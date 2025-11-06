import 'package:compose2target/generators/network.dart';
import 'package:compose2target/tools.dart';
import 'package:yaml/yaml.dart';

bool useMetricsAuthorized = false;
bool useMetricsHttpAuthorized = false;

String generateLoggingPart(
  YamlMap? logList,
  Map variablesList2,
  String containerName,
) {
  String outputStr = "";
  /*
    logging:
      driver: k8s-file
      options:
        max-size: 20m
        max-file: 3
        path: ${DEFAULTLOGPATH}/name.log
  */
  outputStr += "$t${t}logging:\n";
  if (logList != null) {
    logList.forEach((key, value) {
      if (value is YamlMap) {
        //print("key=$key\n");
        outputStr += "$t$t$t$key:\n";
        value.forEach((reskey, resvalue) {
          String foundStr = searchIfVarUsed(
            resvalue.toString(),
            variablesList2,
          );
          if (foundStr.isNotEmpty) {
            //print("____ $reskey: \"$foundStr\"\n");
            outputStr += "$t$t$t$t$reskey: \"$foundStr\"\n";
          } else {
            //print("____ $reskey: \"$resvalue\"\n");
            outputStr += "$t$t$t$t$reskey: \"$resvalue\"\n";
          }
        });
      } else {
        String foundStr = searchIfVarUsed(value.toString(), variablesList2);
        if (foundStr.isNotEmpty) {
          //print("++++2 $key: \"$foundStr\"\n");
          outputStr += "$t$t$t$key: \"$foundStr\"\n";
        } else {
          //print("++++ $key: \"$value\"\n");
          outputStr += "$t$t$t$key: \"$value\"\n";
        }
      }
    });
  }
  return outputStr;
}

String generateDeployPart(
  YamlMap? deployList,
  Map variablesList2,
  String containerName,
) {
  String outputStr = "";
  /*
    deploy:
      resources:
        limits:
          cpus: '0.50'
          memory: 50M
          pids: 1
        reservations:
          cpus: '0.25'
          memory: 20M */
  outputStr += "$t${t}deploy:\n";
  if (deployList != null) {
    deployList.forEach((key, value) {
      if (value is YamlMap) {
        outputStr += "$t$t$t$key:\n";
        value.forEach((reskey, resvalue) {
          if (resvalue is YamlMap) {
            outputStr += "$t$t$t$t$reskey:\n";
            resvalue.forEach((itemkey, itemvalue) {
              String foundStr = searchIfVarUsed(
                itemvalue.toString(),
                variablesList2,
              );
              if (foundStr.isNotEmpty) {
                outputStr += "$t$t$t$t$t$itemkey: \"$foundStr\"\n";
              } else {
                outputStr += "$t$t$t$t$t$itemkey: \"$itemvalue\"\n";
              }
            });
          } else {
            String foundStr = searchIfVarUsed(
              resvalue.toString(),
              variablesList2,
            );
            if (foundStr.isNotEmpty) {
              outputStr += "$t$t$t$t$key: \"$foundStr\"\n";
            } else {
              outputStr += "$t$t$t$t$reskey: \"$resvalue\"\n";
            }
          }
        });
      } else {
        String foundStr = searchIfVarUsed(value.toString(), variablesList2);
        if (foundStr.isNotEmpty) {
          outputStr += "$t$t$t$key: \"$foundStr\"\n";
        } else {
          outputStr += "$t$t$t$key: \"$value\"\n";
        }
      }
    });
  }
  return outputStr;
}

String generateLabelsPart(String containerName, var labelsList) {
  String outputStr = "";
  // If data are only indented, it's a YamlMap
  if (labelsList is YamlMap) {
    YamlMap lstLabels = labelsList;
    lstLabels.forEach((key, value) {
      outputStr += "$t$t$t- $key=\"$value\"\n";
      //outputStr += "$t$t$t- $containerName.$key=\"$value\"\n";
    });
  }
  // If data are preceding by '-', it's a YamlList containing a single key,value YamlMap
  if (labelsList is YamlList) {
    YamlList lstLabels = labelsList;
    for (var item in lstLabels) {
      if (item is String) {
        final (labelStr, labelValue) = extractStrings(item);
        if (labelStr == "metrics") {
          useMetricsAuthorized = bool.parse(labelValue);
        }
        if (labelStr == "metricshttp") {
          useMetricsHttpAuthorized = bool.parse(labelValue);
        }
        outputStr += "$t$t$t- $labelStr=$labelValue\n";
        //outputStr += "$t$t$t- $containerName.$labelStr=$labelValue\n";
      } else {
        if (item.keys.first == "metrics") {
          bool? foo = bool.tryParse(item.values.first);
          if (foo == null || foo == false) {
            useMetricsAuthorized = false;
          } else {
            useMetricsAuthorized = true;
          }
        }
        if (item.keys.first == "metricshttp") {
          bool? foo = bool.tryParse(item.values.first);
          if (foo == null || foo == false) {
            useMetricsHttpAuthorized = false;
          } else {
            useMetricsHttpAuthorized = true;
          }
        }
        outputStr += "$t$t$t- ${item.keys.first}=\"${item.values.first}\"\n";
        //"$t$t$t- $containerName.${item.keys.first}=\"${item.values.first}\"\n";
      }
    }
  }
  return outputStr;
}

String generateAnnotationsPart(String containerName, var annotationsList) {
  String outputStr = "";
  // If data are only indented, it's a YamlMap
  if (annotationsList is YamlMap) {
    YamlMap lstLabels = annotationsList;
    lstLabels.forEach((key, value) {
      outputStr += "$t$t$t- $key=\"$value\"\n";
    });
  }
  // If data are preceding by '-', it's a YamlList containing a single key,value YamlMap
  if (annotationsList is YamlList) {
    YamlList lstLabels = annotationsList;
    for (var item in lstLabels) {
      if (item is String) {
        final (labelStr, labelValue) = extractStrings(item);
        outputStr += "$t$t$t- $labelStr=$labelValue\n";
      } else {
        outputStr += "$t$t$t- ${item.keys.first}=\"${item.values.first}\"\n";
      }
    }
  }
  return outputStr;
}

String generateEnvPart(var envList, Map variablesList2, String containerName) {
  String outputStr = "";
  if (envList != null) {
    if (envList is YamlList) {
      for (var value in envList) {
        String foundStr = searchIfVarUsed(value, variablesList2);
        if (foundStr.isNotEmpty) {
          outputStr += "$t$t$t- $foundStr\n";
        }
      }
    } else if (envList is YamlMap) {
      YamlMap mapList = envList;
      mapList.forEach((key, value) {
        if (value == null) {
          outputStr += "$t$t$t- $key\n";
        } else {
          outputStr += "$t$t$t- $key=$value\n";
        }
      });
    }
  }
  return outputStr;
}

String generateCommandPart(var cmd, YamlMap variablesList) {
  String outputStr = "";
  if (cmd != null) {
    if (cmd is String) {
      outputStr += "$t${t}command: ${fullMappingOnly(cmd, variablesList)}\n";
    } else {
      String foundStr = searchIfVarUsed(
        convertCommandToString(cmd),
        variablesList,
      );
      if (foundStr.isNotEmpty) {
        outputStr += "$t${t}command: [$foundStr]\n";
      } else {
        // if command is  without [], take it as it is
        outputStr += "$t${t}command: $cmd\n";
      }
    }
  }
  return outputStr;
}

/*
  - "3000"
  - "3000-3005"
  - "8000:8000"
  - "9090-9091:8080-8081"
  - "49100:22"
  - "8000-9000:80"
  - "127.0.0.1:8001:8001"
  - "127.0.0.1:5000-5010:5000-5010"
  - "6060:6060/udp"
*/
String generatePortsPart(portsList, variablesList) {
  String outputStr = "";
  if (portsList != null) {
    // Work with ports
    outputStr += "$t${t}ports:\n";
    // - PORT: xxx   => [{PORT: xxx}]
    // - PORT:xxx    => [PORT:xxx]
    for (var value in portsList) {
      if (value is String) {
        // "[[IP:](port|range)](port|range)[/protocol]"
        // "3030"
        RegExp singlePort = RegExp(r'^(?:-?(?:0|[1-9][0-9]*))$');
        // "3000-3050"
        RegExp rangePort = RegExp(
          r'^(?:-?(?:0|[1-9][0-9]*))-(?:-?(?:0|[1-9][0-9]*))$',
        );
        // "8000:8000"
        RegExp portMapping = RegExp(
          r'^(?:-?(?:0|[1-9][0-9]*)):(?:-?(?:0|[1-9][0-9]*))$',
        );
        // "3000-3050:4000-4050"
        RegExp portRangeMapping = RegExp(
          r'^(?:-?(?:0|[1-9][0-9]*))-(?:-?(?:0|[1-9][0-9]*)):(?:-?(?:0|[1-9][0-9]*))-(?:-?(?:0|[1-9][0-9]*))$',
        );
        // "127.0.0.1:8000:8000"
        RegExp ipMapping = RegExp(
          r'^(\d?\d?\d)\.(\d?\d?\d)\.(\d?\d?\d)\.(\d?\d?\d):(?:-?(?:0|[1-9][0-9]*)):(?:-?(?:0|[1-9][0-9]*))$',
        );
        // "127.0.0.1:8000:8000/udp"
        RegExp ipMappingProtocol = RegExp(
          r'^(\d?\d?\d)\.(\d?\d?\d)\.(\d?\d?\d)\.(\d?\d?\d):(?:-?(?:0|[1-9][0-9]*)):(?:-?(?:0|[1-9][0-9]*))/(udp|tcp)$',
        );
        // MAPTOTO_PORT:8051
        RegExp portVarMapping = RegExp(
          r'^[_a-zA-Z0-9]*:(?:-?(?:0|[1-9][0-9]*))$',
        );

        if (singlePort.hasMatch(value)) {
          //print("single port found        : $value");
          outputStr += "$t$t$t- \"$value\"\n";
        } else if (rangePort.hasMatch(value)) {
          //print("range found              : $value");
          outputStr += "$t$t$t- \"$value\"\n";
        } else if (portMapping.hasMatch(value)) {
          //print("port mapping found       : $value");
          outputStr += "$t$t$t- \"$value\"\n";
        } else if (portRangeMapping.hasMatch(value)) {
          //print("port range mapping found : $value");
          outputStr += "$t$t$t- \"$value\"\n";
        } else if (ipMapping.hasMatch(value)) {
          //print("ip mapping found         : $value");
          outputStr += "$t$t$t- \"$value\"\n";
        } else if (ipMappingProtocol.hasMatch(value)) {
          //print("ip mapping protocol found: $value");
          outputStr += "$t$t$t- \"$value\"\n";
        } else if (portVarMapping.hasMatch(value)) {
          //print("port var mapping found       : $value");
          final (portStr, portValue) = extractStrings(value);
          if (portStr == "ANYONE") {
            outputStr += "$t$t$t- \"${portValue.toString()}\"\n";
          } else {
            if (variablesList != null) {
              String searchPortValue = searchVarValue(portStr, variablesList);
              outputStr += "$t$t$t- \"$searchPortValue:$portValue\"\n";
            }
          }
        }
      } else {
        Map port = value;
        String portStr = "";
        if (port.keys.first is int) {
          portStr = port.keys.first.toString();
        } else {
          portStr = port.keys.first;
        }
        if (portStr == "ANYONE") {
          outputStr += "$t$t$t- \"${port.values.first}\"\n";
        } else {
          if (variablesList != null) {
            String searchPortValue = searchVarValue(portStr, variablesList);
            outputStr += "$t$t$t- \"$searchPortValue:${port.values.first}\"\n";
          }
        }
      }
    }
  }
  return outputStr;
}

// If fileList is null, only one file
// Else fileList must be used to generate compose orders
void generateComposeScript(
  String scriptName,
  String data,
  List<String>? fileList,
) {
  String beginpart = """
#!/bin/bash
""";

  String mainpart =
      """
ACTION=\$1
COMPOSE=\$2
if [ "\${COMPOSE}" == "" ]; then
    COMPOSE=\${DEFAULTFILE}
fi
usage() {
  echo "Usage: $scriptName ( start | stop | restart)"
}
startAll() {
""";

  String composeStartOrder = "    podman-compose -f \${COMPOSE} up -d\n";

  if (fileList != null) {
    composeStartOrder = "";
    for (String file in fileList) {
      composeStartOrder += "    podman-compose -f $file up -d\n";
    }
  }

  String mainPart2 = """
}
stopAll() {
""";

  String composeStopOrder = "    podman-compose -f \${COMPOSE} down\n";

  if (fileList != null) {
    composeStopOrder = "";
    for (String file in fileList.reversed) {
      composeStopOrder += "    podman-compose -f $file down\n";
    }
  }

  String mainPart3 = """
}
restartAll() {
  stopAll
  startAll
}
case "\${ACTION}" in
    "start" )
        startAll
        ;;
    "stop" )
        stopAll
        ;;
    "restart" )
        restartAll
        ;;
    *)
        usage
        ;;
esac
""";

  String outputStr = beginpart;
  outputStr += "DEFAULTFILE=\"$data\"\n";
  outputStr +=
      mainpart + composeStartOrder + mainPart2 + composeStopOrder + mainPart3;
  generateOutputFile(scriptName, outputStr);
}

// objStr = 'configs' | 'secrets'
String generateObjectsPartLevel2(
  String objStr,
  var configsList,
  Map mappingData, {
  String tabStr = "$t$t",
}) {
  String outputStr = "";
  outputStr += "$tabStr$objStr:\n";
  if (configsList is YamlMap) {
    configsList.forEach((key, value) {
      if (value is YamlMap) {
        if (value.toString() == "{}") {
          outputStr += "$tabStr$t$key: {}\n";
        } else {
          String foo = fullMappingOnly("$tabStr$t", mappingData);
          outputStr += generateObjectsPartLevel2(
            key,
            value,
            mappingData,
            tabStr: foo,
          );
          /*"$tabStr$key:\n";
          value.forEach((key2, value2) {
            outputStr += "$tabStr$t$key2: $value2\n";
          });*/
        }
      } else {
        outputStr +=
            "$tabStr$key: ${fullMappingOnly(value.toString(), mappingData)}\n";
      }
    });
  } else if (configsList is YamlList) {
    for (var value in configsList) {
      if (value is YamlMap) {
        String first = "-";
        value.forEach((key, value2) {
          //String foo = "$tabStr$t";
          //outputStr += generateObjectsPartLevel2(key, value2, mappingData, tabStr: foo);
          outputStr +=
              "$tabStr$t$first $key: ${fullMappingOnly(value2.toString(), mappingData)}\n";
          first = " ";
        });
      } else {
        outputStr +=
            "$tabStr$t- ${fullMappingOnly(value.toString(), mappingData)}\n";
      }
    }
  }
  return outputStr;
}

String workWithVolumes(
  YamlList? mountList,
  String containerName,
  Map servicesList,
) {
  String outputStr = "";
  if (mountList != null) {
    outputStr += "$t${t}volumes:\n";
    for (var value in mountList) {
      if (value is String) {
        final (ignoreStr, mountStrCont) = extractStrings(value);
        String retStr = searchMountValue(
          mountStrCont,
          containerName,
          servicesList,
        );
        if (retStr.isNotEmpty) {
          String tmp = checkSpecialVolumes(mountStrCont, true);
          outputStr += "$t$t$t- $retStr:$tmp\n";
        } else {
          String tmp = checkSpecialVolumes(value, false);
          outputStr += "$t$t$t- $tmp\n";
        }
      } else {
        // value is Map
        String retStr = searchMountValue(
          value.values.first,
          containerName,
          servicesList,
        );
        if (retStr.isNotEmpty) {
          String tmp = checkSpecialVolumes(value.values.first, true);
          outputStr += "$t$t$t- $retStr:$tmp\n";
        } else {
          String tmp = checkSpecialVolumes(
            "${value.keys.first}:${value.values.first}",
            false,
          );
          outputStr += "$t$t$t- $tmp\n";
        }
      }
    }
  }
  return outputStr;
}

String workWithServices(
  YamlMap containersList,
  Map mappingData,
  String network,
  bool addMetrics,
  bool addGenericOutput,
  bool devMode,
) {
  // Get data from mappingFile
  YamlMap servicesList = mappingData['services'];
  YamlMap variablesList = mappingData['variables'];
  YamlMap? genericList = (addGenericOutput)
      ? mappingData['genericoutput']
      : null;
  YamlMap? metricsList = (mappingData.isNotEmpty)
      ? mappingData['metrics']
      : null;
  YamlMap? metricsHttpList = (mappingData.isNotEmpty)
      ? mappingData['metricshttp']
      : null;
  String outputStr = "";

  Map variablesList2 = convertYamlMapToMap(variablesList);

  // Working with containers
  outputStr += "services:\n";
  // Level 1: Each key 'services' present is associated to a container
  containersList.forEach((key, value) {
    // The key is the container name
    String containerName = key;
    outputStr += "$t$containerName:\n";
    // Level 2 :
    outputStr += "$t${t}container_name: $containerName\n";

    //var foo = containersList[containerName];
    //print("foo:${foo.toString()}");
    variablesList2['SERVICENAME'] = containerName;

    // Level 2 :
    outputStr += (devMode)
        ? "$t${t}image: ${fullMappingOnly(containersList[containerName]['image'], mappingData)}\n"
        : "$t${t}image: ${fullMappingOnly(servicesList[containerName]['image'], mappingData)}\n";

    // Level 2 : Searching 'labels:' field in inputfile
    var labelsList = value['labels'];
    var labelsList2 = (servicesList[containerName] != null
        ? servicesList[containerName]['labels']
        : null);
    var labelsGeneric = (genericList != null ? genericList['labels'] : null);

    if (labelsList != null || labelsList2 != null || labelsGeneric != null) {
      outputStr += "$t${t}labels:\n";
    }
    outputStr += generateLabelsPart(containerName, labelsList);
    outputStr += generateLabelsPart(containerName, labelsList2);
    outputStr += generateLabelsPart(containerName, labelsGeneric);

    // Level 2 : Searching 'annotations:' field in inputfile
    var annotationsList = value['annotations'];
    var annotationsList2 = (servicesList[containerName] != null
        ? servicesList[containerName]['annotations']
        : null);
    var annotationsGeneric = (genericList != null
        ? genericList['annotations']
        : null);

    if (annotationsList != null ||
        annotationsList2 != null ||
        annotationsGeneric != null) {
      outputStr += "$t${t}annotations:\n";
    }
    outputStr += generateAnnotationsPart(containerName, annotationsList);
    outputStr += generateAnnotationsPart(containerName, annotationsList2);
    outputStr += generateAnnotationsPart(containerName, annotationsGeneric);

    // Level 2 :
    if (devMode) {
      String? restart = containersList[containerName]['restart'];
      if (restart == null) {
        outputStr += "$t${t}restart: always\n";
      } else {
        outputStr += "$t${t}restart: $restart\n";
      }
    } else {
      String? restart = servicesList[containerName]['restart'];
      if (restart == null) {
        outputStr += "$t${t}restart: always\n";
      } else {
        outputStr += "$t${t}restart: $restart\n";
      }
    }
    /*if (podName.isEmpty) {
      outputStr += "$t${t}userns_mode: keep-id:uid=1000\n"; // Only possible if no pod created
    }*/

    // Level 2 : 'command' present in input file is prioritary
    if (devMode) {
      var cmd = containersList[containerName]['command'];
      if (cmd == null) {
        // No 'command' in input file, search in mappingFile
        var cmd2 = servicesList[containerName]['command'];
        if (cmd2 != null) {
          outputStr += generateCommandPart(cmd2, variablesList);
        }
      } else {
        outputStr += generateCommandPart(cmd, variablesList);
      }
    } else {
      // 'command' is taken from mappingFile
      var cmd = servicesList[containerName]['command'];
      outputStr += generateCommandPart(cmd, variablesList);
    }

    // Level 2 :
    YamlList? portsList = containersList[containerName]['ports'];
    portsList ??= servicesList[containerName]['ports'];
    outputStr += generatePortsPart(portsList, variablesList);

    // Level 2 :
    var envGeneric = (genericList != null ? genericList['environment'] : null);
    YamlList? envMetrics = (metricsList != null)
        ? metricsList['environment']
        : null;
    YamlList? envMetricsHttp = (metricsHttpList != null)
        ? metricsHttpList['environment']
        : null;
    if (devMode) {
      var envList = containersList[containerName]['environment'];
      if (envList != null || envGeneric != null) {
        outputStr += "$t${t}environment:\n";
      }
      outputStr += generateEnvPart(envList, variablesList2, containerName);
    } else {
      var envList = containersList[containerName]['environment'];
      var envList2 = servicesList[containerName]['environment'];
      if (envList != null || envList2 != null || envGeneric != null) {
        outputStr += "$t${t}environment:\n";
      }
      //outputStr += "$t${t}environment:\n";
      //outputStr += "$t$t$t- PODMAN_USERNS:\"keep-id:uid=1000,gid=1000\"\n";
      outputStr += generateEnvPart(envList2, variablesList2, containerName);
      outputStr += generateEnvPart(envList, variablesList2, containerName);
      if (envGeneric != null) {
        for (var value in envGeneric) {
          outputStr += "$t$t$t- $value\n";
        }
      }
    }
    if (envGeneric != null) {
      for (var value in envGeneric) {
        outputStr += "$t$t$t- $value\n";
      }
    }
    //if (addMetrics & useMetricsAuthorized && envMetrics != null) {
    //  outputStr += generateEnvPart(envMetrics, variablesList2, containerName);
    //}
    if (addMetrics) {
      if (useMetricsAuthorized && envMetrics != null) {
        outputStr += generateEnvPart(envMetrics, variablesList2, containerName);
      }
      if (useMetricsHttpAuthorized && envMetricsHttp != null) {
        outputStr += generateEnvPart(
          envMetricsHttp,
          variablesList2,
          containerName,
        );
      }
    }
    useMetricsAuthorized = false;
    useMetricsHttpAuthorized = false;

    // Level 2 : deploy:
    YamlMap? deployList = (devMode)
        ? containersList[containerName]['deploy']
        : servicesList[containerName]['deploy'];
    if (deployList != null) {
      outputStr += generateDeployPart(
        deployList,
        variablesList2,
        containerName,
      );
    }

    // Level 2 : logging:
    YamlMap? loggingList = (devMode)
        ? containersList[containerName]['logging']
        : servicesList[containerName]['logging'];
    if (loggingList != null) {
      outputStr += generateLoggingPart(
        loggingList,
        variablesList2,
        containerName,
      );
    }

    // Level 2 :
    if (network.isNotEmpty) {
      outputStr += "$t${t}networks:\n";
      outputStr += "$t$t$t- $network\n";
    } else {
      var networksList = containersList[containerName]['networks'];
      if (networksList != null) {
        outputStr += generateObjectsPartLevel2(
          'networks',
          networksList,
          mappingData,
        );
      }
    }
    // Level 2 : depends_on
    if (containersList[containerName]['depends_on'] != null) {
      outputStr += "$t${t}depends_on:\n";
      YamlList dependList = containersList[containerName]['depends_on'];
      for (var value in dependList) {
        outputStr += "$t$t$t- $value\n";
      }
    }
    // Level 2 :
    if (devMode) {
      outputStr += workWithVolumes(
        containersList[containerName]['volumes'],
        containerName,
        servicesList,
      );
    } else {
      outputStr += workWithVolumes(
        servicesList[containerName]['volumes'],
        containerName,
        servicesList,
      );
    }
    // Level 2 : configs
    var configsList = containersList[containerName]['configs'];
    if (configsList != null) {
      outputStr += generateObjectsPartLevel2(
        'configs',
        configsList,
        mappingData,
      );
    }
    // Level 2 : secrets
    var secretsList = containersList[containerName]['secrets'];
    if (secretsList != null) {
      outputStr += generateObjectsPartLevel2(
        'secrets',
        secretsList,
        mappingData,
      );
    }

    // Level 2 : working_dir
    var workdir = containersList[containerName]['working_dir'];
    if (workdir != null) {
      outputStr += "$t${t}working_dir: $workdir\n";
    }

    // Level 2 : security_opt
    if (devMode) {
      var securityOptList = containersList[containerName]['security_opt'];
      if (securityOptList != null) {
        //fullMappingOnly(securityOptList, mappingData);
        outputStr += generateObjectsPartLevel2(
          'security_opt',
          securityOptList,
          mappingData,
        );
      }
    } else {
      var securityOptList = servicesList[containerName]['security_opt'];
      if (securityOptList != null) {
        //fullMappingOnly(securityOptList, mappingData);
        outputStr += generateObjectsPartLevel2(
          'security_opt',
          securityOptList,
          mappingData,
        );
      }
    }
    // Level 2 : tmpfs, security_opt, profiles
  });
  return outputStr;
}

String workWithObjectsPartLevel1(
  String objStr,
  YamlMap configsList, {
  String tabStr = "",
}) {
  String outputStr = "";
  outputStr += "$tabStr$objStr:\n";
  configsList.forEach((key, value) {
    if (value is YamlMap) {
      if (value.toString() == "{}") {
        outputStr += "$tabStr$t$key: {}\n";
      } else {
        String foo = "$tabStr$t";
        outputStr += workWithObjectsPartLevel1(key, value, tabStr: foo);
      }
    } else {
      if (value == null) {
        outputStr += "$tabStr$t$key:\n";
      } else {
        outputStr += "$tabStr$t$key: $value\n";
      }
    }
  });
  return outputStr;
}

String generateComposePartInternal(
  Map mappingData,
  Map inputData,
  String network,
  bool addMetrics,
  bool addGenericOutput,
  bool devMode,
  bool addPodInOutput,
) {
  // if a key 'name' is present, a pod will be created and the value will be used for the POD name
  String outputStr = "";

  if (addPodInOutput) {
    // Level 0 : Check if field 'name:' is present
    String podName = inputData['name'] ?? "";
    if (podName.isNotEmpty) {
      outputStr += "name: $podName\n";
    }
  }

  // Level 0 : Check if field 'networks' is present
  YamlMap? networksList = inputData['networks'];
  if (networksList != null) {
    outputStr += workWithObjectsPartLevel1('networks', networksList);
  } else {
    // Level 0 : Generate 'network' section if needed
    outputStr += generateNetworksPart(network);
  }

  // Level 0 : Check if field 'service' is present
  // Get data from inputFile
  YamlMap? containersList = inputData['services'];
  if (containersList != null) {
    outputStr += workWithServices(
      containersList,
      mappingData,
      network,
      addMetrics,
      addGenericOutput,
      devMode,
    );
  }

  // Level 0 : Check if field 'volumes' is present
  YamlMap? volumesList = inputData['volumes'];
  if (volumesList != null) {
    outputStr += workWithObjectsPartLevel1('volumes', volumesList);
  }

  // Level 0 : Check if field 'secrets' is present
  YamlMap? secretsList = inputData['secrets'];
  if (secretsList != null) {
    outputStr += workWithObjectsPartLevel1('secrets', secretsList);
  }

  // Level 0 : Check if field 'configs' is present
  YamlMap? configsList = inputData['configs'];
  if (configsList != null) {
    outputStr += workWithObjectsPartLevel1('configs', configsList);
  }

  return outputStr;
}
