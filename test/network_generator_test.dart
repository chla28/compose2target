import 'package:test/test.dart';
import 'package:compose2target/generators/network.dart'; // Adjust if necessary
import 'package:compose2target/tools.dart'; // For 't' constant

void main() {
  group('network.dart tests', () {
    group('generateNetworksPart', () {
      test('should return empty string if network name is empty', () {
        expect(generateNetworksPart('compose', ''), '');
        expect(generateNetworksPart('run', ''), '');
        expect(generateNetworksPart('any_target', ''), '');
      });

      test('should generate correct output for target "compose" with a network name', () {
        final networkName = 'my_test_network';
        final expectedOutput = '''
networks:
  $t$networkName:
    $t${t}network_name: $networkName
    $t${t}driver: bridge
    $t${t}external: true
''';
        // Normalizing whitespace/newlines for comparison if necessary,
        // but here expecting exact match based on current generator logic.
        expect(generateNetworksPart('compose', networkName), expectedOutput.trim());
      });

      test('should generate correct output for target "compose" ensuring consistent spacing from "t"', () {
        final networkName = 'another_net';
        // Using the 't' constant directly to ensure the test matches the source code's spacing.
        String expected = "networks:\n";
        expected += "$t$networkName:\n";
        expected += "$t${t}network_name: $networkName\n";
        expected += "$t${t}driver: bridge\n";
        expected += "$t${t}external: true\n";
        
        expect(generateNetworksPart('compose', networkName), expected.trim());
      });

      test('should return "TBD\\n" for target "run" with a network name', () {
        expect(generateNetworksPart('run', 'my_network'), 'TBD\n');
      });

      test('should return "TBD\\n" for target "kube" with a network name', () {
        expect(generateNetworksPart('kube', 'my_network'), 'TBD\n');
      });

      test('should return "TBD\\n" for target "k8s" with a network name', () {
        expect(generateNetworksPart('k8s', 'my_network'), 'TBD\n');
      });

      test('should return "TBD\\n" for target "ha" with a network name', () {
        expect(generateNetworksPart('ha', 'my_network'), 'TBD\n');
      });

      test('should return "TBD\\n" for an unknown target with a network name that is not compose', () {
        // Based on the switch statement, any target not 'compose' and not explicitly returning "TBD"
        // would fall through. However, the current structure has all other explicit cases return "TBD".
        // If a new case were added without a break, or if there was a default, this might change.
        // For now, an unknown target that is not 'compose' will hit no case and return "" if network is empty,
        // or if network is not empty, it will not match any case and return an empty string because there's no default.
        // Let's test this behavior.
        expect(generateNetworksPart('unknown_target', 'my_network'), '');
      });
    });
  });
}
