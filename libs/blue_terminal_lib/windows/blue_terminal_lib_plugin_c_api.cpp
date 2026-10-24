#include "include/blue_terminal_lib/blue_terminal_lib_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "blue_terminal_lib_plugin.h"

void BlueTerminalLibPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  blue_terminal_lib::BlueTerminalLibPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
