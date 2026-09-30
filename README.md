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

The browser bindings follow the WebMCP Draft Community Group Report dated
29 September 2026, with browser regression tests for the interop contract.
The package implements the current `document.modelContext.registerTool`
shape, execution cancellation through `AbortSignal`, signal-based
unregistration, all four tool annotations, ModelContext lifecycle events,
and `exposedTo` origins. Because WebMCP is
not yet a web standard, minor package releases may add compatibility shims for
browser changes.

Some experimental Chromium builds return `undefined` from `registerTool`
instead of the draft's `Promise<void>`. Both forms are supported.

## Install

```yaml
dependencies:
  flutter_webmcp: ^0.3.1
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
  final tasks = <String>[];

  @override
  void initState() {
    super.initState();
    addTaskTool = WebMcpTypedTool<AddTaskInput>(
      name: 'tasks_add_task',
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
      execute: (input, context) {
        if (!mounted || context.isCancelled) {
          throw const WebMcpToolException(
            code: 'page_unavailable',
            message: 'The task list is no longer available.',
          );
        }
        setState(() => tasks.add(input.title));
        return WebMcpResult.text(
          'Task "${input.title}" was added to the visible list.',
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return WebMcpToolScope(
      tools: [addTaskTool],
      child: TasksView(tasks: tasks),
    );
  }
}
```

Keep tool instances stable, for example in `initState`, a ViewModel, or a
dependency-injection container. Replacing a tool instance tells the scope to
unregister the old configuration and register the new one.

Keep the same instance when only backing state or handler behavior changes.
Create a new instance when agent-facing metadata such as `name`, `description`,
or `inputSchema` changes. Do not mutate an already registered schema map.
Handlers must validate current input, authorization, and preconditions at
execution time; state may have changed since an agent discovered the tool.

Names must be unique across the document, including nested or kept-alive
scopes. Prefer feature-specific names such as `tasks_add_task` or
`checkout_add_item`. A scope checks duplicates within its own list; the
browser registry rejects collisions across scopes.

## WebMCP and remote MCP

Use WebMCP for actions tied to the current page, route, UI, or session: the
visible task list, current selection, unsaved document, or open checkout.
Handlers should use the same application state and actions as the visible UI.
Browser-independent capabilities can be exposed through remote MCP. Simply
mirroring server tools into a page can leave the UI out of sync with results.

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

Detection reports API availability, not guaranteed permission to register.
An origin-keyed agent cluster is also required; registration failures preserve
the browser error as `WebMcpException.cause`. See Browser setup below.

## Annotations

```dart
annotations: const WebMcpAnnotations(
  readOnly: false,
  untrustedContent: false,
  consequential: true,
  debugging: false,
),
```

`consequential` maps to `consequentialHint`: use it for purchases, payments,
bookings, deletion, or other significant effects. `debugging` identifies tools
for testing, inspectors, or devtools. `readOnly` and `untrustedContent` map to
`readOnlyHint` and `untrustedContentHint`. Null hints are omitted; explicit
`false` is preserved. These hints do not enforce permissions or confirmation.

## Lifecycle events

```dart
if (WebMcp.isLifecycleEventsSupported) {
  final subscription = WebMcp.lifecycleEvents.listen((event) {
    debugPrint('${event.toolName}: ${event.type.name}');
  });
  // When the owner ends:
  await subscription.cancel();
}
```

The typed stream listens to `toolactivated` and `toolcancel` on
`document.modelContext`. Each access creates a broadcast stream; native
listeners attach on its first subscription and detach after its last one is
cancelled. No events are buffered without subscribers. Older implementations
can support tool registration without these events; unsupported runtimes
return an empty stream.

Events belong to the tool owner's document, including when another frame
invokes the tool. They do not bubble to `window`. Caller cancellation may
reject `executeTool()` before `toolcancel` arrives asynchronously. Events
contain only a tool name, with no invocation ID: use `context.isCancelled`
inside each handler to distinguish concurrent calls of the same tool.

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

Keep passwords, OTPs, PINs, card security codes, authentication secrets, and
sensitive identifiers out of model-visible schemas and results. Collect them
through normal user-mediated UI when necessary.

Only use `exposedTo` with origins you trust. See [`SECURITY.md`](SECURITY.md)
for reporting and deployment guidance.

## Core Dart API

Code that does not need Flutter widgets can import the core library directly:

```dart
import 'package:flutter_webmcp/webmcp.dart';
```

Then call `WebMcp.registerTool()` and keep the returned
`WebMcpRegistration` for manual cleanup.

To cancel while the browser is still registering the tool, start an attempt
and keep it for the whole lifecycle:

```dart
final attempt = WebMcp.startToolRegistration(tool);
final registration = await attempt.ready;

// When the owner ends. This may also run while `ready` is still pending.
await attempt.cancel();
```

Call `cancel()` as soon as the owner ends, even if `ready` has not completed.
Cancelling a pending attempt makes `ready` complete with a `WebMcpException`.

`registration.unregister()`, `attempt.cancel()`, and scope disposal prevent
new calls. They do not cancel handlers already executing. Registration and
execution have separate signals. For widget-bound work, check `mounted` or an
application lifetime guard before applying results, including after `await`.

`WebMcpToolScope` uses this form internally. When a tool changes, its old
attempt is aborted before the replacement starts; slots whose tool instance
and exposure configuration did not change stay registered.

## Browser setup

WebMCP requires `document.modelContext`. It is available in ChatGPT's in-app
browser. For local Chrome testing, enable
`chrome://flags/#enable-webmcp-testing` and restart Chrome.

The draft requires an origin-keyed agent cluster. Where the browser does not
enable this by default, serve `Origin-Agent-Cluster: ?1` consistently across
the origin. A cluster restriction can reject registration with `SecurityError`.

For pages that should never expose WebMCP tools, serve this HTTP header:

```http
Permissions-Policy: tools=()
```

It disables WebMCP for the document and all descendant frames before page
scripts run. This deployment control supplements application authorization.
A policy restriction can reject registration with `NotAllowedError`.

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
