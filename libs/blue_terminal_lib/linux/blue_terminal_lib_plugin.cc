#include "include/blue_terminal_lib/blue_terminal_lib_plugin.h"

#include <fcntl.h>
#include <linux/serial.h>
#include <poll.h>
#include <sys/ioctl.h>
#include <sys/stat.h>
#include <sys/sysmacros.h>
#include <sys/utsname.h>
#include <termios.h>
#include <unistd.h>

#include <algorithm>
#include <cerrno>
#include <cstdlib>
#include <cstring>
#include <deque>
#include <limits>
#include <map>
#include <memory>
#include <sstream>
#include <string>
#include <vector>

#include "blue_terminal_lib_plugin_private.h"
#include "message_types.g.h"
#include "messages.g.h"

#define BLUE_TERMINAL_LIB_PLUGIN(obj) \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), blue_terminal_lib_plugin_get_type(), \
                             BlueTerminalLibPlugin))

using Response = BlueTerminalBlueTerminalLibApiResponseHandle;

struct PendingWrite {
  Response* response;
  std::vector<uint8_t> data;
  size_t written = 0;
  gint64 deadline;

  ~PendingWrite() { g_object_unref(response); }
};

struct SerialPort {
  int fd;
  std::string path;
  std::string device;
  std::deque<std::unique_ptr<PendingWrite>> writes;

  ~SerialPort() {
    for (const auto& pending : writes) {
      blue_terminal_blue_terminal_lib_api_respond_error_write(
          pending->response, "port-closed", "Port closed before write completed",
          nullptr);
    }
    if (fd >= 0) close(fd);
  }
};

using Ports = std::map<std::string, std::unique_ptr<SerialPort>>;

struct _BlueTerminalLibPlugin {
  GObject parent_instance;
  Ports* ports;
  FlEventChannel* data_channel;
  FlEventChannel* connection_channel;
  gboolean data_listening;
  gboolean connection_listening;
  guint poll_source;
};

G_DEFINE_TYPE(BlueTerminalLibPlugin, blue_terminal_lib_plugin, G_TYPE_OBJECT)

static std::string canonical_path(const gchar* path) {
  char* resolved = realpath(path, nullptr);
  if (resolved == nullptr) return path;
  std::string result(resolved);
  free(resolved);
  return result;
}

static Ports::iterator find_port(BlueTerminalLibPlugin* self, const gchar* path) {
  const auto device = canonical_path(path);
  return std::find_if(self->ports->begin(), self->ports->end(),
                      [&](const auto& entry) {
                        return entry.first == path || entry.second->device == device;
                      });
}

static void append_port(FlValue* list, const gchar* name, const gchar* path) {
  g_autoptr(BlueTerminalSerialInfoMessage) info =
      blue_terminal_serial_info_message_new(name, path);
  fl_value_append_take(list,
      fl_value_new_custom_object(kSerialInfoMessageType, G_OBJECT(info)));
}

struct SerialDriverRange {
  unsigned int device_major;
  unsigned int first_minor;
  unsigned int last_minor;
};

static bool parse_device_number(const std::string& text, unsigned int* value) {
  if (text.empty() || !g_ascii_isdigit(text[0])) return false;
  gchar* end = nullptr;
  errno = 0;
  const guint64 parsed = g_ascii_strtoull(text.c_str(), &end, 10);
  if (errno != 0 || *end != '\0' ||
      parsed > std::numeric_limits<unsigned int>::max()) return false;
  *value = static_cast<unsigned int>(parsed);
  return true;
}

static std::vector<SerialDriverRange> serial_driver_ranges(const gchar* contents) {
  std::vector<SerialDriverRange> ranges;
  std::istringstream lines(contents);
  std::string line;
  while (std::getline(lines, line)) {
    std::istringstream fields(line);
    std::vector<std::string> tokens;
    std::string token;
    while (fields >> token) tokens.push_back(token);
    // Read from the right since a driver name can itself contain spaces.
    if (tokens.size() < 5 || tokens.back() != "serial") continue;
    const auto& minor_range = tokens[tokens.size() - 2];
    const auto dash = minor_range.find('-');
    SerialDriverRange range = {};
    if (!parse_device_number(tokens[tokens.size() - 3], &range.device_major) ||
        !parse_device_number(minor_range.substr(0, dash), &range.first_minor)) continue;
    range.last_minor = range.first_minor;
    if (dash != std::string::npos &&
        !parse_device_number(minor_range.substr(dash + 1), &range.last_minor)) continue;
    if (range.first_minor <= range.last_minor) ranges.push_back(range);
  }
  return ranges;
}

static bool is_serial_device(const std::string& sysfs_path,
                             const std::string& path,
                             const std::vector<SerialDriverRange>& ranges) {
  struct stat info = {};
  if (stat(path.c_str(), &info) != 0 || !S_ISCHR(info.st_mode)) return false;
  const bool serial = std::any_of(ranges.begin(), ranges.end(), [&](const auto& range) {
    return major(info.st_rdev) == range.device_major &&
           minor(info.st_rdev) >= range.first_minor &&
           minor(info.st_rdev) <= range.last_minor;
  });
  if (!serial) return false;

  // serial8250 publishes unused ttyS slots too. The serial core exposes their
  // UART type in sysfs, allowing us to reject PORT_UNKNOWN without opening a
  // device, changing modem lines, or hiding a busy/exclusively opened port.
  const std::string type_path = sysfs_path + "/type";
  g_autofree gchar* uart_type = nullptr;
  if (g_file_get_contents(type_path.c_str(), &uart_type, nullptr, nullptr)) {
    unsigned int type;
    return parse_device_number(g_strstrip(uart_type), &type) && type != PORT_UNKNOWN;
  }
  // USB serial/CDC and other serial drivers need not have a UART type attribute.
  // If an attribute exists but is unreadable, or an 8250 slot cannot be
  // identified, omit it rather than advertising an unverified UART.
  if (g_file_test(type_path.c_str(), G_FILE_TEST_EXISTS)) return false;
  const auto driver = canonical_path((sysfs_path + "/device/driver").c_str());
  return driver.find("/serial8250") == std::string::npos;
}

static void get_serial_list(Response* response, gpointer) {
  g_autoptr(GError) error = nullptr;
  g_autofree gchar* driver_contents = nullptr;
  if (!g_file_get_contents("/proc/tty/drivers", &driver_contents, nullptr, &error)) {
    blue_terminal_blue_terminal_lib_api_respond_error_get_serial_list(
        response, "list-failed", error->message, nullptr);
    return;
  }
  const auto serial_ranges = serial_driver_ranges(driver_contents);
  g_autoptr(GDir) directory = g_dir_open("/sys/class/tty", 0, &error);
  if (directory == nullptr) {
    blue_terminal_blue_terminal_lib_api_respond_error_get_serial_list(
        response, "list-failed", error->message, nullptr);
    return;
  }
  std::vector<std::string> names;
  const gchar* name;
  while ((name = g_dir_read_name(directory)) != nullptr) {
    const std::string sysfs_path = std::string("/sys/class/tty/") + name;
    const std::string device = sysfs_path + "/device";
    const std::string path = std::string("/dev/") + name;
    if (g_file_test(device.c_str(), G_FILE_TEST_EXISTS) &&
        is_serial_device(sysfs_path, path, serial_ranges)) {
      names.emplace_back(name);
    }
  }
  std::sort(names.begin(), names.end());
  g_autoptr(FlValue) ports = fl_value_new_list();
  for (const auto& port_name : names) {
    const std::string path = "/dev/" + port_name;
    append_port(ports, port_name.c_str(), path.c_str());
  }
  blue_terminal_blue_terminal_lib_api_respond_get_serial_list(response, ports);
}

static void get_connected_ports(Response* response, gpointer user_data) {
  auto* self = BLUE_TERMINAL_LIB_PLUGIN(user_data);
  g_autoptr(FlValue) ports = fl_value_new_list();
  for (const auto& entry : *self->ports) {
    g_autofree gchar* name = g_path_get_basename(entry.first.c_str());
    append_port(ports, name, entry.first.c_str());
  }
  blue_terminal_blue_terminal_lib_api_respond_get_connected_ports(response, ports);
}

static void send_event(FlEventChannel* channel, FlValue* value) {
  g_autoptr(GError) error = nullptr;
  if (!fl_event_channel_send(channel, value, nullptr, &error)) {
    g_warning("Serial event could not be sent: %s", error->message);
  }
}

static void emit_connection(BlueTerminalLibPlugin* self, const std::string& path,
                            BlueTerminalSerialConnectionState state,
                            const gchar* error = nullptr) {
  if (!self->connection_listening) return;
  g_autoptr(BlueTerminalSerialConnectionMessage) message =
      blue_terminal_serial_connection_message_new(path.c_str(), state, error);
  g_autoptr(FlValue) value = fl_value_new_custom_object(
      kSerialConnectionMessageType, G_OBJECT(message));
  send_event(self->connection_channel, value);
}

static void emit_data(BlueTerminalLibPlugin* self, const std::string& path,
                      const uint8_t* bytes, size_t length) {
  if (!self->data_listening) return;
  g_autoptr(BlueTerminalSerialDataMessage) message =
      blue_terminal_serial_data_message_new(path.c_str(), bytes, length);
  g_autoptr(FlValue) value = fl_value_new_custom_object(
      kSerialDataMessageType, G_OBJECT(message));
  send_event(self->data_channel, value);
}

static bool baud_speed(int64_t baud, speed_t* speed) {
  switch (baud) {
#define BAUD(value) case value: *speed = B##value; return true
    BAUD(50); BAUD(75); BAUD(110); BAUD(134); BAUD(150); BAUD(200);
    BAUD(300); BAUD(600); BAUD(1200); BAUD(1800); BAUD(2400);
    BAUD(4800); BAUD(9600); BAUD(19200); BAUD(38400); BAUD(57600);
    BAUD(115200); BAUD(230400); BAUD(460800); BAUD(500000);
    BAUD(576000); BAUD(921600); BAUD(1000000); BAUD(1152000);
    BAUD(1500000); BAUD(2000000); BAUD(2500000); BAUD(3000000);
    BAUD(3500000); BAUD(4000000);
#undef BAUD
    default: return false;
  }
}

static bool configure(int fd, BlueTerminalSerialConfigMessage* config,
                      std::string* error) {
  speed_t speed;
  const int64_t bits = blue_terminal_serial_config_message_get_data_bits(config);
  if (!baud_speed(blue_terminal_serial_config_message_get_baud_rate(config), &speed)) {
    *error = "Unsupported baud rate";
    return false;
  }
  if (bits < 5 || bits > 8) {
    *error = "Data bits must be between 5 and 8";
    return false;
  }
  const auto stop = blue_terminal_serial_config_message_get_stop_bits(config);
  if (stop == BLUE_TERMINAL_LIB_SERIAL_STOP_BITS_ONE_POINT_FIVE) {
    *error = "Linux termios does not support 1.5 stop bits";
    return false;
  }
  termios settings = {};
  if (tcgetattr(fd, &settings) != 0) {
    *error = strerror(errno);
    return false;
  }
  cfmakeraw(&settings);
  settings.c_cflag |= CLOCAL | CREAD;
  settings.c_cflag &= ~(CSIZE | CSTOPB | PARENB | PARODD | CMSPAR | CRTSCTS);
  settings.c_iflag &= ~(IXON | IXOFF | IXANY | INPCK | ISTRIP);
  const tcflag_t sizes[] = {CS5, CS6, CS7, CS8};
  settings.c_cflag |= sizes[bits - 5];
  if (stop == BLUE_TERMINAL_LIB_SERIAL_STOP_BITS_TWO) settings.c_cflag |= CSTOPB;
  const auto parity = blue_terminal_serial_config_message_get_parity(config);
  if (parity != BLUE_TERMINAL_LIB_SERIAL_PARITY_NONE) {
    settings.c_cflag |= PARENB;
    settings.c_iflag |= INPCK;
    if (parity == BLUE_TERMINAL_LIB_SERIAL_PARITY_ODD ||
        parity == BLUE_TERMINAL_LIB_SERIAL_PARITY_MARK) settings.c_cflag |= PARODD;
    if (parity == BLUE_TERMINAL_LIB_SERIAL_PARITY_MARK ||
        parity == BLUE_TERMINAL_LIB_SERIAL_PARITY_SPACE) settings.c_cflag |= CMSPAR;
  }
  const auto flow = blue_terminal_serial_config_message_get_flow_control(config);
  if (flow == BLUE_TERMINAL_LIB_SERIAL_FLOW_CONTROL_RTS_CTS) settings.c_cflag |= CRTSCTS;
  if (flow == BLUE_TERMINAL_LIB_SERIAL_FLOW_CONTROL_XON_XOFF) settings.c_iflag |= IXON | IXOFF;
  settings.c_cc[VMIN] = 1;
  settings.c_cc[VTIME] = 0;
  if (cfsetispeed(&settings, speed) != 0 || cfsetospeed(&settings, speed) != 0 ||
      tcsetattr(fd, TCSANOW, &settings) != 0) {
    *error = strerror(errno);
    return false;
  }
  return true;
}

// All descriptors are nonblocking. Each timer tick has a bounded I/O budget;
// write timeouts never sleep or block Flutter's platform thread.
static bool advance_write(SerialPort* port, PendingWrite* pending,
                           bool single_attempt, std::string* error) {
  if (pending->written == pending->data.size()) return true;
  const size_t remaining = pending->data.size() - pending->written;
  const ssize_t count = ::write(port->fd, pending->data.data() + pending->written,
                                std::min(remaining, size_t{65536}));
  if (count > 0) pending->written += static_cast<size_t>(count);
  if (count < 0 && errno != EAGAIN && errno != EWOULDBLOCK && errno != EINTR) {
    *error = strerror(errno);
    return true;
  }
  return single_attempt || pending->written == pending->data.size() ||
         g_get_monotonic_time() >= pending->deadline;
}

static void close_port(BlueTerminalLibPlugin* self, const std::string& path,
                       const gchar* error = nullptr) {
  self->ports->erase(path);
  emit_connection(self, path, BLUE_TERMINAL_LIB_SERIAL_CONNECTION_STATE_DISCONNECTED, error);
}

static gboolean poll_ports(gpointer user_data) {
  auto* self = BLUE_TERMINAL_LIB_PLUGIN(user_data);
  std::vector<std::pair<std::string, std::string>> lost;
  for (auto& entry : *self->ports) {
    auto* port = entry.second.get();
    std::string error;
    pollfd status = {port->fd, POLLIN, 0};
    if (poll(&status, 1, 0) < 0 && errno != EINTR) error = strerror(errno);
    if (status.revents & POLLIN) {
      uint8_t buffer[4096];
      for (int chunk = 0; chunk < 4; ++chunk) {
        const ssize_t count = read(port->fd, buffer, sizeof(buffer));
        if (count > 0) {
          emit_data(self, port->path, buffer, static_cast<size_t>(count));
        } else {
          if (count == 0) error = "Serial device disconnected";
          else if (errno != EAGAIN && errno != EWOULDBLOCK && errno != EINTR) error = strerror(errno);
          break;
        }
      }
    }
    if (status.revents & (POLLHUP | POLLERR | POLLNVAL)) error = "Serial device disconnected";
    if (error.empty() && !port->writes.empty()) {
      auto* pending = port->writes.front().get();
      if (g_get_monotonic_time() >= pending->deadline ||
          advance_write(port, pending, false, &error)) {
        if (error.empty()) {
          blue_terminal_blue_terminal_lib_api_respond_write(pending->response, pending->written);
        } else {
          blue_terminal_blue_terminal_lib_api_respond_error_write(
              pending->response, "write-failed", error.c_str(), nullptr);
        }
        port->writes.pop_front();
      }
    }
    if (!error.empty()) lost.emplace_back(entry.first, error);
  }
  for (const auto& entry : lost) close_port(self, entry.first, entry.second.c_str());
  if (self->ports->empty()) {
    self->poll_source = 0;
    return G_SOURCE_REMOVE;
  }
  return G_SOURCE_CONTINUE;
}

static void connect_port(const gchar* path, BlueTerminalSerialConfigMessage* config,
                          Response* response, gpointer user_data) {
  auto* self = BLUE_TERMINAL_LIB_PLUGIN(user_data);
  if (path[0] == '\0') {
    blue_terminal_blue_terminal_lib_api_respond_error_connect(
        response, "invalid-path", "Port path is empty", nullptr);
    return;
  }
  if (find_port(self, path) != self->ports->end()) {
    blue_terminal_blue_terminal_lib_api_respond_error_connect(
        response, "port-busy", "Port is already connected", nullptr);
    return;
  }
  const int fd = open(path, O_RDWR | O_NOCTTY | O_NONBLOCK | O_CLOEXEC);
  if (fd < 0) {
    blue_terminal_blue_terminal_lib_api_respond_error_connect(
        response, "open-failed", strerror(errno), nullptr);
    return;
  }
  auto port = std::make_unique<SerialPort>();
  port->fd = fd;
  port->path = path;
  port->device = canonical_path(path);
  std::string error;
  if (ioctl(fd, TIOCEXCL) != 0 || !configure(fd, config, &error)) {
    if (error.empty()) error = strerror(errno);
    blue_terminal_blue_terminal_lib_api_respond_error_connect(
        response, "configure-failed", error.c_str(), nullptr);
    return;
  }
  self->ports->emplace(path, std::move(port));
  if (self->poll_source == 0) self->poll_source = g_timeout_add(10, poll_ports, self);
  emit_connection(self, path, BLUE_TERMINAL_LIB_SERIAL_CONNECTION_STATE_CONNECTED);
  blue_terminal_blue_terminal_lib_api_respond_connect(response);
}

static void disconnect_port(const gchar* path, Response* response, gpointer user_data) {
  auto* self = BLUE_TERMINAL_LIB_PLUGIN(user_data);
  const auto it = find_port(self, path);
  if (it != self->ports->end()) {
    const std::string connected_path = it->first;
    close_port(self, connected_path);
  }
  if (self->ports->empty() && self->poll_source != 0) {
    g_source_remove(self->poll_source);
    self->poll_source = 0;
  }
  blue_terminal_blue_terminal_lib_api_respond_disconnect(response);
}

static void write_port(const gchar* path, const uint8_t* data, size_t length,
                        int64_t timeout_ms, Response* response, gpointer user_data) {
  auto* self = BLUE_TERMINAL_LIB_PLUGIN(user_data);
  const auto it = find_port(self, path);
  if (it == self->ports->end()) {
    blue_terminal_blue_terminal_lib_api_respond_error_write(
        response, "port-not-connected", "Port is not connected", nullptr);
    return;
  }
  const gint64 now = g_get_monotonic_time();
  if (timeout_ms < 0 || timeout_ms > (std::numeric_limits<gint64>::max() - now) / 1000) {
    blue_terminal_blue_terminal_lib_api_respond_error_write(
        response, "invalid-timeout", "Timeout is outside the supported range", nullptr);
    return;
  }
  auto pending = std::make_unique<PendingWrite>();
  pending->response = static_cast<Response*>(g_object_ref(response));
  if (length > 0) pending->data.assign(data, data + length);
  pending->deadline = now + timeout_ms * 1000;
  auto* port = it->second.get();
  std::string error;
  if (length == 0 || (timeout_ms == 0 && !port->writes.empty()) ||
      (port->writes.empty() && advance_write(port, pending.get(), timeout_ms == 0, &error))) {
    if (error.empty()) {
      blue_terminal_blue_terminal_lib_api_respond_write(response, pending->written);
    } else {
      blue_terminal_blue_terminal_lib_api_respond_error_write(response, "write-failed", error.c_str(), nullptr);
      const std::string connected_path = it->first;
      close_port(self, connected_path, error.c_str());
    }
    return;
  }
  port->writes.push_back(std::move(pending));
}

static FlMethodErrorResponse* stream_listen(FlEventChannel* channel, FlValue*, gpointer user_data) {
  auto* self = BLUE_TERMINAL_LIB_PLUGIN(user_data);
  if (channel == self->data_channel) self->data_listening = TRUE;
  else self->connection_listening = TRUE;
  return nullptr;
}

static FlMethodErrorResponse* stream_cancel(FlEventChannel* channel, FlValue*, gpointer user_data) {
  auto* self = BLUE_TERMINAL_LIB_PLUGIN(user_data);
  if (channel == self->data_channel) self->data_listening = FALSE;
  else self->connection_listening = FALSE;
  return nullptr;
}

// Preserve the original template helper for existing native consumers.
FlMethodResponse* get_platform_version() {
  struct utsname system = {};
  uname(&system);
  g_autofree gchar* version = g_strdup_printf("Linux %s", system.version);
  g_autoptr(FlValue) value = fl_value_new_string(version);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(value));
}

static void blue_terminal_lib_plugin_dispose(GObject* object) {
  auto* self = BLUE_TERMINAL_LIB_PLUGIN(object);
  if (self->poll_source != 0) {
    g_source_remove(self->poll_source);
    self->poll_source = 0;
  }
  delete self->ports;
  self->ports = nullptr;
  if (self->data_channel != nullptr) {
    fl_event_channel_set_stream_handlers(self->data_channel, nullptr, nullptr, nullptr, nullptr);
    g_clear_object(&self->data_channel);
  }
  if (self->connection_channel != nullptr) {
    fl_event_channel_set_stream_handlers(self->connection_channel, nullptr, nullptr, nullptr, nullptr);
    g_clear_object(&self->connection_channel);
  }
  G_OBJECT_CLASS(blue_terminal_lib_plugin_parent_class)->dispose(object);
}

static void blue_terminal_lib_plugin_class_init(BlueTerminalLibPluginClass* klass) {
  G_OBJECT_CLASS(klass)->dispose = blue_terminal_lib_plugin_dispose;
}

static void blue_terminal_lib_plugin_init(BlueTerminalLibPlugin* self) {
  self->ports = new Ports();
}

void blue_terminal_lib_plugin_register_with_registrar(FlPluginRegistrar* registrar) {
  auto* self = BLUE_TERMINAL_LIB_PLUGIN(g_object_new(blue_terminal_lib_plugin_get_type(), nullptr));
  auto* messenger = fl_plugin_registrar_get_messenger(registrar);
  g_autoptr(BlueTerminalMessageCodec) message_codec = BLUE_TERMINAL_MESSAGE_CODEC(
      g_object_new(blue_terminal_message_codec_get_type(), nullptr));
  g_autoptr(FlStandardMethodCodec) method_codec = fl_standard_method_codec_new_with_message_codec(
      FL_STANDARD_MESSAGE_CODEC(message_codec));
  self->data_channel = fl_event_channel_new(messenger,
      "dev.flutter.pigeon.blue_terminal_lib.BlueTerminalLibEvents.serialDataReceived",
      FL_METHOD_CODEC(method_codec));
  self->connection_channel = fl_event_channel_new(messenger,
      "dev.flutter.pigeon.blue_terminal_lib.BlueTerminalLibEvents.serialConnectionChanged",
      FL_METHOD_CODEC(method_codec));
  fl_event_channel_set_stream_handlers(self->data_channel, stream_listen, stream_cancel, self, nullptr);
  fl_event_channel_set_stream_handlers(self->connection_channel, stream_listen, stream_cancel, self, nullptr);
  static const BlueTerminalBlueTerminalLibApiVTable vtable = {
      get_serial_list, get_connected_ports, connect_port, disconnect_port, write_port};
  // The generated host handlers own this reference until the messenger closes.
  blue_terminal_blue_terminal_lib_api_set_method_handlers(messenger, nullptr, &vtable, self, g_object_unref);
}
