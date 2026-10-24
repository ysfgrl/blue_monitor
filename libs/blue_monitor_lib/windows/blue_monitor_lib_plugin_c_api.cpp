#include "include/blue_monitor_lib/blue_monitor_lib_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "blue_monitor_lib_plugin.h"

void BlueMonitorLibPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  blue_monitor_lib::BlueMonitorLibPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
