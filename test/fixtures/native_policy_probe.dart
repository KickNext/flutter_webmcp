@JS()
library;

import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter_webmcp/webmcp.dart';

// Served by tool/check_native_browser.dart with real HTTP response headers.
Future<void> main() async {
  final path = _location.getProperty<JSString>('pathname'.toJS).toDart;
  final blocked = path == '/blocked';
  final checks = <String, Object?>{'path': path};
  try {
    if (!WebMcp.isSupported) throw StateError('Native WebMCP is unavailable');
    // API presence is distinct from permission to register.
    checks['apiPresent'] = true;
    checks['parentAllowed'] = await _registrationAllowed();

    final frame =
        _document.callMethod<JSObject>('createElement'.toJS, 'iframe'.toJS);
    _document
        .getProperty<JSObject>('body'.toJS)
        .callMethod<JSAny?>('appendChild'.toJS, frame);
    try {
      final child = frame.getProperty<JSObject>('contentDocument'.toJS);
      checks['descendantAllowed'] = await _childRegistrationAllowed(child);
    } finally {
      frame.callMethod<JSAny?>('remove'.toJS);
    }
    checks['passed'] = checks['parentAllowed'] == !blocked &&
        checks['descendantAllowed'] == !blocked;
  } catch (error) {
    checks['passed'] = false;
    checks['error'] = error.toString();
  }
  final json = jsonEncode(checks);
  _document
      .callMethod<JSObject>('getElementById'.toJS, 'result'.toJS)
      .setProperty('textContent'.toJS, json.toJS);
  await _fetch(
          '/result',
          <String, Object?>{
            'method': 'POST',
            'body': json,
          }.jsify() as JSObject)
      .toDart;
}

Future<bool> _registrationAllowed() async {
  try {
    final registration = await WebMcp.registerTool(WebMcpTool(
      name: 'native_policy_parent',
      description: 'Tests HTTP Permissions Policy enforcement.',
      execute: (_, __) => WebMcpResult.text('OK'),
    ));
    await registration.unregister();
    return true;
  } on WebMcpException catch (error) {
    final cause = error.cause as JSAny?;
    if (cause != null &&
        cause.isA<JSObject>() &&
        (cause as JSObject).getProperty<JSString>('name'.toJS).toDart ==
            'NotAllowedError') {
      return false;
    }
    rethrow;
  }
}

Future<bool> _childRegistrationAllowed(JSObject document) async {
  final context = document.getProperty<JSObject>('modelContext'.toJS);
  final controller = _AbortController();
  final tool = <String, Object?>{
    'name': 'native_policy_child',
    'description': 'Tests inherited HTTP Permissions Policy.',
    'inputSchema': <String, Object?>{'type': 'object'},
  }.jsify() as JSObject;
  tool.setProperty('execute'.toJS, (() => 'OK'.toJS).toJS);
  try {
    await context
        .callMethod<JSPromise<JSAny?>>('registerTool'.toJS, tool,
            <String, Object?>{'signal': controller.signal}.jsify())
        .toDart;
    return true;
  } catch (error) {
    final cause = error as JSAny?;
    if (cause != null &&
        cause.isA<JSObject>() &&
        (cause as JSObject).getProperty<JSString>('name'.toJS).toDart ==
            'NotAllowedError') {
      return false;
    }
    rethrow;
  } finally {
    controller.abort();
  }
}

@JS('document')
external JSObject get _document;
@JS('location')
external JSObject get _location;
@JS('fetch')
external JSPromise<JSAny?> _fetch(String url, JSObject options);
@JS('AbortController')
extension type _AbortController._(JSObject _) implements JSObject {
  external factory _AbortController();
  external JSObject get signal;
  external void abort();
}
