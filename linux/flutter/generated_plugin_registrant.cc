//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <blue_monitor_lib/blue_monitor_lib_plugin.h>

void fl_register_plugins(FlPluginRegistry* registry) {
  g_autoptr(FlPluginRegistrar) blue_monitor_lib_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "BlueMonitorLibPlugin");
  blue_monitor_lib_plugin_register_with_registrar(blue_monitor_lib_registrar);
}
