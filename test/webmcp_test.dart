@TestOn('vm')
library;

import 'package:flutter_webmcp/webmcp.dart';
import 'package:test/test.dart';

void main() {
  WebMcpTool tool({
    String name = 'add_task',
    String description = 'Adds a task.',
    Map<String, Object?>? schema,
  }) =>
      WebMcpTool(
        name: name,
        description: description,
        inputSchema: schema ?? const {'type': 'object'},
        execute: (input, context) => {'ok': true},
      );

  test('reports unsupported outside a browser', () {
    expect(WebMcp.isSupported, isFalse);
  });

  test('rejects an invalid tool name before platform access', () {
    expect(
      () => WebMcp.registerTool(tool(name: 'not a valid name')),
      throwsArgumentError,
    );
  });

  test('accepts 128-character names and rejects longer names', () {
    final validName = 'a' * 128;
    expect(
      () => WebMcp.registerTool(tool(name: validName)),
      throwsUnsupportedError,
    );
    expect(
      () => WebMcp.registerTool(tool(name: '${validName}a')),
      throwsArgumentError,
    );
  });

  test('rejects an empty description before platform access', () {
    expect(
      () => WebMcp.registerTool(tool(description: '  ')),
      throwsArgumentError,
    );
  });

  test('rejects a non-origin exposedTo value', () {
    expect(
      () => WebMcp.registerTool(tool(), exposedTo: const ['not-an-origin']),
      throwsArgumentError,
    );
  });

  test('rejects a schema that cannot be encoded as JSON', () {
    expect(
      () => WebMcp.registerTool(
        tool(schema: {'type': Object()}),
      ),
      throwsArgumentError,
    );
  });

  test('registration is unsupported on the Dart VM', () {
    expect(() => WebMcp.registerTool(tool()), throwsUnsupportedError);
  });

  test('registration handle unregisters once', () async {
    var calls = 0;
    final registration = WebMcpRegistration('test', () => calls++);

    await registration.unregister();
    await registration.unregister();

    expect(calls, 1);
    expect(registration.isRegistered, isFalse);
  });

  test('typed tool decodes input before execution', () async {
    final typedTool = WebMcpTypedTool<int>(
      name: 'double_value',
      description: 'Doubles a value.',
      decodeInput: (input) => input['value']! as int,
      execute: (value, context) => value * 2,
    );

    final result = await typedTool.execute(
      {'value': 4},
      WebMcpExecutionContext(isCancelled: () => false),
    );

    expect(result, 8);
  });

  test('result helpers create JSON-compatible envelopes', () {
    expect(
      WebMcpResult.text('Done').toJson(),
      {
        'content': [
          {'type': 'text', 'text': 'Done'},
        ],
      },
    );
    expect(
      WebMcpResult.error(code: 'failed', message: 'Nope').toJson(),
      containsPair('isError', true),
    );
    expect(
      WebMcpResult.structured({'id': 7}, text: 'Created').toJson(),
      {
        'content': [
          {'type': 'text', 'text': 'Created'},
        ],
        'structuredContent': {'id': 7},
      },
    );
  });
}
