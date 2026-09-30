@TestOn('browser')
@JS()
library;

import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter_webmcp/webmcp.dart';
import 'package:test/test.dart';

void main() {
  final context = _document.getProperty<JSObject?>('modelContext'.toJS);
  final available = WebMcp.isLifecycleEventsSupported &&
      context != null &&
      context.getProperty<JSAny?>('getTools'.toJS).isA<JSFunction>() &&
      context.getProperty<JSAny?>('executeTool'.toJS).isA<JSFunction>();

  test('native lifecycle API is available', () {
    expect(available, isTrue,
        reason: 'Use a recent Chrome Canary with WebMCP testing enabled. '
            '${_navigator.getProperty<JSString>("userAgent".toJS).toDart}');
  });
  if (!available) return;

  test('native iframe invocation notifies the owner and cancels independently',
      () async {
    final frame =
        _document.callMethod<JSObject>('createElement'.toJS, 'iframe'.toJS);
    final body = _document.getProperty<JSObject>('body'.toJS);
    body.callMethod<JSAny?>('appendChild'.toJS, frame);
    addTearDown(() => frame.callMethod<JSAny?>('remove'.toJS));
    final childDocument = frame.getProperty<JSObject>('contentDocument'.toJS);
    final caller = _NativeModelContext(
        childDocument.getProperty<JSObject>('modelContext'.toJS));
    var callerEvents = 0;
    final callerListener = ((JSObject event) => callerEvents++).toJS;
    caller.addEventListener('toolactivated', callerListener);
    caller.addEventListener('toolcancel', callerListener);
    addTearDown(() {
      caller.removeEventListener('toolactivated', callerListener);
      caller.removeEventListener('toolcancel', callerListener);
    });

    const name = 'flutter_webmcp_native_lifecycle';
    final activated = Completer<void>();
    final cancelled = Completer<void>();
    final order = <String>[];
    final subscription = WebMcp.lifecycleEvents.listen((event) {
      if (event.toolName != name) return;
      switch (event.type) {
        case WebMcpLifecycleEventType.activated:
          activated.complete();
        case WebMcpLifecycleEventType.cancelled:
          order.add('cancel_event');
          cancelled.complete();
      }
    });
    addTearDown(subscription.cancel);
    final finish = Completer<void>();
    addTearDown(() {
      if (!finish.isCompleted) finish.complete();
    });
    final started = Completer<WebMcpExecutionContext>();
    final registration = await WebMcp.registerTool(WebMcpTool(
      name: name,
      description: 'Checks native owner events and separate cancellation.',
      execute: (input, execution) async {
        started.complete(execution);
        await finish.future;
        return WebMcpResult.text('Finished');
      },
    ));
    addTearDown(registration.unregister);
    final tools = (await _NativeModelContext(context).getTools().toDart).toDart;
    final tool = tools.singleWhere(
        (tool) => tool.getProperty<JSString>('name'.toJS).toDart == name);
    final executionController = _NativeAbortController();
    addTearDown(() => executionController.abort());
    final result = caller
        .executeTool(
            tool,
            JSObject(),
            <String, Object?>{'signal': executionController.signal}.jsify()
                as JSObject)
        .toDart;
    final rejection = expectLater(result.catchError((Object error) {
      order.add('rejected');
      throw error;
    }),
        throwsA(predicate(
            (Object error) => error.toString().contains('AbortError'))));

    final execution = await started.future;
    await activated.future;
    expect(callerEvents, 0);
    await registration.unregister();
    expect(execution.isCancelled, isFalse);
    executionController.abort();
    await rejection;
    await cancelled.future;
    expect(execution.isCancelled, isTrue);
    expect(callerEvents, 0);
    expect(order, ['rejected', 'cancel_event']);
    finish.complete();
  });
}

@JS('document')
external JSObject get _document;

@JS('navigator')
external JSObject get _navigator;

extension type _NativeModelContext(JSObject _) implements JSObject {
  external JSPromise<JSArray<JSObject>> getTools();
  external JSPromise<JSString> executeTool(
      JSObject tool, JSObject input, JSObject options);
  external void addEventListener(String type, JSFunction listener);
  external void removeEventListener(String type, JSFunction listener);
}

@JS('AbortController')
extension type _NativeAbortController._(JSObject _) implements JSObject {
  external factory _NativeAbortController();
  external JSObject get signal;
  external void abort();
}
