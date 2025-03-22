import 'package:compose2target/tools.dart';
import 'package:yaml/yaml.dart';

// Les objets 'configs' ne sont pas supportés par les quadlets

/*
  => a chaque service correspond un fichier
[Unit]
Description=valkey-db

Requires=test-db.service   ==> depends_on
After=test-db.service

[Container]
ContainerName=valkey-db
AutoUpdate=registry
Image=docker.io/valkey/valkey:latest
PublishPort=6379:6379
Volume=/local/data1/DB/redis/data:/data
Volume=%h/volumes/oxitraffic/logs:/var/log/oxitraffic:Z
Environment=POSTGRES_PASSWORD=CHANGE_ME
Environment=MARIADB_RANDOM_ROOT_PASSWORD=1
Environment=MARIADB_USER=wordpress
Environment=MARIADB_DATABASE=wordpress
User=1000
Network=wordpress.net
[Service]
Restart=always

[Install]
WantedBy=local.target
*/
String generatePortsPartForQuadlet(value) {
  String outputStr = "";
  if (value is String) {
    // "[[IP:](port|range)](port|range)[/protocol]"
    // "3030"
    RegExp singlePort = RegExp(r'^(?:-?(?:0|[1-9][0-9]*))$');
    // "3000-3050"
    RegExp rangePort = RegExp(r'^(?:-?(?:0|[1-9][0-9]*))-(?:-?(?:0|[1-9][0-9]*))$');
    // "8000:8000"
    RegExp portMapping = RegExp(r'^(?:-?(?:0|[1-9][0-9]*)):(?:-?(?:0|[1-9][0-9]*))$');
    // "3000-3050:4000-4050"
    RegExp portRangeMapping = RegExp(r'^(?:-?(?:0|[1-9][0-9]*))-(?:-?(?:0|[1-9][0-9]*)):(?:-?(?:0|[1-9][0-9]*))-(?:-?(?:0|[1-9][0-9]*))$');
    // "127.0.0.1:8000:8000"
    RegExp ipMapping = RegExp(r'^(\d?\d?\d)\.(\d?\d?\d)\.(\d?\d?\d)\.(\d?\d?\d):(?:-?(?:0|[1-9][0-9]*)):(?:-?(?:0|[1-9][0-9]*))$');
    // "127.0.0.1:8000:8000/udp"
    RegExp ipMappingProtocol = RegExp(r'^(\d?\d?\d)\.(\d?\d?\d)\.(\d?\d?\d)\.(\d?\d?\d):(?:-?(?:0|[1-9][0-9]*)):(?:-?(?:0|[1-9][0-9]*))/(udp|tcp)$');

    if (singlePort.hasMatch(value)) {
      //print("single port found        : $value");
      outputStr += value;
    } else if (rangePort.hasMatch(value)) {
      //print("range found              : $value");
      outputStr += value;
    } else if (portMapping.hasMatch(value)) {
      //print("port mapping found       : $value");
      outputStr += value;
    } else if (portRangeMapping.hasMatch(value)) {
      //print("port range mapping found : $value");
      outputStr += value;
    } else if (ipMapping.hasMatch(value)) {
      //print("ip mapping found         : $value");
      outputStr += value;
    } else if (ipMappingProtocol.hasMatch(value)) {
      //print("ip mapping protocol found: $value");
      outputStr += value;
    }
  } else {
    Map port = value;
    String portStr = "";
    if (port.keys.first is int) {
      portStr = port.keys.first.toString();
    } else {
      portStr = port.keys.first;
    }
    outputStr += "$portStr:${port.values.first}";
  }
  return outputStr;
}

String generateQuadletPartInternal(Map inputData) {
  // Get data from inputFile
  YamlMap containersList = inputData['services'];
  // if a key 'name' is present, a pod will be created and the value will be used for the POD name
  String name = inputData['name'] ?? "";
  String podName = "";
  if (name.isNotEmpty) {
    podName = "pod_$name.pod";
  }

  String outputStr = "";

  // Each key 'services' present is associated to a container
  containersList.forEach((key, value) {
    String containerName = key;
    outputStr += "[Unit]\n";
    outputStr += "Description=$containerName\n";
    YamlList? dependsList = containersList[containerName]['depends_on'];
    if (dependsList != null) {
      String depListStr = "";
      for (var value in dependsList) {
        depListStr += "$value.service ";
      }
      outputStr += "Requires=$depListStr\n";
      outputStr += "After=$depListStr\n";
    }
    outputStr += "\n";

    outputStr += "[Container]\n";
    // container_name: dbvalkey  => ContainerName=dbvalkey
    outputStr += "ContainerName=$containerName\n";
    if (podName.isNotEmpty) {
      outputStr += "Pod=$podName\n";
    }
    // AutoUpdate=registry
    outputStr += "AutoUpdate=registry\n";
    // image: docker.io/valkey/valkey:latest => Image=docker.io/valkey/valkey:latest
    outputStr += "Image=${containersList[containerName]['image']}\n";
    // labels => Ignored
    // - "6379:6379"  => PublishPort=6379:6379
    YamlList? portList = containersList[containerName]['ports'];
    if (portList != null) {
      for (var value in portList) {
        String portPart = generatePortsPartForQuadlet(value);
        outputStr += "PublishPort=$portPart\n";
      }
    }
    YamlList? envList = containersList[containerName]['environment'];
    if (envList != null) {
      for (var value in envList) {
        outputStr += "Environment=$value\n";
      }
    }
    YamlList? volumeList = containersList[containerName]['volumes'];
    if (volumeList != null) {
      for (var value in volumeList) {
        if (value is String) {
          final (localStr, mountStrCont) = extractStrings(value);
          String tmp = checkSpecialVolumes(mountStrCont, true);
          outputStr += "Volume=$localStr:$tmp\n";
        } else {
          String tmp = checkSpecialVolumes(value.values.first, true);
          outputStr += "Volume=${value.keys.first}:$tmp\n";
        }
      }
    }
    YamlList? networkList = containersList[containerName]['networks'];
    if (networkList != null) {
      for (var value in networkList) {
        outputStr += "Network=$value.network\n";
      }
    }
    YamlList? secretList = containersList[containerName]['secrets'];
    if (secretList != null) {
      for (var value in secretList) {
        outputStr += "Secret=$value\n";
      }
    }
    var cmd2 = containersList[containerName]['command'];
    if (cmd2 != null) {
      /*var shell = Shell();
      var results = shell.runSync("podman inspect --type=image --format='{{json .Config.Entrypoint}}' ${containersList[containerName]['image']}");
      var result = results.first.outText.trim();
      String cmd = result.substring(2, result.length - 2); // remove  [" and "]
      */
      String cmd = "";
      //print('output: ${result.outText.trim()} exitCode: ${result.exitCode}');
      if (cmd2 is String) {
        outputStr += "Exec=$cmd $cmd2\n";
      } else if (cmd2 is YamlList) {
        String cmdStr = "";
        for (var value in cmd2) {
          cmdStr += " $value";
        }
        outputStr += "Exec=$cmd $cmdStr\n";
      }
    }
    outputStr += "\n";
    outputStr += "[Service]\n";
    // restart: always => Restart=always
    outputStr += "Restart=${containersList[containerName]['restart']}\n";
    outputStr += "RestartSec=5\n";
    outputStr += "Delegate=yes\n";
    //outputStr += "KillMode=mixed\n";
    //outputStr += "IOWeight=50\n";
    outputStr += "MemorySwapMax=0\n";
    //outputStr += "ManageOOMSwap=kill\n";

    YamlMap? deployMap = containersList[containerName]['deploy'];
    if (deployMap != null) {
      for (var item in deployMap.keys) {
        switch (item) {
          case "resources":
            // manage resources
            YamlMap? resourcesMap = deployMap[item];
            if (resourcesMap != null) {
              for (var item2 in resourcesMap.keys) {
                switch (item2) {
                  case "limits":
                    // manage limits
                    YamlMap? limitsMap = resourcesMap[item2];
                    if (limitsMap != null) {
                      for (var item3 in limitsMap.keys) {
                        switch (item3) {
                          case "cpus":
                            // manage cpus
                            outputStr += "AllowedCPUs=${limitsMap[item3]}\n";
                            break;
                          case "memory":
                            // manage memory : MemoryMin in [Service] section
                            outputStr += "MemoryMax=${limitsMap[item3]}\n";
                            break;
                          case "pids":
                            // manage pids
                            outputStr += "PIDsLimit=${limitsMap[item3]}\n";
                            break;
                        }
                      }
                    }
                    break;
                  case "reservations":
                    // manage reservations
                    YamlMap? reservationsMap = resourcesMap[item2];
                    if (reservationsMap != null) {
                      for (var item3 in reservationsMap.keys) {
                        switch (item3) {
                          case "cpus":
                            // manage cpus
                            outputStr += "CPUQuota=${reservationsMap[item3]}\n";
                            break;
                          case "memory":
                            // manage memory
                            outputStr += "MemoryMin=${reservationsMap[item3]}\n";
                            break;
                        }
                      }
                    }
                    break;
                }
              }
            }
            break;
          case "mode":
            // manage mode
            outputStr += "Mode=${deployMap[item]}\n";
            break;
          case "replicas":
            // manage replicas
            outputStr += "Replicas=${deployMap[item]}\n";
            break;
          case "endpoint_mode":
            // manage endpoint_mode
            outputStr += "EndpointMode=${deployMap[item]}\n";
            break;
          case "labels":
            // manage labels
            YamlMap? labelsMap = deployMap[item];
            if (labelsMap != null) {
              for (var item2 in labelsMap.keys) {
                outputStr += "Label=${labelsMap[item2]}\n";
              }
            }
            break;
          case "placement":
            // manage placement
            // "constraints" and "preferences"
            YamlMap? placementMap = deployMap[item];
            if (placementMap != null) {
              for (var item2 in placementMap.keys) {
                switch (item2) {
                  case "constraints":
                    // manage constraints
                    YamlList? constraintsList = placementMap[item2];
                    if (constraintsList != null) {
                      for (var item3 in constraintsList) {
                        outputStr += "Constraint=$item3\n";
                      }
                    }
                    //outputStr += "Constraint=${placementMap[item2]}\n";
                    break;
                  case "preferences":
                    // manage preferences
                    YamlList? preferencesList = placementMap[item2];
                    if (preferencesList != null) {
                      for (var item3 in preferencesList) {
                        outputStr += "Preference=$item3\n";
                      }
                    }
                    //outputStr += "Preference=${placementMap[item2]}\n";
                    break;
                }
              }
            }
            break;
          case "restart_policy":
            // manage restart_policy
            YamlMap? restartPolicyMap = deployMap[item];
            if (restartPolicyMap != null) {
              for (var item2 in restartPolicyMap.keys) {
                switch (item2) {
                  case "condition":
                    // manage condition
                    YamlMap? conditionMap = restartPolicyMap[item2];
                    if (conditionMap != null) {
                      for (var item3 in conditionMap.keys) {
                        switch (item3) {
                          case "max_attempts":
                            // manage max_attempts
                            outputStr += "MaxAttempts=${conditionMap[item3]}\n";
                            break;
                          case "window":
                            // manage window
                            outputStr += "Window=${conditionMap[item3]}\n";
                            break;
                        }
                      }
                    }
                    break;
                  case "delay":
                    // manage delay
                    outputStr += "Delay=${restartPolicyMap[item2]}\n";
                    break;
                  case "max_attempts":
                    // manage max_attempts
                    outputStr += "MaxAttempts=${restartPolicyMap[item2]}\n";
                    break;
                  case "window":
                    // manage window
                    outputStr += "Window=${restartPolicyMap[item2]}\n";
                    break;
                }
              }
            }
            break;
          case "rollback_config":
            // manage rollback_config
            YamlMap? rollbackConfigMap = deployMap[item];
            if (rollbackConfigMap != null) {
              for (var item2 in rollbackConfigMap.keys) {
                switch (item2) {
                  case "failure_action":
                    // manage failure_action
                    outputStr += "FailureAction=${rollbackConfigMap[item2]}\n";
                    break;
                  case "monitor":
                    // manage monitor
                    outputStr += "Monitor=${rollbackConfigMap[item2]}\n";
                    break;
                  case "partition":
                    // manage partition
                    outputStr += "Partition=${rollbackConfigMap[item2]}\n";
                    break;
                  case "retry":
                    // manage retry
                    outputStr += "Retry=${rollbackConfigMap[item2]}\n";
                    break;
                }
              }
            }
            break;
          case "update_config":
            // manage update_config
            YamlMap? updateConfigMap = deployMap[item];
            if (updateConfigMap != null) {
              for (var item2 in updateConfigMap.keys) {
                switch (item2) {
                  case "delay":
                    // manage delay
                    outputStr += "Delay=${updateConfigMap[item2]}\n";
                    break;
                  case "failure_action":
                    // manage failure_action
                    outputStr += "FailureAction=${updateConfigMap[item2]}\n";
                    break;
                  case "monitor":
                    // manage monitor
                    outputStr += "Monitor=${updateConfigMap[item2]}\n";
                    break;
                  case "order":
                    // manage order
                    outputStr += "Order=${updateConfigMap[item2]}\n";
                    break;
                  case "parallelism":
                    // manage parallelism
                    outputStr += "Parallelism=${updateConfigMap[item2]}\n";
                    break;
                  case "retry":
                    // manage retry
                    outputStr += "Retry=${updateConfigMap[item2]}\n";
                    break;
                }
              }
            }
            break;
          default:
        }
      }
    }
    outputStr += "\n";

    outputStr += "[Install]\n";
    outputStr += "WantedBy=default.target\n";
  });

  return outputStr;
}
