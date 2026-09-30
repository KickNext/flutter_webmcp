@TestOn('browser')
@JS()
library;

import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter_webmcp/webmcp.dart';
import 'package:test/test.dart';

void main() {
  setUp(() {
    final original = _document.getProperty<JSAny?>('modelContext'.toJS);
    addTearDown(() {
      _document.setProperty('modelContext'.toJS, original);
      WebMcp.logger = null;
    });
  });

  for (final value in <bool?>[true, false, null]) {
    test('serializes all annotations with value $value', () async {
      JSObject? registeredTool;
      _document.setProperty(
          'modelContext'.toJS,
          _FakeModelContext(
            registerTool: ((JSObject tool, JSObject options) {
              registeredTool = tool;
            }).toJS,
          ));
      final registration = await WebMcp.registerTool(WebMcpTool(
        name: 'annotations',
        description: 'Tests annotation serialization.',
        annotations: WebMcpAnnotations(
          readOnly: value,
          untrustedContent: value,
          consequential: value,
          debugging: value,
        ),
        execute: (input, context) => null,
      ));
      final annotations =
          registeredTool!.getProperty<JSObject>('annotations'.toJS);
      for (final key in [
        'readOnlyHint',
        'untrustedContentHint',
        'consequentialHint',
        'debugging',
      ]) {
        if (value == null) {
          expect(annotations.hasProperty(key.toJS).toDart, isFalse);
        } else {
          expect(annotations.getProperty<JSBoolean>(key.toJS).toDart, value);
        }
      }
      await registration.unregister();
    });
  }

  test('older ModelContext can register without lifecycle events', () async {
    _document.setProperty(
        'modelContext'.toJS,
        _FakeModelContext(
          registerTool: ((JSObject tool, JSObject options) {}).toJS,
        ));
    expect(WebMcp.isSupported, isTrue);
    expect(WebMcp.isLifecycleEventsSupported, isFalse);
    expect(await WebMcp.lifecycleEvents.toList(), isEmpty);
    final registration = await WebMcp.registerTool(WebMcpTool(
      name: 'older_browser',
      description: 'Registration still works.',
      execute: (input, context) => null,
    ));
    await registration.unregister();
  });

  test('unavailable ModelContext has an empty event stream', () async {
    _document.setProperty('modelContext'.toJS, null);
    expect(WebMcp.isLifecycleEventsSupported, isFalse);
    expect(await WebMcp.lifecycleEvents.toList(), isEmpty);
  });

  test('lifecycle detection requires both events and EventTarget methods', () {
    final target = _lifecycleTarget();
    _document.setProperty('modelContext'.toJS, target);
    expect(WebMcp.isLifecycleEventsSupported, isTrue);
    target.delete('ontoolcancel'.toJS);
    expect(WebMcp.isLifecycleEventsSupported, isFalse);
    target.setProperty('ontoolcancel'.toJS, null);
    target.setProperty('addEventListener'.toJS, null);
    expect(WebMcp.isLifecycleEventsSupported, isFalse);
  });

  test('streams owner events without replacing JS callbacks; cleans up',
      () async {
    final owner = _lifecycleTarget();
    final otherDocument = _lifecycleTarget();
    _document.setProperty('modelContext'.toJS, owner);
    var jsCalls = 0;
    final jsListener = ((JSObject event) => jsCalls++).toJS;
    owner.addEventListener('toolactivated', jsListener);
    addTearDown(() => owner.removeEventListener('toolactivated', jsListener));
    final handler = ((JSObject event) {}).toJS;
    owner.setProperty('ontoolactivated'.toJS, handler);

    var attached = 0;
    var detached = 0;
    final nativeAdd = owner.getProperty<JSFunction>('addEventListener'.toJS);
    final nativeRemove =
        owner.getProperty<JSFunction>('removeEventListener'.toJS);
    owner.setProperty(
        'addEventListener'.toJS,
        ((JSString type, JSFunction listener) {
          attached++;
          nativeAdd.callAsFunction(owner, type, listener);
        }).toJS);
    owner.setProperty(
        'removeEventListener'.toJS,
        ((JSString type, JSFunction listener) {
          detached++;
          nativeRemove.callAsFunction(owner, type, listener);
        }).toJS);
    final stream = WebMcp.lifecycleEvents;
    expect(attached, 0);
    final first = <WebMcpLifecycleEvent>[];
    final second = <WebMcpLifecycleEvent>[];
    final a = stream.listen(first.add);
    final b = stream.listen(second.add);
    addTearDown(a.cancel);
    addTearDown(b.cancel);
    expect(attached, 2);

    _dispatchToolEvent(otherDocument, 'toolactivated', 'other_tool');
    _dispatchToolEvent(owner, 'toolactivated', 'owner_tool');
    _dispatchToolEvent(owner, 'toolcancel', 'owner_tool');
    await Future<void>.delayed(Duration.zero);
    expect(first.map((event) => event.type), [
      WebMcpLifecycleEventType.activated,
      WebMcpLifecycleEventType.cancelled,
    ]);
    expect(first.map((event) => event.toolName), ['owner_tool', 'owner_tool']);
    expect(second.length, 2);
    expect(jsCalls, 1);
    expect(
        identical(
            owner.getProperty<JSFunction>('ontoolactivated'.toJS), handler),
        isTrue);

    await a.cancel();
    expect(detached, 0);
    _dispatchToolEvent(owner, 'toolcancel', 'owner_tool');
    await Future<void>.delayed(Duration.zero);
    expect(first.length, 2);
    expect(second.length, 3);

    // Cleanup stays bound to the original target even if the document changes.
    _document.setProperty('modelContext'.toJS, otherDocument);
    await b.cancel();
    expect(detached, 2);
    _dispatchToolEvent(owner, 'toolactivated', 'owner_tool');
    expect(jsCalls, 2);
    final c = stream.listen(first.add);
    addTearDown(c.cancel);
    expect(attached, 4);
    _dispatchToolEvent(owner, 'toolactivated', 'owner_tool');
    await Future<void>.delayed(Duration.zero);
    expect(first.length, 3);
    await c.cancel();
    expect(detached, 4);
  });

  for (final cancelAttempt in [false, true]) {
    test('registration cleanup preserves an executing handler ($cancelAttempt)',
        () async {
      JSObject? registeredTool;
      JSObject? registrationOptions;
      _document.setProperty(
          'modelContext'.toJS,
          _FakeModelContext(
            registerTool: ((JSObject tool, JSObject options) {
              registeredTool = tool;
              registrationOptions = options;
            }).toJS,
          ));
      final finish = Completer<void>();
      final started = Completer<WebMcpExecutionContext>();
      final attempt = WebMcp.startToolRegistration(WebMcpTool(
        name: 'long_running',
        description: 'Keeps executing after registration cleanup.',
        execute: (input, context) async {
          started.complete(context);
          await finish.future;
          return {'cancelled': context.isCancelled};
        },
      ));
      final registration = await attempt.ready;
      final executionController = _TestAbortController();
      final promise = registeredTool!
              .getProperty<JSFunction>('execute'.toJS)
              .callAsFunction(registeredTool, <String, Object?>{}.jsify(),
                  {'signal': executionController.signal}.jsify())
          as JSPromise<JSAny?>;
      final context = await started.future;
      if (cancelAttempt) {
        await attempt.cancel();
      } else {
        await registration.unregister();
      }
      expect(
          registrationOptions!
              .getProperty<JSObject>('signal'.toJS)
              .getProperty<JSBoolean>('aborted'.toJS)
              .toDart,
          isTrue);
      expect(context.isCancelled, isFalse);
      finish.complete();
      expect((await promise.toDart).dartify(), {'cancelled': false});
      executionController.abort();
      expect(context.isCancelled, isTrue);
    });
  }

  test('registers, executes, and unregisters through document.modelContext',
      () async {
    JSObject? registeredTool;
    JSObject? registrationOptions;

    final fakeModelContext = _FakeModelContext(
      registerTool: ((JSObject tool, JSObject options) {
        registeredTool = tool;
        registrationOptions = options;
        return Future<JSAny?>.value(null).toJS;
      }).toJS,
    );
    _document.setProperty('modelContext'.toJS, fakeModelContext);

    final registration = await WebMcp.registerTool(
      WebMcpTool(
        name: 'sum_values',
        title: 'Sum values',
        description: 'Adds two numbers.',
        inputSchema: const {
          'type': 'object',
          'properties': {
            'a': {'type': 'number'},
            'b': {'type': 'number'},
          },
          'required': ['a', 'b'],
        },
        annotations: const WebMcpAnnotations(
          readOnly: true,
          untrustedContent: false,
        ),
        execute: (input, context) => {
          'total': (input['a']! as num) + (input['b']! as num),
          'cancelled': context.isCancelled,
        },
      ),
      exposedTo: const ['https://agent.example'],
    );

    expect(
      registeredTool!.getProperty<JSString>('name'.toJS).toDart,
      'sum_values',
    );
    expect(
      registeredTool!.getProperty<JSString>('title'.toJS).toDart,
      'Sum values',
    );
    expect(
      registeredTool!.getProperty<JSString>('description'.toJS).toDart,
      'Adds two numbers.',
    );
    final schema = registeredTool!
        .getProperty<JSObject>('inputSchema'.toJS)
        .dartify()! as Map;
    expect(schema['type'], 'object');
    expect(schema['required'], ['a', 'b']);
    final annotations =
        registeredTool!.getProperty<JSObject>('annotations'.toJS);
    expect(
      annotations.getProperty<JSBoolean>('readOnlyHint'.toJS).toDart,
      isTrue,
    );
    expect(
      annotations.getProperty<JSBoolean>('untrustedContentHint'.toJS).toDart,
      isFalse,
    );
    final exposedTo = registrationOptions!
        .getProperty<JSArray<JSString>>('exposedTo'.toJS)
        .toDart
        .map((origin) => origin.toDart);
    expect(exposedTo, ['https://agent.example']);

    final execute = registeredTool!.getProperty<JSFunction>('execute'.toJS);
    final resultPromise = execute.callAsFunction(
      registeredTool,
      {'a': 2, 'b': 3}.jsify(),
      <String, Object?>{}.jsify(),
    ) as JSPromise<JSAny?>;
    final result = (await resultPromise.toDart).dartify()! as Map;

    expect(result['total'], 5);
    expect(result['cancelled'], isFalse);

    final cancelledResultPromise = execute.callAsFunction(
      registeredTool,
      {'a': 2, 'b': 3}.jsify(),
      {
        'signal': {'aborted': true},
      }.jsify(),
    ) as JSPromise<JSAny?>;
    final cancelledResult =
        (await cancelledResultPromise.toDart).dartify()! as Map;
    expect(cancelledResult['cancelled'], isTrue);

    final signal = registrationOptions!.getProperty<JSObject>('signal'.toJS);
    expect(signal.getProperty<JSBoolean>('aborted'.toJS).toDart, isFalse);
    await registration.unregister();
    expect(signal.getProperty<JSBoolean>('aborted'.toJS).toDart, isTrue);
  });

  test('turns Dart tool errors into structured agent results', () async {
    JSObject? registeredTool;
    final fakeModelContext = _FakeModelContext(
      registerTool: ((JSObject tool, JSObject options) {
        registeredTool = tool;
        return Future<JSAny?>.value(null).toJS;
      }).toJS,
    );
    _document.setProperty('modelContext'.toJS, fakeModelContext);

    WebMcpToolCallEvent? logEvent;
    WebMcp.logger = (event) => logEvent = event;
    await WebMcp.registerTool(
      WebMcpTool(
        name: 'fail_cleanly',
        description: 'Fails with a public error.',
        execute: (input, context) => throw const WebMcpToolException(
          code: 'expected_failure',
          message: 'Readable failure.',
        ),
      ),
    );

    final execute = registeredTool!.getProperty<JSFunction>('execute'.toJS);
    final promise = execute.callAsFunction(
      registeredTool,
      <String, Object?>{}.jsify(),
      <String, Object?>{}.jsify(),
    ) as JSPromise<JSAny?>;
    final result = (await promise.toDart).dartify()! as Map;

    expect(result['isError'], isTrue);
    expect((result['error']! as Map)['code'], 'expected_failure');
    expect(logEvent?.status, WebMcpToolCallStatus.failed);
    WebMcp.logger = null;
  });

  test('accepts a synchronous undefined registration result', () async {
    final fakeModelContext = _FakeModelContext(
      registerTool: ((JSObject tool, JSObject options) {}).toJS,
    );
    _document.setProperty('modelContext'.toJS, fakeModelContext);

    final registration = await WebMcp.registerTool(
      WebMcpTool(
        name: 'sync_registration',
        description: 'Covers experimental synchronous browser bindings.',
        execute: (input, context) => null,
      ),
    );

    expect(registration.isRegistered, isTrue);
    await registration.unregister();
    expect(registration.isRegistered, isFalse);
  });

  test('waits for the draft Promise registration result', () async {
    final completer = Completer<JSAny?>();
    final fakeModelContext = _FakeModelContext(
      registerTool:
          ((JSObject tool, JSObject options) => completer.future.toJS).toJS,
    );
    _document.setProperty('modelContext'.toJS, fakeModelContext);

    var completed = false;
    final registrationFuture = WebMcp.registerTool(
      WebMcpTool(
        name: 'async_registration',
        description: 'Covers the draft Promise registration binding.',
        execute: (input, context) => null,
      ),
    ).then((registration) {
      completed = true;
      return registration;
    });

    await Future<void>.delayed(Duration.zero);
    expect(completed, isFalse);
    completer.complete(null);

    final registration = await registrationFuture;
    expect(completed, isTrue);
    await registration.unregister();
  });

  test('aborts a registration while its browser Promise is pending', () async {
    final completer = Completer<JSAny?>();
    JSObject? registrationOptions;
    final fakeModelContext = _FakeModelContext(
      registerTool: ((JSObject tool, JSObject options) {
        registrationOptions = options;
        return completer.future.toJS;
      }).toJS,
    );
    _document.setProperty('modelContext'.toJS, fakeModelContext);

    final attempt = WebMcp.startToolRegistration(
      WebMcpTool(
        name: 'cancel_pending',
        description: 'Covers cancellation before registration is ready.',
        execute: (input, context) => null,
      ),
    );
    final signal = registrationOptions!.getProperty<JSObject>('signal'.toJS);
    expect(signal.getProperty<JSBoolean>('aborted'.toJS).toDart, isFalse);

    attempt.cancel();
    expect(signal.getProperty<JSBoolean>('aborted'.toJS).toDart, isTrue);

    final readyExpectation = expectLater(
      attempt.ready,
      throwsA(isA<WebMcpException>()),
    );
    completer.complete(null);
    await readyExpectation;
  });

  test('hides unexpected local errors from the agent', () async {
    JSObject? registeredTool;
    final fakeModelContext = _FakeModelContext(
      registerTool: ((JSObject tool, JSObject options) {
        registeredTool = tool;
        return Future<JSAny?>.value(null).toJS;
      }).toJS,
    );
    _document.setProperty('modelContext'.toJS, fakeModelContext);

    WebMcpToolCallEvent? logEvent;
    WebMcp.logger = (event) => logEvent = event;
    await WebMcp.registerTool(
      WebMcpTool(
        name: 'fail_privately',
        description: 'Fails with a private error.',
        execute: (input, context) => throw StateError('private-token'),
      ),
    );

    final execute = registeredTool!.getProperty<JSFunction>('execute'.toJS);
    final promise = execute.callAsFunction(
      registeredTool,
      <String, Object?>{}.jsify(),
    ) as JSPromise<JSAny?>;
    final result = (await promise.toDart).dartify()! as Map;

    expect((result['error']! as Map)['code'], 'internal_error');
    expect(result.toString(), isNot(contains('private-token')));
    expect(logEvent?.error.toString(), contains('private-token'));
    WebMcp.logger = null;
  });
}

@JS('document')
external JSObject get _document;

@JS('EventTarget')
extension type _TestEventTarget._(JSObject _) implements JSObject {
  external factory _TestEventTarget();
  external void addEventListener(String type, JSFunction listener);
  external void removeEventListener(String type, JSFunction listener);
  external bool dispatchEvent(_TestEvent event);
}

@JS('Event')
extension type _TestEvent._(JSObject _) implements JSObject {
  external factory _TestEvent(String type);
}

@JS('AbortController')
extension type _TestAbortController._(JSObject _) implements JSObject {
  external factory _TestAbortController();
  external JSObject get signal;
  external void abort();
}

_TestEventTarget _lifecycleTarget() => _TestEventTarget()
  ..setProperty('ontoolactivated'.toJS, null)
  ..setProperty('ontoolcancel'.toJS, null);

void _dispatchToolEvent(_TestEventTarget target, String type, String name) {
  final event = _TestEvent(type)..setProperty('toolName'.toJS, name.toJS);
  target.dispatchEvent(event);
}

@JS()
@anonymous
extension type _FakeModelContext._(JSObject _) implements JSObject {
  external factory _FakeModelContext({required JSFunction registerTool});
}
