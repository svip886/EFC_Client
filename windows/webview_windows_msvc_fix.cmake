# Auto-applied by CI / local Windows builds for webview_windows + new MSVC.
# Flutter regenerates generated_plugins.cmake; we include this file from CMakeLists.

# Silence experimental coroutine deprecation used by webview_windows 0.4.x
if(TARGET webview_windows_plugin)
  target_compile_definitions(webview_windows_plugin PRIVATE
    _SILENCE_EXPERIMENTAL_COROUTINE_DEPRECATION_WARNINGS
  )
endif()
