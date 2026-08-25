@TestOn('vm')
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webmcp/flutter_webmcp.dart';

void main() {
  testWidgets('registers tools while mounted and unregisters on dispose', (
    tester,
  ) async {
    final registered = <String>[];
    final unregistered = <String>[];
    final tool = WebMcpTool(
      name: 'test_tool',
      description: 'A test tool.',
      execute: (input, context) => null,
    );

    Future<WebMcpRegistration> registrar(
      WebMcpTool tool, {
      List<String> exposedTo = const [],
    }) async {
      registered.add(tool.name);
      return WebMcpRegistration(
        tool.name,
        () => unregistered.add(tool.name),
      );
    }

    await tester.pumpWidget(
      WebMcpToolScope(
        tools: [tool],
        registrar: registrar,
        supportCheck: () => true,
        child: const Directionality(
          textDirection: TextDirection.ltr,
          child: Text('Child'),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Child'), findsOneWidget);
    expect(registered, ['test_tool']);
    expect(unregistered, isEmpty);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    expect(unregistered, ['test_tool']);
  });

  testWidgets('replaces tools when configuration changes', (tester) async {
    final events = <String>[];

    Future<WebMcpRegistration> registrar(
      WebMcpTool tool, {
      List<String> exposedTo = const [],
    }) async {
      events.add('register:${tool.name}');
      return WebMcpRegistration(
        tool.name,
        () => events.add('unregister:${tool.name}'),
      );
    }

    WebMcpTool tool(String name) => WebMcpTool(
          name: name,
          description: 'Tool $name.',
          execute: (input, context) => null,
        );

    await tester.pumpWidget(
      WebMcpToolScope(
        tools: [tool('first')],
        registrar: registrar,
        supportCheck: () => true,
        child: const SizedBox(),
      ),
    );
    await tester.pump();
    await tester.pumpWidget(
      WebMcpToolScope(
        tools: [tool('second')],
        registrar: registrar,
        supportCheck: () => true,
        child: const SizedBox(),
      ),
    );
    await tester.pump();

    expect(
      events,
      ['register:first', 'unregister:first', 'register:second'],
    );
  });

  testWidgets('does not register when disabled or unsupported', (tester) async {
    var registrations = 0;
    final tool = WebMcpTool(
      name: 'test_tool',
      description: 'A test tool.',
      execute: (input, context) => null,
    );

    Future<WebMcpRegistration> registrar(
      WebMcpTool tool, {
      List<String> exposedTo = const [],
    }) async {
      registrations++;
      return WebMcpRegistration(tool.name, () {});
    }

    await tester.pumpWidget(
      WebMcpToolScope(
        tools: [tool],
        enabled: false,
        registrar: registrar,
        supportCheck: () => true,
        child: const SizedBox(),
      ),
    );
    await tester.pump();
    expect(registrations, 0);

    await tester.pumpWidget(
      WebMcpToolScope(
        tools: [tool],
        registrar: registrar,
        supportCheck: () => false,
        child: const SizedBox(),
      ),
    );
    await tester.pump();
    expect(registrations, 0);
  });

  testWidgets('cleans up partial registration and reports the error', (
    tester,
  ) async {
    final unregistered = <String>[];
    Object? reportedError;
    final tools = [
      WebMcpTool(
        name: 'first',
        description: 'First tool.',
        execute: (input, context) => null,
      ),
      WebMcpTool(
        name: 'second',
        description: 'Second tool.',
        execute: (input, context) => null,
      ),
    ];

    Future<WebMcpRegistration> registrar(
      WebMcpTool tool, {
      List<String> exposedTo = const [],
    }) async {
      if (tool.name == 'second') throw StateError('registration failed');
      return WebMcpRegistration(
        tool.name,
        () => unregistered.add(tool.name),
      );
    }

    await tester.pumpWidget(
      WebMcpToolScope(
        tools: tools,
        registrar: registrar,
        supportCheck: () => true,
        onError: (error, stackTrace) => reportedError = error,
        child: const SizedBox(),
      ),
    );
    await tester.pump();

    expect(unregistered, ['first']);
    expect(reportedError, isA<StateError>());
  });
}
