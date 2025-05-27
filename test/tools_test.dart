import 'package:test/test.dart';
import 'package:yaml/yaml.dart';
import '../lib/tools.dart'; // Adjust the import path as needed

void main() {
  group('tools.dart tests', () {
    // Tests for searchVarValue
    group('searchVarValue', () {
      test('should return value if key exists', () {
        final variables = {'key1': 'value1', 'key2': 'value2'};
        expect(searchVarValue('key1', variables), 'value1');
      });

      test('should return original string if key does not exist', () {
        final variables = {'key1': 'value1'};
        expect(searchVarValue('key3', variables), 'key3');
      });

      test('should return original string for empty map', () {
        final variables = {};
        expect(searchVarValue('key1', variables), 'key1');
      });
    });

    // Tests for searchIfVarUsed
    group('searchIfVarUsed', () {
      test('should replace variable if found', () {
        final variables = {'name': 'Dart'};
        expect(searchIfVarUsed('Hello \$name!', variables), 'Hello Dart!');
      });

      test('should replace multiple variables if found', () {
        final variables = {'name': 'Dart', 'version': '3'};
        expect(searchIfVarUsed('Hello \$name v\$version!', variables), 'Hello Dart v3!');
      });

      test('should not replace if variable not found', () {
        final variables = {'name': 'Dart'};
        expect(searchIfVarUsed('Hello \$other!', variables), 'Hello \$other!');
      });

      test('should handle string with no variables', () {
        final variables = {'name': 'Dart'};
        expect(searchIfVarUsed('Hello World!', variables), 'Hello World!');
      });
    });

    // Tests for searchService
    group('searchService', () {
      test('should return YamlMap if service exists', () {
        final services = {
          'serviceA': loadYaml('name: ServiceA\nport: 8080'),
          'serviceB': loadYaml('name: ServiceB\nport: 9090')
        };
        final serviceAData = services['serviceA'] as YamlMap;
        expect(searchService('serviceA', services), equals(serviceAData));
      });

      test('should return null if service does not exist', () {
        final services = {
          'serviceA': loadYaml('name: ServiceA\nport: 8080'),
        };
        expect(searchService('serviceC', services), isNull);
      });

       test('should return null for empty services map', () {
        final services = {};
        expect(searchService('serviceA', services), isNull);
      });
    });

    // Tests for extractStrings
    group('extractStrings', () {
      test('should extract with colon separator', () {
        expect(extractStrings('key:value'), ('key', 'value'));
      });

      test('should extract with equals separator', () {
        expect(extractStrings('key=value'), ('key', 'value'));
      });

      test('should trim spaces around key and value', () {
        expect(extractStrings('  key  :  value  '), ('key', 'value'));
        expect(extractStrings('  key  =  value  '), ('key', 'value'));
      });

      test('should return input string for both if no separator', () {
        expect(extractStrings('keyvalue'), ('keyvalue', 'keyvalue'));
      });
       test('should handle empty string', () {
        expect(extractStrings(''), ('', ''));
      });
    });

    // Tests for checkSpecialVolumes
    group('checkSpecialVolumes', () {
      test('should append :Z if useSELinux is true and no colon', () {
        expect(checkSpecialVolumes('/data/volume', true), '/data/volume:Z');
      });

      test('should not append :Z if useSELinux is false and no colon', () {
        expect(checkSpecialVolumes('/data/volume', false), '/data/volume');
      });

      test('should append ,Z if useSELinux is true and colon exists', () {
        expect(checkSpecialVolumes('/host:/container', true), '/host:/container,Z');
      });

      test('should not append ,Z if useSELinux is false and colon exists', () {
        expect(checkSpecialVolumes('/host:/container', false), '/host:/container');
      });

      test('should not append anything if it already ends with :Z', () {
        expect(checkSpecialVolumes('/host:/container:Z', true), '/host:/container:Z');
        expect(checkSpecialVolumes('/host:/container:Z', false), '/host:/container:Z');
      });
    });

    // Tests for searchMountValue
    group('searchMountValue', () {
      final servicesList = {
        'service1': loadYaml('''
          volumes:
            - /local/data1:/container/data1
            - type: bind
              source: /local/data2
              target: /container/data2
            - /local/data3:/container/data3:ro
        '''),
        'service2': loadYaml('''
          volumes:
            - /other/path:/app/config
        '''),
        'service3': loadYaml('''
          # No volumes here
        ''')
      };

      test('should find mount value for string format', () {
        expect(searchMountValue('/container/data1', 'service1', servicesList), '/local/data1');
      });

      test('should find mount value for map format (target)', () {
         expect(searchMountValue('/container/data2', 'service1', servicesList), '/local/data2');
      });

      test('should find mount value with options (e.g. :ro)', () {
        expect(searchMountValue('/container/data3', 'service1', servicesList), '/local/data3');
      });


      test('should return empty string if mount value not found', () {
        expect(searchMountValue('/not/found', 'service1', servicesList), '');
      });

      test('should return empty string if service not found', () {
        expect(searchMountValue('/container/data1', 'nonExistentService', servicesList), '');
      });

      test('should return empty string if service has no volumes', () {
        expect(searchMountValue('/app/config', 'service3', servicesList), '');
      });

       test('should return empty string if servicesList is empty', () {
        expect(searchMountValue('/container/data1', 'service1', {}), '');
      });
    });

    // Tests for convertYamlMapToMap
    group('convertYamlMapToMap', () {
      test('should convert simple YamlMap to Map', () {
        final yamlMap = loadYaml('key1: value1\nkey2: 123') as YamlMap;
        final expectedMap = {'key1': 'value1', 'key2': '123'};
        expect(convertYamlMapToMap(yamlMap), equals(expectedMap));
      });

      test('should convert nested YamlMap to Map', () {
        final yamlMap = loadYaml('key1: value1\nnested:\n  nKey1: nValue1\n  nKey2: 456') as YamlMap;
        final expectedMap = {
          'key1': 'value1',
          'nested': {'nKey1': 'nValue1', 'nKey2': '456'}
        };
        expect(convertYamlMapToMap(yamlMap), equals(expectedMap));
      });

       test('should handle empty YamlMap', () {
        final yamlMap = loadYaml('') as YamlMap; // or loadYaml('{}')
        expect(convertYamlMapToMap(yamlMap), equals({}));
      });
    });

    // Tests for fullMappingOnly
    group('fullMappingOnly', () {
      test('should replace variables and keys from mappingData', () {
        final yamlContent = 'Hello \$name, your city is city_placeholder.';
        final mappingData = loadYaml('''
variables:
  name: World
  city_placeholder: New York
        ''') as YamlMap;
        expect(fullMappingOnly(yamlContent, mappingData), 'Hello World, your city is New York.');
      });

      test('should replace only variables if no direct key match', () {
        final yamlContent = 'Value: \$val';
        final mappingData = loadYaml('''
variables:
  val: 123
  other_key: abc 
        ''') as YamlMap;
         // Expecting "Value: 123" because 'other_key' is not in 'yamlContent' as a placeholder or direct key
        expect(fullMappingOnly(yamlContent, mappingData), 'Value: 123');
      });


      test('should handle content with no variables or keys to replace', () {
        final yamlContent = 'Static content.';
        final mappingData = loadYaml('''
variables:
  name: Test
        ''') as YamlMap;
        expect(fullMappingOnly(yamlContent, mappingData), 'Static content.');
      });

      test('should handle empty mappingData variables', () {
        final yamlContent = 'Hello \$name.';
        final mappingData = loadYaml('variables: {}') as YamlMap;
        expect(fullMappingOnly(yamlContent, mappingData), 'Hello \$name.');
      });

       test('should handle mappingData without variables key', () {
        final yamlContent = 'Hello \$name.';
        final mappingData = loadYaml('some_other_key: value') as YamlMap;
        expect(fullMappingOnly(yamlContent, mappingData), 'Hello \$name.');
      });
    });

    // Tests for generateOutputFile (Conceptual - actual file I/O is hard to test without mocks)
    group('generateOutputFile', () {
      // This test is more of a placeholder as true file I/O testing
      // would require a more complex setup (e.g., temporary file system, mocks).
      // For now, we'll assume if it runs without throwing, the basic structure is okay.
      // In a real scenario, you'd mock 'dart:io' File and IOSink.
      test('should complete without error (conceptual test)', () async {
        // Using a dummy path and content for the conceptual test.
        // This won't actually write a file in this test environment effectively.
        final outputFile = 'dummy_output.txt';
        final outputStr = 'Test content';
        try {
          final result = await generateOutputFile(outputFile, outputStr);
          expect(result, isTrue); // Expecting true as per function's return
          // In a real test with mocks, you would verify interactions with the mock IOSink.
          // e.g. verify(mockSink.write(outputStr)).called(1);
          // verify(mockSink.flush()).called(1);
          // verify(mockSink.close()).called(1);

          // Clean up dummy file if it was created (less relevant without actual file system)
          // final file = File(outputFile);
          // if (await file.exists()) {
          //   await file.delete();
          // }
        } catch (e) {
          // If any exception occurs, the test fails.
          fail('generateOutputFile threw an error: $e');
        }
      });
    });
  });
}
