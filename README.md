# flutter_webmcp

[![CI](https://github.com/KickNext/flutter_webmcp/actions/workflows/ci.yml/badge.svg)](https://github.com/KickNext/flutter_webmcp/actions/workflows/ci.yml)
[![pub package](https://img.shields.io/pub/v/flutter_webmcp.svg)](https://pub.dev/packages/flutter_webmcp)
[![license: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

Expose Flutter Web application actions as typed
[WebMCP](https://webmachinelearning.github.io/webmcp/) tools without writing
JavaScript interop code.

WebMCP is experimental. This package keeps the changing browser bindings behind
a small Dart API and adds Flutter lifecycle management on top.

Try the [live Flutter Web demo](https://kicknext.github.io/flutter_webmcp/).

## Compatibility

| Runtime | Behavior |
| --- | --- |
| Flutter Web (JavaScript) | Supported when the browser exposes WebMCP |
| Flutter Web (WebAssembly) | Supported when the browser exposes WebMCP |
| Android, iOS, desktop, and Dart VM | Safe no-op detection; registration is unsupported |

The package follows the WebMCP Draft Community Group Report. Because that API
is not yet a web standard, minor package releases may add compatibility shims
for browser changes.

## Install

```yaml
dependencies:
  flutter_webmcp: ^0.2.0
```

For a local checkout:

```yaml
dependencies:
  flutter_webmcp:
    path: ../flutter_webmcp
```

## Flutter usage

Create tools once and let `WebMcpToolScope` register them while the feature is
mounted:

```dart
class TasksPageState extends State<TasksPage> {
  late final WebMcpTool addTaskTool;

  @override
  void initState() {
    super.initState();
    addTaskTool = WebMcpTypedTool<AddTaskInput>(
      name: 'add_task',
      title: 'Add task',
      description: 'Adds a task to the list currently open in the app.',
      inputSchema: const {
        'type': 'object',
        'properties': {
          'title': {'type': 'string'},
        },
        'required': ['title'],
      },
      decodeInput: AddTaskInput.fromJson,
      execute: (input, context) async {
        final task = await taskRepository.add(input.title);
        return WebMcpResult.structured(
          {'id': task.id, 'title': task.title},
          text: 'Task "${task.title}" was added.',
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return WebMcpToolScope(
      tools: [addTaskTool],
      child: const TasksView(),
    );
  }
}
```

Keep tool instances stable, for example in `initState`, a ViewModel, or a
dependency-injection container. Replacing a tool instance tells the scope to
unregister the old configuration and register the new one.

## Typed input

```dart
final class AddTaskInput {
  const AddTaskInput(this.title);

  factory AddTaskInput.fromJson(Map<String, Object?> json) {
    final title = json['title'];
    if (title is! String || title.trim().isEmpty) {
      throw const WebMcpToolException(
        code: 'invalid_title',
        message: 'Task title must be a non-empty string.',
      );
    }
    return AddTaskInput(title.trim());
  }

  final String title;
}
```

The original map-based `WebMcpTool` remains available for simple integrations.

## Results and errors

Use helpers instead of building protocol maps manually:

```dart
return WebMcpResult.text('Done');

return WebMcpResult.structured({'taskId': task.id});

throw const WebMcpToolException(
  code: 'task_not_found',
  message: 'The selected task no longer exists.',
);
```

`WebMcpToolException` is converted into a structured `isError` result that an
agent can understand. Unexpected Dart errors are logged and returned as a safe
`internal_error` without exposing local details.

## Feature detection

```dart
final support = WebMcp.support;
if (!support.isSupported) {
  debugPrint(support.message);
}
```

The result distinguishes unsupported platforms, insecure pages, and unavailable
browser APIs. Permission-policy errors are reported when registration is
attempted because current browsers do not expose a reliable read-only policy
signal for WebMCP.

## Logging

```dart
WebMcp.logger = (event) {
  debugPrint(
    '${event.toolName}: ${event.status} in ${event.duration.inMilliseconds}ms',
  );
};
```

Logs include the tool name, decoded JSON input, duration, result, and local
error information. Logger failures never break tool execution.

Inputs and results can contain sensitive data. Redact them before forwarding
events to production telemetry.

## Security

WebMCP tools run with the same authority as your application code. Validate
input in `decodeInput`, enforce authorization inside the handler, and require
normal user confirmation for destructive or sensitive operations. Annotations
are agent hints, not security boundaries.

Only use `exposedTo` with origins you trust. See [`SECURITY.md`](SECURITY.md)
for reporting and deployment guidance.

## Core Dart API

Code that does not need Flutter widgets can import the core library directly:

```dart
import 'package:flutter_webmcp/webmcp.dart';
```

Then call `WebMcp.registerTool()` and keep the returned
`WebMcpRegistration` for manual cleanup.

## Browser setup

WebMCP requires `document.modelContext`. It is available in ChatGPT's in-app
browser. For local Chrome testing, enable
`chrome://flags/#enable-webmcp-testing` and restart Chrome.

- Flutter Web compiled to JavaScript or WebAssembly is supported when the
  browser implements WebMCP.
- Android, iOS, macOS, Windows, Linux, and Dart VM report unsupported.

See the complete application in [`example/lib/main.dart`](example/lib/main.dart).

## Contributing

Issues and pull requests are welcome. Read [`CONTRIBUTING.md`](CONTRIBUTING.md)
and follow the [`CODE_OF_CONDUCT.md`](CODE_OF_CONDUCT.md). Report security
issues privately as described in [`SECURITY.md`](SECURITY.md).

## License

`flutter_webmcp` is available under the [MIT License](LICENSE).
