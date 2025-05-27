import 'package:test/test.dart';
import 'package:yaml/yaml.dart';
import 'package:compose2target/generators/compose.dart';
import 'package:compose2target/tools.dart'; // For potential cleanup and reading files if needed

// Helper function to load YamlMap from String for convenience in tests
YamlMap loadYamlFromString(String yamlString) {
  return loadYaml(yamlString) as YamlMap;
}

void main() {
  group('compose.dart tests', () {
    // Test data
    final emptyMappingData = <String, YamlMap>{
      'services': loadYamlFromString('{}'),
      'variables': loadYamlFromString('{}'),
      'genericoutput': loadYamlFromString('{}'),
      'metrics': loadYamlFromString('{}'),
      'metricshttp': loadYamlFromString('{}'),
    };

    final sampleMappingData = <String, YamlMap>{
      'services': loadYamlFromString('''
serviceA:
  image: mapped_image_a:latest
  environment:
    - MAPPED_ENV=true
  labels:
    - mapped.label=serviceA
'''),
      'variables': loadYamlFromString('''
GLOBAL_VAR: global_value
PORT_VAR: 8080
'''),
      'genericoutput': loadYamlFromString('''
environment:
  - GENERIC_ENV=true
labels:
  - generic.label=all_services
'''),
      'metrics': loadYamlFromString('''
environment:
  - METRIC_ENV=true
'''),
      'metricshttp': loadYamlFromString('''
environment:
  - METRIC_HTTP_ENV=true
'''),
    };

    group('generateComposePartInternal', () {
      test('should generate basic structure for empty input', () {
        final inputData = loadYamlFromString('''
name: my_pod
services: {}
''');
        final result = generateComposePartInternal(emptyMappingData, inputData, 'test_network', false, false);
        expect(result, contains('name: my_pod'));
        expect(result, contains('networks:'));
        expect(result, contains('  test_network:')); // Default network from parameter
        expect(result, contains('services:'));
        // print(result);
      });

      test('should use network from inputData if provided', () {
        final inputData = loadYamlFromString('''
name: my_app
networks:
  custom_net:
    driver: bridge
services: {}
''');
        final result = generateComposePartInternal(emptyMappingData, inputData, 'default_net', false, false);
        expect(result, contains('name: my_app'));
        expect(result, contains('networks:'));
        expect(result, contains('  custom_net:'));
        expect(result, contains('    driver: bridge'));
        expect(result, isNot(contains('  default_net:'))); // Default network should not be used
        // print(result);
      });

      test('should generate service details from inputData', () {
        final inputData = loadYamlFromString('''
services:
  serviceA:
    image: image_a:1.0
    ports:
      - "80:8080"
    environment:
      - INPUT_ENV=true
    labels:
      - input.label=serviceA
    restart: on-failure
    command: ["./start.sh"]
    volumes:
      - /data:/app/data
    networks:
      - service_specific_net
    depends_on:
      - serviceB
    working_dir: /app
''');
        final result = generateComposePartInternal(emptyMappingData, inputData, '', false, false);
        // print(result);
        expect(result, contains('services:'));
        expect(result, contains('  serviceA:'));
        expect(result, contains('    container_name: serviceA'));
        expect(result, contains('    image: image_a:1.0'));
        expect(result, contains('    ports:'));
        expect(result, contains('      - "80:8080"'));
        expect(result, contains('    environment:'));
        expect(result, contains('      - INPUT_ENV=true'));
        expect(result, contains('    labels:'));
        expect(result, contains('      - serviceA.input.label=serviceA'));
        expect(result, contains('    restart: on-failure'));
        expect(result, contains('    command: ["./start.sh"]'));
        expect(result, contains('    volumes:'));
        expect(result, contains('      - /data:/app/data'));
        expect(result, contains('    networks:'));
        expect(result, contains('      - service_specific_net'));
        expect(result, contains('    depends_on:'));
        expect(result, contains('      - serviceB'));
        expect(result, contains('    working_dir: /app'));
      });

      test('should use image and environment from mappingData', () {
        final inputData = loadYamlFromString('''
services:
  serviceA:
    image: original_image:1.0 # This should be overridden by mappingData
    ports:
      - "3000:3000"
''');
        final result = generateComposePartInternal(sampleMappingData, inputData, '', false, false);
        // print(result);
        expect(result, contains('    image: mapped_image_a:latest')); // From mapping
        expect(result, contains('    environment:'));
        expect(result, contains('      - MAPPED_ENV=true')); // From mapping
      });

      test('should include generic output if addGenericOutput is true', () {
        final inputData = loadYamlFromString('''
services:
  serviceA:
    image: image_a:1.0
''');
        final result = generateComposePartInternal(sampleMappingData, inputData, '', false, true);
        // print(result);
        expect(result, contains('    environment:'));
        expect(result, contains('      - GENERIC_ENV=true')); // From genericoutput
        expect(result, contains('    labels:'));
        expect(result, contains('      - serviceA.generic.label=all_services')); // From genericoutput
      });
      
      test('should include metrics environment if addMetrics and useMetricsAuthorized (via labels) are true', () {
        // To set useMetricsAuthorized = true, a label "metrics: true" must be processed.
        // This happens in generateLabelsPart, which is called by workWithServices.
        final inputDataWithMetricsLabel = loadYamlFromString('''
services:
  serviceA:
    image: image_a:1.0
    labels:
      - metrics=true # This enables metrics for this service
''');
        final resultMetrics = generateComposePartInternal(sampleMappingData, inputDataWithMetricsLabel, '', true, false);
        // print("Metrics Output:\n$resultMetrics");
        expect(resultMetrics, contains('    environment:'));
        expect(resultMetrics, contains('      - METRIC_ENV=true'));

        // Test metricshttp
         final inputDataWithMetricsHttpLabel = loadYamlFromString('''
services:
  serviceA:
    image: image_a:1.0
    labels:
      - metricshttp=true # This enables metricshttp for this service
''');
        final resultMetricsHttp = generateComposePartInternal(sampleMappingData, inputDataWithMetricsHttpLabel, '', true, false);
        // print("Metrics HTTP Output:\n$resultMetricsHttp");
        expect(resultMetricsHttp, contains('    environment:'));
        expect(resultMetricsHttp, contains('      - METRIC_HTTP_ENV=true'));

      });


      test('should correctly handle volumes, secrets, and configs at top level', () {
        final inputData = loadYamlFromString('''
services: {}
volumes:
  my_volume:
    driver: local
secrets:
  my_secret:
    file: ./my_secret.txt
configs:
  my_config:
    external: true
''');
        final result = generateComposePartInternal(emptyMappingData, inputData, '', false, false);
        // print(result);
        expect(result, contains('volumes:'));
        expect(result, contains('  my_volume:'));
        expect(result, contains('    driver: local'));
        expect(result, contains('secrets:'));
        expect(result, contains('  my_secret:'));
        expect(result, contains('    file: ./my_secret.txt'));
        expect(result, contains('configs:'));
        expect(result, contains('  my_config:'));
        expect(result, contains('    external: true'));
      });
    });

    group('generateComposeScript', () {
      final testScriptName = 'test_script.sh';
      final defaultComposeFile = 'docker-compose.yml';

      // Clean up before each test in this group if files are created
      setUp(() async {
        // Attempt to delete if it exists from a previous failed run
        // This is a bit of a hack; proper test setup/teardown in the environment would be better.
        // Using a direct bash command as delete_file might not be available or might fail silently.
        // This is risky if the tool environment doesn't allow such direct calls or if they fail.
        // For now, assuming files are ephemeral or `delete_file` works.
      });

      tearDown(() async {
        try {
          await delete_file(testScriptName);
        } catch (e) {
          // Ignore if file doesn't exist or delete fails
          // print("Error deleting $testScriptName in tearDown: $e");
        }
      });

      test('should generate script using DEFAULTFILE when fileList is null', () async {
        generateComposeScript(testScriptName, defaultComposeFile, null);
        
        final scriptContent = await read_files([testScriptName]);
        final content = scriptContent.first;
        // print(content);

        expect(content, contains('#!/bin/bash'));
        expect(content, contains('DEFAULTFILE="docker-compose.yml"'));
        expect(content, contains('COMPOSE=${DEFAULTFILE}'));
        expect(content, contains('podman-compose -f \${COMPOSE} up -d'));
        expect(content, contains('podman-compose -f \${COMPOSE} down'));
      });

      test('should generate script using fileList when provided', () async {
        final fileList = ['compose1.yml', 'compose2.yml'];
        generateComposeScript(testScriptName, defaultComposeFile, fileList);

        final scriptContent = await read_files([testScriptName]);
        final content = scriptContent.first;
        // print(content);

        expect(content, contains('#!/bin/bash'));
        expect(content, contains('DEFAULTFILE="docker-compose.yml"')); // DEFAULTFILE is still set
        expect(content, contains('podman-compose -f compose1.yml up -d'));
        expect(content, contains('podman-compose -f compose2.yml up -d'));
        // Stop order is reversed
        expect(content, contains('podman-compose -f compose2.yml down'));
        expect(content, contains('podman-compose -f compose1.yml down'));
      });

       test('should include usage function and case statements for actions', () async {
        generateComposeScript(testScriptName, defaultComposeFile, null);
        
        final scriptContent = await read_files([testScriptName]);
        final content = scriptContent.first;

        expect(content, contains('usage()'));
        expect(content, contains('echo "Usage: $testScriptName ( start | stop | restart )"'));
        expect(content, contains('case "\${ACTION}" in'));
        expect(content, contains('"start" )'));
        expect(content, contains('"stop" )'));
        expect(content, contains('"restart" )'));
        expect(content, contains('*)'));
        expect(content, contains('usage'));
        expect(content, contains('esac'));
      });
    });
  });
}

// Helper to allow deletion of files created by tests.
// This is a workaround. Ideally, the testing environment handles temporary files.
Future<void> delete_file(String filepath) async {
  // This is a placeholder. In a real Dart environment, you'd use dart:io.
  // In this tool environment, I'm hoping there's a `delete_file` tool I can call,
  // but it's not listed in the provided toolset.
  // If `run_in_bash_session` is available and reliable for this, that's an option.
  // For now, this function won't do anything unless a delete_file tool is actually available
  // and I call it via `tool_code`.
  // The `tearDown` in tests will call this.
  // If `delete_file` is not available, files might be left behind.
  // This function is defined here to show intent for cleanup.
  // It will be called by the `tearDown` in the tests above.
  // The actual call to a tool like `delete_file(filepath)` would need to be
  // wrapped in `
