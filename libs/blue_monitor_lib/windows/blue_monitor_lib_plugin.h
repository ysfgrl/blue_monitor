#ifndef FLUTTER_PLUGIN_BLUE_MONITOR_LIB_PLUGIN_H_
#define FLUTTER_PLUGIN_BLUE_MONITOR_LIB_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <memory>

namespace blue_monitor_lib {

class BlueMonitorLibPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  BlueMonitorLibPlugin();

  virtual ~BlueMonitorLibPlugin();

  // Disallow copy and assign.
  BlueMonitorLibPlugin(const BlueMonitorLibPlugin&) = delete;
  BlueMonitorLibPlugin& operator=(const BlueMonitorLibPlugin&) = delete;

  // Called when a method is called on this plugin's channel from Dart.
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
};

}  // namespace blue_monitor_lib

#endif  // FLUTTER_PLUGIN_BLUE_MONITOR_LIB_PLUGIN_H_
