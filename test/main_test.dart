import 'dart:io';
import 'package:args/args.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';
import '../../bin/compose2target.dart' as app; // Assuming app.mainFunction

void main() {
  group('compose2target.dart tests', () {
    late Directory tempDir;
    late String tempDirPath;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('compose2target_test_');
      tempDirPath = tempDir.path;
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    File createDummyFile(String path, String content) {
      final file = File(p.join(tempDirPath, path));
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(content);
      return file;
    }

    Directory createDummyDir(String path) {
      final dir = Directory(p.join(tempDirPath, path));
      dir.createSync(recursive: true);
      return dir;
    }

    group('Argument Parser (buildParser)', () {
      late ArgParser parser;

      setUp(() {
        parser = app.buildParser();
      });

      test('should have all defined flags and options', () {
        expect(parser.options.containsKey('help'), isTrue);
        expect(parser.options.containsKey('verbose'), isTrue);
        expect(parser.options.containsKey('version'), isTrue);
        expect(parser.options.containsKey('metrics'), isTrue);
        expect(parser.options.containsKey('nogeneric'), isTrue);
        expect(parser.options.containsKey('input'), isTrue);
        expect(parser.options.containsKey('output'), isTrue);
        expect(parser.options.containsKey('type'), isTrue);
        expect(parser.options.containsKey('mapfile'), isTrue);
        expect(parser.options.containsKey('network'), isTrue);
        expect(parser.options.containsKey('script'), isTrue);
      });

      test('parses valid arguments correctly', () {
        final args = [
          '-i', 'input.yaml',
          '-o', 'output.yaml',
          '-t', 'compose',
          '-m', 'map.yaml',
          '-n', 'test_net',
          '-s', 'script.sh',
          '--verbose', '--metrics', '--nogeneric'
        ];
        final results = parser.parse(args);
        expect(results['input'], 'input.yaml');
        expect(results['output'], 'output.yaml');
        expect(results['type'], 'compose');
        expect(results['mapfile'], 'map.yaml');
        expect(results['network'], 'test_net');
        expect(results['script'], 'script.sh');
        expect(results['verbose'], isTrue);
        expect(results['metrics'], isTrue);
        expect(results['nogeneric'], isTrue); // nogeneric means addGenericOutput = false
      });

      test('throws FormatException for missing mandatory arguments if any were mandatory by default', () {
        // buildParser() does not mark options as mandatory by default in ArgParser
        // The application logic itself checks for some conditions and exits.
        // This test verifies that ArgParser itself doesn't fail without app logic.
        expect(() => parser.parse([]), returnsNormally);
      });
    });

    group('mainFunction - File Operations', () {
      test('workOnFile: simple compose generation', () async {
        final inputFile = createDummyFile('input.yaml', '''
services:
  app:
    image: myapp
''');
        final outputFile = p.join(tempDirPath, 'output.yaml');
        final args = ['-i', inputFile.path, '-o', outputFile, '-t', 'compose'];
        
        await app.mainFunction(args);

        final outFile = File(outputFile);
        expect(outFile.existsSync(), isTrue);
        final outContent = outFile.readAsStringSync();
        expect(outContent, contains('services:'));
        expect(outContent, contains('app:'));
        expect(outContent, contains('image: myapp'));
      });

      test('workOnFile: run generation with mapfile', () async {
        final inputFile = createDummyFile('input_run.yaml', '''
services:
  runner:
    image: input_image # Will be overridden by mapfile
    ports: ["VAR_PORT:80"] 
''');
        final mapFile = createDummyFile('map_run.yaml', '''
services:
  runner:
    image: mapped_image
variables:
  VAR_PORT: 8080
''');
        final outputFile = p.join(tempDirPath, 'output_run.txt');
        final args = [
          '-i', inputFile.path,
          '-m', mapFile.path,
          '-o', outputFile,
          '-t', 'run'
        ];

        await app.mainFunction(args);
        final outFile = File(outputFile);
        expect(outFile.existsSync(), isTrue);
        final outContent = outFile.readAsStringSync();
        expect(outContent, contains('podman run -d -it --name runner'));
        expect(outContent, contains('-p 8080:80')); // Port resolved
        expect(outContent, contains('mapped_image')); // Image mapped
      });
      
      test('workOnFile: quadlet generation (no mapfile - direct compose input)', () async {
        final inputFile = createDummyFile('input_quadlet.yaml', '''
services:
  web:
    image: nginx
    ports: ["80:8080"]
    restart: always
''');
        final outputFile = p.join(tempDirPath, 'web.quadlet');
        final args = ['-i', inputFile.path, '-o', outputFile, '-t', 'quadlet'];
        
        await app.mainFunction(args);

        final outFile = File(outputFile);
        expect(outFile.existsSync(), isTrue);
        final outContent = outFile.readAsStringSync();
        expect(outContent, contains('[Unit]'));
        expect(outContent, contains('Description=web'));
        expect(outContent, contains('[Container]'));
        expect(outContent, contains('Image=nginx'));
        expect(outContent, contains('PublishPort=80:8080'));
        expect(outContent, contains('[Service]'));
        expect(outContent, contains('Restart=always'));
      });
      
      test('workOnFile: quadlet generation with mapfile (tests intermediate file)', () async {
        final inputFile = createDummyFile('input_for_quadlet_map.yaml', '''
services:
  db:
    image: input_db_image # to be mapped
''');
        final mapFile = createDummyFile('map_for_quadlet.yaml', '''
services:
  db:
    image: mapped_postgres:15
variables: {}
''');
        final outputQuadletFile = p.join(tempDirPath, 'db.quadlet');
        final intermediateComposeFile = p.join(tempDirPath, '${outputQuadletFile}_tmp.yaml');

        final args = [
          '-i', inputFile.path,
          '-m', mapFile.path,
          '-o', outputQuadletFile,
          '-t', 'quadlet'
        ];
        
        await app.mainFunction(args);

        final quadletFile = File(outputQuadletFile);
        expect(quadletFile.existsSync(), isTrue, reason: "Quadlet output file should exist.");
        final quadletContent = quadletFile.readAsStringSync();
        expect(quadletContent, contains('Image=mapped_postgres:15'));
        
        // Check that intermediate file was created then deleted
        expect(File(intermediateComposeFile).existsSync(), isFalse, reason: "Intermediate tmp file should be deleted.");
      });


      test('workOnFile: mapping type (simple variable substitution)', () async {
        final inputFile = createDummyFile('input_mapping_test.yaml', 'Hello \$NAME, welcome to \$PLACE!');
        final mapFile = createDummyFile('map_mapping_test.yaml', '''
variables:
  NAME: TestUser
  PLACE: TestVille
''');
        final outputFile = p.join(tempDirPath, 'output_mapped.txt');
        final args = [
          '-i', inputFile.path,
          '-m', mapFile.path,
          '-o', outputFile,
          '-t', 'mapping'
        ];
        
        await app.mainFunction(args);
        final outFile = File(outputFile);
        expect(outFile.existsSync(), isTrue);
        expect(outFile.readAsStringSync(), 'Hello TestUser, welcome to TestVille!');
      });
      
      test('prints to stdout if outputFilePath is empty', () async {
        // This test is difficult because:
        // 1. `mainFunction` calls `print()`, which is hard to capture in `package:test`.
        // 2. `mainFunction` might call `exit()`, terminating tests.
        // For now, we'll test the argument parsing that leads to this.
        // A full test would require a different setup or refactoring `workOnFile`.
        // We can ensure that `generateOutputFile` is NOT called if output path is empty.
        // This requires checking side effects or refactoring `generateOutputFile`.
        // For now, this test will be conceptual.
        final inputFile = createDummyFile('input_stdout.yaml', 'services: {app: {image: test}}');
        final args = ['-i', inputFile.path, '-t', 'compose']; // No -o

        // No direct way to check print output here without more complex test setup.
        // We're relying on the fact that if -o is not provided, it should print.
        // If it tries to write to a file with an empty path, it might error or behave unexpectedly.
        // The code has `if (outputFilePath.isEmpty) { print(outputStr); }`
        // So, if it completes without error, it implies it took the print path.
        try {
          await app.mainFunction(args);
          // If it reaches here, it means it didn't crash trying to write to an empty file path.
          // This is a weak test for the print path.
          succeed('Test conceptually passed: mainFunction completed for stdout path.');
        } catch (e) {
          fail('mainFunction call for stdout failed: $e');
        }
      });
    });

    group('mainFunction - Folder Operations', () {
      late Directory inputDir;
      late Directory outputDir;

      setUp(() {
        inputDir = createDummyDir('input_folder');
        outputDir = createDummyDir('output_folder');
        createDummyFile(p.join('input_folder', 'file1.yaml'), 'services: {srv1: {image: img1}}');
        createDummyFile(p.join('input_folder', 'file2.yaml'), 'services: {srv2: {image: img2}}');
      });

      test('workOnFolder: processes multiple files', () async {
        final args = [
          '-i', inputDir.path,
          '-o', outputDir.path,
          '-t', 'compose'
        ];
        await app.mainFunction(args);

        expect(File(p.join(outputDir.path, 'file1.yaml')).existsSync(), isTrue);
        expect(File(p.join(outputDir.path, 'file2.yaml')).existsSync(), isTrue);
        final content1 = File(p.join(outputDir.path, 'file1.yaml')).readAsStringSync();
        expect(content1, contains('srv1:'));
        expect(content1, contains('image: img1'));
      });

      test('workOnFolder: generates script when --script is provided', () async {
        final scriptName = p.join(outputDir.path, 'deploy.sh');
        final args = [
          '-i', inputDir.path,
          '-o', outputDir.path, // outputDir.path is used as DEFAULTFILE base for script
          '-t', 'compose',
          '-s', scriptName 
        ];
        await app.mainFunction(args);

        expect(File(scriptName).existsSync(), isTrue);
        final scriptContent = File(scriptName).readAsStringSync();
        expect(scriptContent, contains('#!/bin/bash'));
        // DEFAULTFILE in script is the output directory when -o is a dir for workOnFolder
        expect(scriptContent, contains('DEFAULTFILE="${outputDir.path}"')); 
        expect(scriptContent, contains('podman-compose -f ${outputDir.path}/file1.yaml up -d'));
        expect(scriptContent, contains('podman-compose -f ${outputDir.path}/file2.yaml up -d'));
      });
    });
    
    group('mainFunction - Error Handling and Flags (Conceptual due to exit())', () {
      // Tests for --help, --version, file not found, bad type are hard due to exit()
      // These tests will verify argument parsing setup rather than full execution.
      test('--help flag is parsed', () {
        final results = app.buildParser().parse(['--help']);
        expect(results.wasParsed('help'), isTrue);
        // In real execution, mainFunction would print help and exit(1)
      });

      test('--version flag is parsed', () {
        final results = app.buildParser().parse(['--version']);
        expect(results.wasParsed('version'), isTrue);
        // In real execution, mainFunction would print version and exit(1)
      });

      test('input file not found (conceptual - parser level)', () {
        // mainFunction itself would print error and exit(1)
        // We test that the argument is parsed; the app logic handles the file check.
        final args = ['-i', 'non_existent_file.yaml', '-t', 'compose'];
        final results = app.buildParser().parse(args);
        expect(results['input'], 'non_existent_file.yaml');
        // Manually check what mainFunction would do:
        // expect(File('non_existent_file.yaml').existsSync(), isFalse);
        // Then mainFunction would call exit(1).
      });

      test('invalid type (conceptual - parser level)', () {
        final args = ['-i', 'dummy.yaml', '-t', 'invalid_type'];
        final results = app.buildParser().parse(args);
        expect(results['type'], 'invalid_type');
        // Manually check:
        // expect(app.typeList.contains('invalid_type'), isFalse);
        // Then mainFunction would call exit(1).
      });

       test('--nogeneric flag sets addGenericOutput to false', () async {
        // This test checks if the flag influences the call to workOnFile correctly.
        // We need an input and mapfile that would normally produce generic output.
        final inputFile = createDummyFile('input_nogeneric.yaml', '''
services:
  app:
    image: myapp
''');
        final mapFile = createDummyFile('map_nogeneric.yaml', '''
services:
  app:
    image: myapp # no specific mapped env
genericoutput:
  environment:
    - GENERIC_ENV_VAR=true 
variables: {}
''');
        final outputFile = p.join(tempDirPath, 'output_nogeneric.yaml');
        // First run WITH generic output (default)
        await app.mainFunction([
          '-i', inputFile.path, 
          '-m', mapFile.path, 
          '-o', outputFile, 
          '-t', 'compose' 
        ]);
        expect(File(outputFile).readAsStringSync(), contains('GENERIC_ENV_VAR=true'));

        // Second run with --nogeneric
        final outputFileNoGeneric = p.join(tempDirPath, 'output_no_generic_flag.yaml');
        await app.mainFunction([
          '-i', inputFile.path, 
          '-m', mapFile.path, 
          '-o', outputFileNoGeneric, 
          '-t', 'compose',
          '--nogeneric'
        ]);
        expect(File(outputFileNoGeneric).readAsStringSync(), isNot(contains('GENERIC_ENV_VAR=true')));
      });
    });
  });
}
