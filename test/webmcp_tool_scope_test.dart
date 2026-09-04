@TestOn('vm')
library;

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webmcp/flutter_webmcp.dart';

void main() {
  WebMcpTool tool(String name, {String? description}) => WebMcpTool(
        name: name,
        description: description ?? 'Tool $name.',
        execute: (input, context) => null,
      );

  testWidgets('registers tools while mounted and cancels them on dispose', (
    tester,
  ) async {
    final events = <String>[];

    WebMcpRegistrationAttempt starter(
      WebMcpTool tool, {
      List<String> exposedTo = const [],
    }) {
      events.add('start:${tool.name}');
      void cancel() => events.add('cancel:${tool.name}');

      return WebMcpRegistrationAttempt(
        ready: Future.value(WebMcpRegistration(tool.name, cancel)),
        cancel: cancel,
      );
    }

    await tester.pumpWidget(
      WebMcpToolScope(
        tools: [tool('test_tool')],
        registrationStarter: starter,
        supportCheck: () => true,
        child: const Directionality(
          textDirection: TextDirection.ltr,
          child: Text('Child'),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Child'), findsOneWidget);
    expect(events, ['start:test_tool']);

    await tester.pumpWidget(const SizedBox.shrink());

    expect(events, ['start:test_tool', 'cancel:test_tool']);
  });

  testWidgets('cancels a pending version before starting its replacement', (
    tester,
  ) async {
    final events = <String>[];
    final errors = <Object>[];
    final pending = Completer<WebMcpRegistration>();
    var starts = 0;

    WebMcpRegistrationAttempt starter(
      WebMcpTool tool, {
      List<String> exposedTo = const [],
    }) {
      starts++;
      final version = starts;
      events.add('start:$version');
      return WebMcpRegistrationAttempt(
        ready: version == 1
            ? pending.future
            : Future.value(WebMcpRegistration(tool.name, () {
                events.add('cancel:$version');
                if (version == 2) throw StateError('active cleanup failed');
              })),
        cancel: () {
          events.add('cancel:$version');
        },
      );
    }

    await tester.pumpWidget(
      WebMcpToolScope(
        tools: [tool('same_name', description: 'First version.')],
        registrationStarter: starter,
        supportCheck: () => true,
        onError: (error, stackTrace) => errors.add(error),
        child: const SizedBox(),
      ),
    );
    await tester.pumpWidget(
      WebMcpToolScope(
        tools: [tool('same_name', description: 'Second version.')],
        registrationStarter: starter,
        supportCheck: () => true,
        onError: (error, stackTrace) => errors.add(error),
        child: const SizedBox(),
      ),
    );

    expect(events, ['start:1', 'cancel:1', 'start:2']);
    expect(errors, isEmpty);

    pending.completeError(const WebMcpException('Registration cancelled.'));
    await tester.pump();
    expect(events, ['start:1', 'cancel:1', 'start:2']);
    expect(errors, isEmpty);

    await tester.pumpWidget(
      WebMcpToolScope(
        tools: [tool('same_name', description: 'Third version.')],
        registrationStarter: starter,
        supportCheck: () => true,
        onError: (error, stackTrace) => errors.add(error),
        child: const SizedBox(),
      ),
    );
    await tester.pump();

    expect(events, [
      'start:1',
      'cancel:1',
      'start:2',
      'cancel:2',
      'start:3',
    ]);
    expect(errors.single, isA<StateError>());
  });

  testWidgets('keeps unchanged names active while other names change', (
    tester,
  ) async {
    final events = <String>[];

    WebMcpRegistrationAttempt starter(
      WebMcpTool tool, {
      List<String> exposedTo = const [],
    }) {
      events.add('start:${tool.name}');
      void cancel() => events.add('cancel:${tool.name}');

      return WebMcpRegistrationAttempt(
        ready: Future.value(WebMcpRegistration(tool.name, cancel)),
        cancel: cancel,
      );
    }

    final stable = tool('stable');
    await tester.pumpWidget(
      WebMcpToolScope(
        tools: [stable, tool('old')],
        registrationStarter: starter,
        supportCheck: () => true,
        child: const SizedBox(),
      ),
    );
    await tester.pumpWidget(
      WebMcpToolScope(
        tools: [stable, tool('new')],
        registrationStarter: starter,
        supportCheck: () => true,
        child: const SizedBox(),
      ),
    );

    expect(
      events,
      ['start:stable', 'start:old', 'cancel:old', 'start:new'],
    );
  });

  testWidgets('reports registration errors without cancelling other names', (
    tester,
  ) async {
    final errors = <Object>[];
    final events = <String>[];

    WebMcpRegistrationAttempt starter(
      WebMcpTool tool, {
      List<String> exposedTo = const [],
    }) {
      events.add('start:${tool.name}');
      return WebMcpRegistrationAttempt(
        ready: tool.name == 'broken'
            ? Future.error(StateError('registration failed'))
            : Future.value(WebMcpRegistration(tool.name, () {})),
        cancel: () => events.add('cancel:${tool.name}'),
      );
    }

    await tester.pumpWidget(
      WebMcpToolScope(
        tools: [tool('working'), tool('broken')],
        registrationStarter: starter,
        supportCheck: () => true,
        onError: (error, stackTrace) => errors.add(error),
        child: const SizedBox(),
      ),
    );
    await tester.pump();

    expect(events, ['start:working', 'start:broken']);
    expect(errors.single, isA<StateError>());
  });

  testWidgets('reports synchronous errors after the build phase', (
    tester,
  ) async {
    var errorCount = 0;
    late StateSetter setParentState;
    final duplicate = tool('duplicate');
    final tools = [duplicate, duplicate];

    WebMcpRegistrationAttempt starter(
      WebMcpTool tool, {
      List<String> exposedTo = const [],
    }) =>
        WebMcpRegistrationAttempt(
          ready: Future.value(WebMcpRegistration(tool.name, () {})),
          cancel: () {},
        );

    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          setParentState = setState;
          return WebMcpToolScope(
            tools: tools,
            registrationStarter: starter,
            supportCheck: _supported,
            onError: (error, stackTrace) {
              errorCount++;
              setParentState(() {});
            },
            child: const SizedBox(),
          );
        },
      ),
    );
    await tester.pump();

    expect(errorCount, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('disabling cancels without checking support', (tester) async {
    var starts = 0;
    var cancels = 0;
    final testTool = tool('test_tool');

    WebMcpRegistrationAttempt starter(
      WebMcpTool tool, {
      List<String> exposedTo = const [],
    }) {
      starts++;
      void cancel() => cancels++;

      return WebMcpRegistrationAttempt(
        ready: Future.value(WebMcpRegistration(tool.name, cancel)),
        cancel: cancel,
      );
    }

    await tester.pumpWidget(
      WebMcpToolScope(
        tools: [testTool],
        registrationStarter: starter,
        supportCheck: () => true,
        child: const SizedBox(),
      ),
    );
    await tester.pumpWidget(
      WebMcpToolScope(
        tools: [testTool],
        enabled: false,
        registrationStarter: starter,
        supportCheck: () => throw StateError('must not be called'),
        child: const SizedBox(),
      ),
    );

    expect(starts, 1);
    expect(cancels, 1);
  });

  testWidgets('dispose cancels every slot before reporting errors', (
    tester,
  ) async {
    var showScope = true;
    var errors = 0;
    late StateSetter setParentState;
    final cancelled = <String>[];

    WebMcpRegistrationAttempt starter(
      WebMcpTool tool, {
      List<String> exposedTo = const [],
    }) {
      void cancel() {
        cancelled.add(tool.name);
        throw StateError('cancel failed');
      }

      return WebMcpRegistrationAttempt(
        ready: Future.value(WebMcpRegistration(tool.name, cancel)),
        cancel: cancel,
      );
    }

    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          setParentState = setState;
          return showScope
              ? WebMcpToolScope(
                  tools: [tool('first'), tool('second')],
                  registrationStarter: starter,
                  supportCheck: _supported,
                  onError: (error, stackTrace) {
                    errors++;
                    setParentState(() {});
                  },
                  child: const SizedBox(),
                )
              : const SizedBox();
        },
      ),
    );

    setParentState(() => showScope = false);
    await tester.pump();
    await tester.pump();

    expect(cancelled, ['first', 'second']);
    expect(errors, 2);
    expect(tester.takeException(), isNull);
  });
}

bool _supported() => true;
