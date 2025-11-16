// Web-specific implementation
// This file is only used when the app is compiled for web
import 'dart:html' as html;
import 'dart:js' as js;

String? getWebEnvironmentVariable(String key) {
  try {
    final env = js.context['ENV'] as js.JsObject?;
    if (env != null) {
      return env[key] as String?;
    }
  } catch (e) {
    // JS interop failed, return null
  }
  return null;
}
