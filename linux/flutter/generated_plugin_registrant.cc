//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <blue_terminal_lib/blue_terminal_lib_plugin.h>

void fl_register_plugins(FlPluginRegistry* registry) {
  g_autoptr(FlPluginRegistrar) blue_terminal_lib_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "BlueTerminalLibPlugin");
  blue_terminal_lib_plugin_register_with_registrar(blue_terminal_lib_registrar);
}
