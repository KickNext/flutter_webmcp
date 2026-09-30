import 'dart:async';
import 'dart:convert';
import 'dart:io';

// No browser automation dependency: Chrome reports results over loopback HTTP.
Future<void> main(List<String> arguments) async {
  final executable = Platform.environment['CHROME_EXECUTABLE'] ??
      (Platform.isWindows
          ? r'C:\Program Files\Google\Chrome\Application\chrome.exe'
          : 'google-chrome');
  if (!arguments.contains('--serve')) {
    // package:test's settings merge drops CHROME_EXECUTABLE when adding flags.
    // Write the selected executable explicitly to the isolated native config.
    final config = File('.dart_tool/native_browser.yaml');
    await config.writeAsString('override_platforms:\n'
        '  chrome:\n'
        '    settings:\n'
        '      executable: ${jsonEncode(executable)}\n'
        '      arguments: --enable-features=WebMCPTesting '
        '--enable-blink-features=WebMCP,WebMCPTesting\n');
    final tests = await Process.start(Platform.resolvedExecutable, [
      'test',
      '-p',
      'chrome',
      'test/webmcp_native_browser_test.dart',
    ], environment: {
      'DART_TEST_CONFIG': config.absolute.path
    });
    await Future.wait(
        [stdout.addStream(tests.stdout), stderr.addStream(tests.stderr)]);
    final testExit = await tests.exitCode;
    if (testExit != 0) {
      exitCode = testExit;
      return;
    }
  }
  final compile = await Process.run(Platform.resolvedExecutable, [
    'compile',
    'js',
    'test/fixtures/native_policy_probe.dart',
    '-o',
    'build/native_policy/probe.js',
  ]);
  if (compile.exitCode != 0) {
    stderr.write(compile.stderr);
    stderr.write(compile.stdout);
    exitCode = compile.exitCode;
    return;
  }
  final script = await File('build/native_policy/probe.js').readAsBytes();
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  final origin = 'http://127.0.0.1:${server.port}';
  final results = <String, Completer<Map<String, dynamic>>>{
    for (final path in ['/allowed', '/blocked']) path: Completer(),
  };
  server.listen((request) async {
    request.response.headers.set('Origin-Agent-Cluster', '?1');
    final path = request.uri.path;
    if (path == '/result' && request.method == 'POST') {
      final report = jsonDecode(await utf8.decoder.bind(request).join())
          as Map<String, dynamic>;
      final result = results[report['path']];
      if (result != null && !result.isCompleted) result.complete(report);
    } else if (path == '/probe.js') {
      request.response.headers.contentType = ContentType('text', 'javascript');
      request.response.add(script);
    } else if (results.containsKey(path)) {
      if (path == '/blocked') {
        request.response.headers.set('Permissions-Policy', 'tools=()');
      }
      request.response.headers.contentType = ContentType.html;
      request.response
          .write('<!doctype html><title>Native WebMCP policy</title>'
              '<body><pre id="result">Checking $path...</pre>'
              '<script src="/probe.js"></script></body>');
    } else {
      request.response.statusCode = HttpStatus.notFound;
    }
    await request.response.close();
  });
  stdout.writeln('Native policy fixtures: $origin/allowed and $origin/blocked');
  if (arguments.contains('--serve')) return; // Keep server alive for UI checks.

  try {
    for (final entry in results.entries) {
      final profile = await Directory.systemTemp.createTemp('webmcp_policy_');
      Process? browser;
      try {
        browser = await Process.start(executable, [
          '--headless',
          '--no-first-run',
          '--no-default-browser-check',
          '--user-data-dir=${profile.path}',
          '--enable-features=WebMCPTesting',
          '--enable-blink-features=WebMCP,WebMCPTesting',
          '$origin${entry.key}',
        ]);
        browser.stdout.drain<void>();
        browser.stderr.drain<void>();
        final report =
            await entry.value.future.timeout(const Duration(seconds: 45));
        stdout.writeln(jsonEncode(report));
        if (report['passed'] != true) exitCode = 1;
      } finally {
        if (browser != null) {
          browser.kill();
          await browser.exitCode;
        }
        // Chrome may take a moment to release profile files on Windows.
        try {
          await profile.delete(recursive: true);
        } on FileSystemException {
          stderr.writeln('Temporary Chrome profile remains: ${profile.path}');
        }
      }
    }
  } catch (error) {
    stderr.writeln(error);
    exitCode = 1;
  } finally {
    await server.close(force: true);
  }
}
