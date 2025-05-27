import 'package:test/test.dart';
import 'package:yaml/yaml.dart';
import 'package:compose2target/generators/quadlet.dart'; // Adjust if necessary

// Helper function to load YamlMap from String for convenience in tests
YamlMap loadYamlFromString(String yamlString) {
  if (yamlString.trim().isEmpty) {
    return loadYaml('{}') as YamlMap;
  }
  return loadYaml(yamlString) as YamlMap;
}

// Helper to normalize INI output for comparison (remove empty lines, trim lines)
String normalizeIni(String iniString) {
  return iniString
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .join('\n');
}

void main() {
  group('quadlet.dart tests', () {
    group('generatePortsPartForQuadlet', () {
      test('should return simple port string as is', () {
        expect(generatePortsPartForQuadlet('8080'), '8080');
      });
      test('should return port mapping string as is', () {
        expect(generatePortsPartForQuadlet('80:8080'), '80:8080');
      });
      test('should return IP mapping string as is', () {
        expect(generatePortsPartForQuadlet('127.0.0.1:80:8080'), '127.0.0.1:80:8080');
      });
      test('should return port range string as is', () {
        expect(generatePortsPartForQuadlet('3000-3005'), '3000-3005');
      });
      test('should format map port correctly', () {
        expect(generatePortsPartForQuadlet({'80': '8080'}), '80:8080');
        expect(generatePortsPartForQuadlet({80: 8080}), '80:8080');
      });
    });

    group('generateQuadletPartInternal', () {
      test('should generate basic quadlet file for a single service', () {
        final inputData = loadYamlFromString('''
services:
  serviceA:
    image: myimage:latest
    restart: always
''');
        final expected = normalizeIni('''
[Unit]
Description=serviceA

[Container]
ContainerName=serviceA
AutoUpdate=registry
Image=myimage:latest

[Service]
Restart=always
RestartSec=5
Delegate=yes
MemorySwapMax=0

[Install]
WantedBy=default.target
''');
        final result = normalizeIni(generateQuadletPartInternal(inputData));
        // print(result);
        expect(result, expected);
      });

      test('should include Pod name if inputData.name is provided', () {
        final inputData = loadYamlFromString('''
name: my_application
services:
  serviceA:
    image: myimage:latest
    restart: on-failure
''');
        final expected = normalizeIni('''
[Unit]
Description=serviceA

[Container]
ContainerName=serviceA
Pod=pod_my_application.pod
AutoUpdate=registry
Image=myimage:latest

[Service]
Restart=on-failure
RestartSec=5
Delegate=yes
MemorySwapMax=0

[Install]
WantedBy=default.target
''');
        final result = normalizeIni(generateQuadletPartInternal(inputData));
        // print(result);
        expect(result, expected);
      });

      test('should handle depends_on for [Unit] section', () {
        final inputData = loadYamlFromString('''
services:
  serviceA:
    image: image_a
    restart: always
    depends_on:
      - serviceB
      - serviceC
''');
        final expected = normalizeIni('''
[Unit]
Description=serviceA
Requires=serviceB.service serviceC.service 
After=serviceB.service serviceC.service 

[Container]
ContainerName=serviceA
AutoUpdate=registry
Image=image_a

[Service]
Restart=always
RestartSec=5
Delegate=yes
MemorySwapMax=0

[Install]
WantedBy=default.target
''');
        final result = normalizeIni(generateQuadletPartInternal(inputData));
        // print(result);
        expect(result, expected);
      });

      test('should generate PublishPort, Environment, Volume, Network, Secret, Exec', () {
        final inputData = loadYamlFromString('''
services:
  serviceA:
    image: image_a
    restart: no
    ports:
      - "80:8080"
      - "127.0.0.1:9090:9090/tcp"
    environment:
      - VAR1=value1
      - VAR2="value with space"
    volumes:
      - /host/data:/container/data # -> /container/data,Z
      - named_volume:/app/storage:ro # -> /app/storage,Z (ro is not parsed by quadlet gen for Volume=)
    networks:
      - my_net
      - another_net
    secrets:
      - app_secret
      - db_secret
    command: ["./start.sh", "--param", "value"]
''');
        // Note: checkSpecialVolumes adds ",Z" to volume target if SELinux is true (which it is in the call)
        // The 'ro' option for volumes is not specifically handled by this generator for the Volume= line.
        final expected = normalizeIni('''
[Unit]
Description=serviceA

[Container]
ContainerName=serviceA
AutoUpdate=registry
Image=image_a
PublishPort=80:8080
PublishPort=127.0.0.1:9090:9090/tcp
Environment=VAR1=value1
Environment=VAR2="value with space"
Volume=/host/data:/container/data,Z
Volume=named_volume:/app/storage,Z 
Network=my_net.network
Network=another_net.network
Secret=app_secret
Secret=db_secret
Exec= ./start.sh --param value

[Service]
Restart=no
RestartSec=5
Delegate=yes
MemorySwapMax=0

[Install]
WantedBy=default.target
''');
        final result = normalizeIni(generateQuadletPartInternal(inputData));
        // print(result);
        expect(result, expected);
      });
      
      test('should handle string command', () {
        final inputData = loadYamlFromString('''
services:
  serviceA:
    image: image_a
    restart: always
    command: "/entrypoint.sh --arg"
''');
        final expected = normalizeIni('''
[Unit]
Description=serviceA

[Container]
ContainerName=serviceA
AutoUpdate=registry
Image=image_a
Exec= /entrypoint.sh --arg

[Service]
Restart=always
RestartSec=5
Delegate=yes
MemorySwapMax=0

[Install]
WantedBy=default.target
''');
        final result = normalizeIni(generateQuadletPartInternal(inputData));
        expect(result, contains(normalizeIni("Exec= /entrypoint.sh --arg")));
      });


      test('should correctly parse deploy resources limits and reservations', () {
        final inputData = loadYamlFromString('''
services:
  serviceA:
    image: image_a
    restart: always
    deploy:
      resources:
        limits:
          cpus: '0.50'
          memory: 50M
          pids: 100
        reservations:
          cpus: '0.25' # CPUQuota
          memory: 20M  # MemoryMin
''');
        final expectedServicePart = normalizeIni('''
[Service]
Restart=always
RestartSec=5
Delegate=yes
MemorySwapMax=0
AllowedCPUs=0.50
MemoryMax=50M
PIDsLimit=100
CPUQuota=0.25
MemoryMin=20M
''');
        final result = normalizeIni(generateQuadletPartInternal(inputData));
        // print(result);
        expect(result, contains(expectedServicePart));
      });
      
      test('should correctly parse other deploy options', () {
        final inputData = loadYamlFromString('''
services:
  serviceA:
    image: image_a
    restart: always
    deploy:
      mode: global
      replicas: 3
      endpoint_mode: vip
      labels:
        com.example.foo: bar
        com.example.baz: qux
      placement:
        constraints:
          - node.role==manager
        preferences:
          - datacenter==east
      restart_policy:
        condition: on-failure
        delay: 5s
        max_attempts: 3
        window: 120s
      # rollback_config and update_config are also parsed but this test covers the structure
''');
        final expectedServicePart = normalizeIni('''
Mode=global
Replicas=3
EndpointMode=vip
Label=bar 
Label=qux 
Constraint=node.role==manager
Preference=datacenter==east
Delay=5s
MaxAttempts=3
Window=120s
'''); // Note: restart_policy condition is not directly translated to a single key
        final result = normalizeIni(generateQuadletPartInternal(inputData));
        // print(result);
        expect(result, contains(normalizeIni("Mode=global")));
        expect(result, contains(normalizeIni("Replicas=3")));
        expect(result, contains(normalizeIni("EndpointMode=vip")));
        expect(result, contains(normalizeIni("Label=bar"))); // Order of labels from map not guaranteed
        expect(result, contains(normalizeIni("Label=qux")));
        expect(result, contains(normalizeIni("Constraint=node.role==manager")));
        expect(result, contains(normalizeIni("Preference=datacenter==east")));
        // For restart_policy, individual fields are translated
        expect(result, contains(normalizeIni("Delay=5s"))); 
        expect(result, contains(normalizeIni("MaxAttempts=3")));
        expect(result, contains(normalizeIni("Window=120s")));
      });


      test('should generate output for multiple services', () {
        final inputData = loadYamlFromString('''
services:
  serviceA:
    image: image_a
    restart: always
  serviceB:
    image: image_b
    restart: on-failure
    ports: ["8081:80"]
''');
        final result = normalizeIni(generateQuadletPartInternal(inputData));
        // print(result);
        expect(result, contains(normalizeIni("Description=serviceA")));
        expect(result, contains(normalizeIni("Image=image_a")));
        expect(result, contains(normalizeIni("Restart=always")));
        expect(result, contains(normalizeIni("Description=serviceB")));
        expect(result, contains(normalizeIni("Image=image_b")));
        expect(result, contains(normalizeIni("PublishPort=8081:80")));
        expect(result, contains(normalizeIni("Restart=on-failure")));
      });
      
      test('should handle empty services input', () {
        final inputData = loadYamlFromString('''
services: {}
''');
        final result = generateQuadletPartInternal(inputData);
        expect(result, isEmpty);
      });

    });
  });
}
