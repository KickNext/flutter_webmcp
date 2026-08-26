@TestOn('browser')
@JS()
library;

import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter_webmcp/webmcp.dart';
import 'package:test/test.dart';

void main() {
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

@JS()
@anonymous
extension type _FakeModelContext._(JSObject _) implements JSObject {
  external factory _FakeModelContext({required JSFunction registerTool});
}
