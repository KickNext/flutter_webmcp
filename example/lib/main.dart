import 'package:flutter/material.dart';
import 'package:flutter_webmcp/flutter_webmcp.dart';

void main() => runApp(const WebMcpDemoApp());

class WebMcpDemoApp extends StatelessWidget {
  const WebMcpDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const TaskDemoPage(),
    );
  }
}

class TaskDemoPage extends StatefulWidget {
  const TaskDemoPage({super.key});

  @override
  State<TaskDemoPage> createState() => _TaskDemoPageState();
}

class _TaskDemoPageState extends State<TaskDemoPage> {
  final _controller = TextEditingController();
  final _tasks = <String>['Open this page in a WebMCP browser'];
  late final WebMcpTool _addTaskTool;
  Object? _registrationError;

  @override
  void initState() {
    super.initState();
    _addTaskTool = WebMcpTypedTool<AddTaskInput>(
      name: 'add_task',
      title: 'Add task',
      description: 'Adds a task to the list visible on this page.',
      inputSchema: const {
        'type': 'object',
        'properties': {
          'title': {
            'type': 'string',
            'description': 'Short task title.',
          },
        },
        'required': ['title'],
      },
      decodeInput: AddTaskInput.fromJson,
      execute: (input, context) {
        if (context.isCancelled) {
          throw const WebMcpToolException(
            code: 'cancelled',
            message: 'Task creation was cancelled.',
          );
        }
        if (mounted) setState(() => _tasks.add(input.title));
        return WebMcpResult.text('Task "${input.title}" was added.');
      },
    );
  }

  void _handleWebMcpError(Object error, StackTrace stackTrace) {
    if (mounted) {
      setState(() {
        _registrationError = error;
      });
    }
  }

  void _addManually() {
    final title = _controller.text.trim();
    if (title.isEmpty) return;
    setState(() => _tasks.add(title));
    _controller.clear();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final support = WebMcp.support;

    return WebMcpToolScope(
      tools: [_addTaskTool],
      onError: _handleWebMcpError,
      child: Scaffold(
        appBar: AppBar(title: const Text('Flutter WebMCP demo')),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Card(
                  color: support.isSupported
                      ? Colors.green.withValues(alpha: 0.12)
                      : Colors.orange.withValues(alpha: 0.12),
                  child: ListTile(
                    leading: Icon(
                      support.isSupported ? Icons.check_circle : Icons.info,
                    ),
                    title: Text(support.message),
                    subtitle: _registrationError == null
                        ? const Text('Tool name: add_task')
                        : Text('Error: $_registrationError'),
                  ),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _controller,
                  onSubmitted: (_) => _addManually(),
                  decoration: InputDecoration(
                    labelText: 'New task',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      onPressed: _addManually,
                      icon: const Icon(Icons.add),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Tasks', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                for (final task in _tasks)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.task_alt),
                      title: Text(task),
                    ),
                  ),
                const SizedBox(height: 24),
                const Text(
                  'Ask the browser agent: “Add a task called Test Flutter”. '
                  'The agent should call add_task and the new item should appear '
                  'in this list.',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

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
