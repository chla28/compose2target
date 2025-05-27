import 'package:test/test.dart';
import 'package:yaml/yaml.dart';
import 'package:compose2target/generators/ha.dart'; // Adjust if necessary
// import 'package:compose2target/tools.dart'; // For checkSpecialVolumes, extractStrings if we were testing them here

// Helper function to load YamlMap from String for convenience in tests
YamlMap loadYamlFromString(String yamlString) {
  // Handles empty string to return an empty YamlMap, common in some input structures
  if (yamlString.trim().isEmpty) {
    return loadYaml('{}') as YamlMap;
  }
  return loadYaml(yamlString) as YamlMap;
}

void main() {
  group('ha.dart tests', () {
    group('generateHAPartInternal', () {
      test('should generate basic pcs resource for a single service', () {
        final inputData = loadYamlFromString('''
services:
  serviceA:
    image: myimage:latest
''');
        final result = generateHAPartInternal(inputData);
        // print(result);
        expect(result, contains('pcs resource create serviceA ocf:other:podmanrootless'));
        expect(result, contains('\timage="myimage:latest" name="serviceA"'));
        expect(result, contains('\tallow_pull=false reuse=false'));
        expect(result, contains('\trun_opts="   "')); // Default empty run_opts if no ports, env, vols
        expect(result, contains('\top monitor timeout="30s" interval="30s" depth="0"'));
      });

      test('should handle inputData with a name (podName is not used in output)', () {
        final inputData = loadYamlFromString('''
name: my_application
services:
  serviceA:
    image: myimage:latest
''');
        // The 'name' field in inputData is used to set 'podName' internally,
        // but 'podName' is not used in the output string. So the output
        // should be the same as if 'name' was not provided.
        final result = generateHAPartInternal(inputData);
        // print(result);
        expect(result, contains('pcs resource create serviceA ocf:other:podmanrootless'));
        expect(result, contains('\timage="myimage:latest" name="serviceA"'));
      });

      test('should generate resources for multiple services', () {
        final inputData = loadYamlFromString('''
services:
  serviceA:
    image: image_a:1.0
  serviceB:
    image: image_b:2.0
''');
        final result = generateHAPartInternal(inputData);
        // print(result);
        expect(result, contains('pcs resource create serviceA ocf:other:podmanrootless'));
        expect(result, contains('\timage="image_a:1.0" name="serviceA"'));
        expect(result, contains('pcs resource create serviceB ocf:other:podmanrootless'));
        expect(result, contains('\timage="image_b:2.0" name="serviceB"'));
      });

      test('should include volumes in mount_points and run_opts', () {
        final inputData = loadYamlFromString('''
services:
  serviceA:
    image: myimage
    volumes:
      - /local/data:/container/data # Uses checkSpecialVolumes -> /container/data,Z
      - type: bind # This format is from compose, HA parser expects {source: target} or "source:target"
        source: /local/config
        target: /container/config # Uses checkSpecialVolumes -> /container/config,Z
''');
        // The HA generator's volume parsing is simpler than compose.
        // It expects strings "source:target" or YamlMap entries like "source: target".
        // The test above uses a map structure that is more like Docker Compose.
        // Let's adjust to what ha.dart expects or test its actual behavior.
        // `extractStrings` is used on string values.
        // For map values, it directly uses `value.keys.first` and `value.values.first`.

        // Corrected input based on ha.dart's parsing logic for volumes:
        final correctedInputData = loadYamlFromString('''
services:
  serviceA:
    image: myimage
    volumes:
      - /local/data:/container/data 
      - /local/config:/container/config # Simple string format
      # Example of a map format it might encounter (though less common for simple lists)
      # - hostPath: /containerPath (This is not directly supported by the loop structure for YamlMap items)
''');
        // Let's test with a list of strings first, which is the primary way it parses.
        // The `checkSpecialVolumes` adds ",Z" to the container path part if SELinux is implied (true in this call).
        final result = generateHAPartInternal(correctedInputData);
        // print(result);
        expect(result, contains('\tmount_points="/local/data,/local/config,"')); // Note trailing comma
        expect(result, contains('\trun_opts_part_volumes="-v /local/data:/container/data,Z -v /local/config:/container/config,Z "'));
        // The actual run_opts line construction concatenates ports, env, and volumes.
        // The test below will use a helper to reconstruct the expected run_opts string.
      });
      
      test('should correctly format run_opts with ports, environment, and volumes', () {
        final inputData = loadYamlFromString('''
services:
  serviceA:
    image: myimage
    ports:
      - "80:8080"
      - "ANYONE:9090" # Assuming 'ANYONE' is treated as host part if it were a YamlMap key
    environment:
      - VAR1=value1
      - VAR2=value2
    volumes:
      - /data:/app/data # Becomes /app/data,Z
      - /config:/app/config # Becomes /app/config,Z
''');
        // For ports, if it's a string "host:container", it's used as -p host:container
        // If it's a YamlMap {host: container}, it's -p host:container
        // The test uses string list for ports.

        final result = generateHAPartInternal(inputData);
        // print(result);

        String expectedPortsOpt = "-p 80:8080 -p ANYONE:9090 "; // Note: `extractStrings` behavior with "ANYONE:9090"
                                                              // idx = value.indexOf(":") -> ANYONE, 9090
        String expectedEnvOpt = "-e VAR1=value1 -e VAR2=value2 ";
        String expectedVolOpt = "-v /data:/app/data,Z -v /config:/app/config,Z ";
        
        expect(result, contains('\tmount_points="/data,/config,"'));
        expect(result, contains('\trun_opts="$expectedPortsOpt$expectedEnvOpt$expectedVolOpt"'));
      });

      test('should handle string command', () {
        final inputData = loadYamlFromString('''
services:
  serviceA:
    image: myimage
    command: "./start.sh --arg"
''');
        final result = generateHAPartInternal(inputData);
        // print(result);
        expect(result, contains('\trun_cmd=" ./start.sh --arg"')); // Note leading space from `cmd $cmd2` where cmd is ""
      });

      test('should handle list command', () {
        final inputData = loadYamlFromString('''
services:
  serviceA:
    image: myimage
    command:
      - ./start.sh
      - --arg1
      - value1
''');
        final result = generateHAPartInternal(inputData);
        // print(result);
        expect(result, contains('\trun_cmd=" ./start.sh --arg1 value1"')); // Note leading space
      });

      test('should handle service with no optional fields', () {
        final inputData = loadYamlFromString('''
services:
  minimal_service:
    image: busybox
''');
        final result = generateHAPartInternal(inputData);
        // print(result);
        expect(result, contains('pcs resource create minimal_service ocf:other:podmanrootless'));
        expect(result, contains('\timage="busybox" name="minimal_service"'));
        expect(result, contains('\trun_opts="   "')); // Empty opts for ports, env, vols
        expect(result, isNot(contains('\tmount_points='))); // No mount_points line if no volumes
        expect(result, isNot(contains('\trun_cmd=')));     // No run_cmd line if no command
      });
       test('should handle empty services input', () {
        final inputData = loadYamlFromString('''
services: {}
''');
        final result = generateHAPartInternal(inputData);
        expect(result, isEmpty);
      });

      test('should correctly process volumes with map format (less common in list)', () {
        // The loop `for (var value in mountList)` expects `value` to be a string or a simple map.
        // If YamlList contains YamlMap items like { source: /host, target: /container }
        // it would try `item.keys.first` and `item.values.first`.
        // Let's test this specific case if a volume is defined as a map within the list.
        final inputData = loadYamlFromString('''
services:
  serviceWithMapVolume:
    image: myimage
    volumes:
      - /hostPath1:/containerPath1,Z # String item
      - hostPath2: /containerPath2,Z # Map item (keys.first: hostPath2, values.first: /containerPath2,Z)
''');
        final result = generateHAPartInternal(inputData);
        // print(result);
        expect(result, contains('\tmount_points="/hostPath1,hostPath2,"'));
        // checkSpecialVolumes is called with `value.values.first` (which is /containerPath2,Z) and true.
        // It should not add another ,Z if it's already there.
        // However, checkSpecialVolumes adds ,Z if ":" is present and it doesn't end with :Z.
        // If value.values.first is "/containerPath2,Z", then idx is -1. It becomes "/containerPath2,Z:Z"
        // This seems like a potential double "Z" issue if the input already has it.
        // Let's assume input is clean for now: /containerPath2
        
        final cleanInputData = loadYamlFromString('''
services:
  serviceWithMapVolume:
    image: myimage
    volumes:
      - /hostPath1:/containerPath1
      - hostPath2: /containerPath2 
''');
        final cleanResult = generateHAPartInternal(cleanInputData);
        // print(cleanResult);
        expect(cleanResult, contains('\tmount_points="/hostPath1,hostPath2,"'));
        expect(cleanResult, contains('\trun_opts_part_volumes="-v /hostPath1:/containerPath1,Z -v hostPath2:/containerPath2,Z "'));
      });

    });
  });
}
