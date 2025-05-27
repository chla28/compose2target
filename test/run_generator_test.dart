import 'package:test/test.dart';
import 'package:yaml/yaml.dart';
import 'package:compose2target/generators/run.dart'; // Adjust if necessary

// Helper function to load YamlMap from String for convenience in tests
YamlMap loadYamlFromString(String yamlString) {
  if (yamlString.trim().isEmpty) {
    return loadYaml('{}') as YamlMap;
  }
  return loadYaml(yamlString) as YamlMap;
}

// Helper to normalize command strings for comparison
// (join lines, replace multiple spaces with one, trim)
String normalizeCommand(String commandString) {
  return commandString
      .replaceAll('\\\n', '') // Join multi-line commands
      .split('\n')
      .map((s) => s.trim().replaceAll(RegExp(r'\s+'), ' '))
      .where((s) => s.isNotEmpty)
      .join('\n');
}

void main() {
  group('run.dart tests', () {
    // Common test data
    final emptyInputData = loadYamlFromString('services: {}');
    final sampleInputData = loadYamlFromString('''
services:
  serviceA:
    image: input_image_a:latest # This will be used by WithoutMapping, ignored by WithMapping if mapping exists
    command: input_command_A
    ports:
      - "8080:80"
      - "VAR_PORT:81" 
    environment:
      - INPUT_VAR_A=valueA
      - "GREETING=Hello \$NAME"
    volumes:
      - /input/data_a:/container/data_a # Used by WithoutMapping
      # For WithMapping, it expects to find '/container/data_a' as a value in mappingData.services.serviceA.volumes
  serviceB:
    image: input_image_b:1.0
    command: ["./start.sh", "b"]
    environment:
      - INPUT_VAR_B=valueB
''');

    final emptyMappingData = <String, YamlMap>{
      'services': loadYamlFromString('{}'),
      'variables': loadYamlFromString('{}'),
      // genericoutput and metrics are not used by run.dart functions directly
    };

    final sampleMappingData = <String, YamlMap>{
      'services': loadYamlFromString('''
serviceA:
  image: mapped_image_a:v1 # Override
  command: mapped_command_A \$PARAM # Override and uses variable
  environment:
    - MAPPED_VAR_A=mappedValueA
  volumes: # For generateRunPartInternal, these are host paths mapped to container paths from inputData
    - /mapped/host_data_a:/container/data_a # value /container/data_a is searched from inputData
serviceB:
  image: mapped_image_b:v2
  # command not in mapping, will take from inputData
'''),
      'variables': loadYamlFromString('''
NAME: World
PARAM: mapped_param
VAR_PORT: 9090 
# Note: VAR_PORT from variables is used by generateRunPartInternal for port mapping
'''),
    };

    // Unused parameters in the current implementation, but passed for signature compatibility
    final String testNetworkName = "test_net";
    final bool testAddMetrics = false;
    final bool testAddGenericOutput = false;

    group('generateRunPartInternal', () {
      test('should return empty string for empty inputData services', () {
        final result = generateRunPartInternal(
            emptyMappingData, emptyInputData, testNetworkName, testAddMetrics, testAddGenericOutput);
        expect(result, isEmpty);
      });

      test('should generate basic podman run command using mappingData', () {
        final inputForServiceAOnly = loadYamlFromString('''
services:
  serviceA:
    image: ignored_input_image 
    ports: 
      - "VAR_PORT:80" # VAR_PORT will be resolved from mappingData.variables
    volumes: # This volume definition is used to find the container path for mapping
      - /ignored_host_path:/container/data_a 
''');
        final result = generateRunPartInternal(
            sampleMappingData, inputForServiceAOnly, testNetworkName, testAddMetrics, testAddGenericOutput);
        final norm = normalizeCommand(result);
        // print("WithMapping Basic:\n$norm");

        expect(norm, contains('podman run -d -it --name serviceA'));
        expect(norm, contains('-p 9090:80')); // VAR_PORT resolved to 9090
        expect(norm, contains('-v /mapped/host_data_a:/container/data_a:Z')); // Volume from mapping
        expect(norm, contains('mapped_image_a:v1 mapped_command_A mapped_param')); // Image and command from mapping with var
      });

      test('should combine environment variables from input and mapping', () {
        final result = generateRunPartInternal(
            sampleMappingData, sampleInputData, testNetworkName, testAddMetrics, testAddGenericOutput);
        final norm = normalizeCommand(result);
        // print("WithMapping Combined Env:\n$norm");
        
        // For serviceA
        expect(norm, contains('podman run -d -it --name serviceA'));
        expect(norm, contains('-e INPUT_VAR_A=valueA')); // From inputData.serviceA.environment
        expect(norm, contains('-e GREETING="Hello World"')); // From inputData.serviceA.environment, NAME resolved
        expect(norm, contains('-e MAPPED_VAR_A=mappedValueA')); // From mappingData.services.serviceA.environment
      });
      
      test('should use command from inputData if not in mappingData, with variable substitution', () {
        // serviceB command is not in sampleMappingData, so it should take from sampleInputData
        // sampleInputData.serviceB.command is ["./start.sh", "b"]
        // sampleInputData.serviceA.command is "input_command_A"
        // sampleMappingData.serviceA.command is "mapped_command_A $PARAM" -> "mapped_command_A mapped_param"
        final result = generateRunPartInternal(
            sampleMappingData, sampleInputData, testNetworkName, testAddMetrics, testAddGenericOutput);
        final norm = normalizeCommand(result);
        // print("WithMapping Command Fallback:\n$norm");

        expect(norm, contains('mapped_image_a:v1 mapped_command_A mapped_param')); // serviceA
        expect(norm, contains('mapped_image_b:v2 ./start.sh,b')); // serviceB, command from input (array to string)
      });

      test('should handle multiple services', () {
        final result = generateRunPartInternal(
            sampleMappingData, sampleInputData, testNetworkName, testAddMetrics, testAddGenericOutput);
        final norm = normalizeCommand(result);
        // print("WithMapping Multiple:\n$norm");
        expect(norm, contains('podman run -d -it --name serviceA'));
        expect(norm, contains('podman run -d -it --name serviceB'));
        // Check serviceB specific parts (image from mapping, command from input)
        expect(norm, contains('-e INPUT_VAR_B=valueB')); // serviceB env
        expect(norm, contains('mapped_image_b:v2 ./start.sh,b')); // serviceB image and command
      });
    });

    group('generateRunPartInternalWithoutMapping', () {
      test('should return empty string for empty inputData services', () {
        final result = generateRunPartInternalWithoutMapping(
            emptyInputData, testNetworkName, testAddMetrics, testAddGenericOutput);
        expect(result, isEmpty);
      });

      test('should generate basic podman run command directly from inputData', () {
        final inputForServiceAOnly = loadYamlFromString('''
services:
  serviceA:
    image: direct_image:latest
    command: direct_command_A --arg
    ports:
      - "8888:80"
    environment:
      - DIRECT_VAR=direct_value
    volumes:
      - /direct/host:/container/path # Becomes /container/path,Z
''');
        final result = generateRunPartInternalWithoutMapping(
            inputForServiceAOnly, testNetworkName, testAddMetrics, testAddGenericOutput);
        final norm = normalizeCommand(result);
        // print("WithoutMapping Basic:\n$norm");

        expect(norm, contains('podman run -d -it --name serviceA'));
        expect(norm, contains('-p 8888:80'));
        expect(norm, contains('-e DIRECT_VAR=direct_value'));
        expect(norm, contains('-v /direct/host:/container/path:Z')); // checkSpecialVolumes adds :Z
        expect(norm, contains('direct_image:latest direct_command_A --arg'));
      });

      test('should handle list command in inputData', () {
        // sampleInputData.serviceB.command is ["./start.sh", "b"]
        final result = generateRunPartInternalWithoutMapping(
            sampleInputData, testNetworkName, testAddMetrics, testAddGenericOutput);
        final norm = normalizeCommand(result);
        // print("WithoutMapping List Command:\n$norm");
        expect(norm, contains('input_image_b:1.0 ./start.sh,b')); // serviceB command
      });
      
      test('should handle volumes with map format from inputData', () {
        final inputWithMapVolume = loadYamlFromString('''
services:
  serviceC:
    image: an_image
    volumes:
      - host_path: /container/map_volume # Becomes /container/map_volume,Z
''');
        final result = generateRunPartInternalWithoutMapping(
            inputWithMapVolume, testNetworkName, testAddMetrics, testAddGenericOutput);
        final norm = normalizeCommand(result);
        // print("WithoutMapping Map Volume:\n$norm");
        expect(norm, contains('-v host_path:/container/map_volume:Z'));
      });


      test('should handle multiple services from inputData directly', () {
        final result = generateRunPartInternalWithoutMapping(
            sampleInputData, testNetworkName, testAddMetrics, testAddGenericOutput);
        final norm = normalizeCommand(result);
        // print("WithoutMapping Multiple:\n$norm");

        // Service A from inputData
        expect(norm, contains('podman run -d -it --name serviceA'));
        expect(norm, contains('-p 8080:80'));
        expect(norm, contains('-p VAR_PORT:81')); // VAR_PORT is literal, not resolved
        expect(norm, contains('-e INPUT_VAR_A=valueA'));
        expect(norm, contains('-e GREETING=Hello $NAME')); // $NAME is literal
        expect(norm, contains('-v /input/data_a:/container/data_a:Z'));
        expect(norm, contains('input_image_a:latest input_command_A'));

        // Service B from inputData
        expect(norm, contains('podman run -d -it --name serviceB'));
        expect(norm, contains('-e INPUT_VAR_B=valueB'));
        expect(norm, contains('input_image_b:1.0 ./start.sh,b'));
      });
    });
  });
}
