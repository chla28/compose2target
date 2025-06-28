// bin/compose2target_test.dart
import 'dart:io';
import 'package:test/test.dart';
import '../bin/compose2target.dart' as c2t;

void main() {
  group('ArgParser', () {
    test('buildParser returns parser with expected options', () {
      final parser = c2t.buildParser();
      expect(parser.options, contains('help'));
      expect(parser.options, contains('input'));
      expect(parser.options, contains('output'));
      expect(parser.options, contains('type'));
      expect(parser.options, contains('mapfile'));
    });
  });

  group('Argument handling', () {
    test('Prints usage and exits on help flag', () async {
      // Can't test exit(1) directly, but can check usage output
      // Here, just check that usage string contains expected text
      final parser = c2t.buildParser();
      final buffer = StringBuffer();
      void printOverride(Object? obj) => buffer.writeln(obj);
      c2t.printUsage(parser);
      expect(buffer.toString(), contains('Usage:'));
    });

    test('Fails on unknown type', () async {
      final parser = c2t.buildParser();
      expect(() {
        parser.parse(['-t', 'unknown']);
      }, throwsA(isA<FormatException>()));
    });
  });

  group('workOnFile', () {
    late Directory tempDir;
    late File inputFile;
    late File mapFile;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync();
      inputFile = File('${tempDir.path}/input.yaml')..writeAsStringSync('services:\n  test:\n    image: alpine');
      mapFile = File('${tempDir.path}/map.yaml')..writeAsStringSync('mapping:\n  test: mapped');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('run type with mapping', () async {
      final result = await c2t.workOnFile(inputFile.path, mapFile.path, '', '', 'run', '', false, true, false);
      expect(result, isA<String>());
    });

    test('run type without mapping', () async {
      final result = await c2t.workOnFile(inputFile.path, '', '', '', 'run', '', false, true, false);
      expect(result, isA<String>());
    });

    test('compose type with mapping', () async {
      final result = await c2t.workOnFile(inputFile.path, mapFile.path, '', '', 'compose', '', false, true, false);
      expect(result, isA<String>());
    });

    test('quadlet type with mapping', () async {
      final outFile = '${tempDir.path}/out.container';
      final result = await c2t.workOnFile(inputFile.path, mapFile.path, outFile, '', 'quadlet', '', false, true, false);
      expect(result, isA<String>());
      expect(File(outFile).existsSync(), isTrue);
    });

    test('ha type with mapping', () async {
      final outFile = '${tempDir.path}/out.ha';
      final result = await c2t.workOnFile(inputFile.path, mapFile.path, outFile, '', 'ha', '', false, true, false);
      expect(result, isA<String>());
      expect(File(outFile).existsSync(), isTrue);
    });

    test('mapping type', () async {
      final result = await c2t.workOnFile(inputFile.path, mapFile.path, '', '', 'mapping', '', false, true, false);
      expect(result, isA<String>());
    });

    test('Fails if input file does not exist', () async {
      expect(() async => await c2t.workOnFile('nonexistent.yaml', '', '', '', 'run', '', false, true, false), throwsA(isA<FileSystemException>()));
    });
  });

  group('mainFunction', () {
    test('Handles missing input gracefully', () async {
      // Should print error and not throw
      c2t.mainFunction(['-i', 'nonexistent.yaml', '-t', 'run']);
    });

    test('Handles unknown type', () async {
      c2t.mainFunction(['-t', 'unknown']);
    });
  });
}
