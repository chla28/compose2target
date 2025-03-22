import 'dart:io';
import 'package:yaml/yaml.dart';

// '$t' is used to format output yaml files
const String t = "  ";

Future<bool> generateOutputFile(String outputFile, String outputStr) async {
  var file = File(outputFile);
  var sink = file.openWrite();
  sink.write(outputStr);

  await sink.flush();

  // Close the IOSink to free system resources.
  await sink.close();
  return true;
}

// Search a String inside a Map
//   If found returns associated value else return original String
String searchVarValue(String searchedStr, Map variablesList) {
  var tmpStr = variablesList[searchedStr];
  return tmpStr ?? searchedStr;
}

// Find all 'key' present in inputStr
//  If key is found, they are replaced by their 'value'
String searchIfVarUsed(String inputStr, Map variablesList) {
  variablesList.forEach((key, value) {
    if (inputStr.contains("\$$key")) {
      inputStr = inputStr.replaceAll("\$$key", value.toString());
    }
  });
  return inputStr;
}

// Find a String in the serviceList map
YamlMap searchService(String searchedStr, Map servicesList) {
  return servicesList[searchedStr];
}

// Extract a String from a String with ':' or '=' separator
//   return a records with each part of the string
(String, String) extractStrings(String inputStr) {
  // Check if field separator is ':' ou '='
  var idx = inputStr.indexOf(":");
  if (idx == -1) {
    idx = inputStr.indexOf("=");
  }
  String labelStr;
  String labelValue;
  if (idx == -1) {
    labelStr = inputStr;
    labelValue = inputStr;
  } else {
    labelStr = inputStr.substring(0, idx).trim(); //Remove potentials spaces around the string
    labelValue = inputStr.substring(idx + 1).trim(); //Remove potentials spaces around the string
  }
  return (labelStr, labelValue);
}

// inputString = /host:ro,rslave  ==> ajout de ",Z" avec selinux
// inputString = /etc/grafana/provisioning/datasources/datasources.yml  ==> ajout de ":Z" avec selinux
String checkSpecialVolumes(String inputString, bool useSELinux) {
  String outputStr = "";
  var idx = inputString.indexOf(":");
  //print(idx);
  if (idx == -1) {
    String selinux = (useSELinux) ? ":Z" : "";
    outputStr += "$inputString$selinux";
  } else {
    if (inputString.endsWith(":Z")) {
      outputStr += "$inputString";
    } else {
      String selinux = (useSELinux) ? ",Z" : "";
      outputStr += "$inputString$selinux";
    }
  }
  return outputStr;
}

// Find a mount value associated to a container (service)
String searchMountValue(String searchedStr, String service, Map servicesList) {
  YamlList? mountValues = (servicesList[service] != null ? servicesList[service]['volumes'] : null);
  if (mountValues != null) {
    // mountValues can contains a YamlMap or a String : {/local/drbd_data1/DB/AlarmDB: /var/lib/mysql/data}, /local/drbd_data1/DB/AlarmDB2:/var/lib/mysql/data2
    for (Object item in mountValues) {
      if (item is Map) {
        if (item.values.first == searchedStr) {
          return item.keys.first;
        }
      } else if (item is String) {
        final (labelStr, labelValue) = extractStrings(item);

        if (labelValue == searchedStr) {
          return labelStr;
        }
      }
    }
  }
  return "";
}

Map<String, dynamic> convertYamlMapToMap(YamlMap yamlMap) {
  final map = <String, dynamic>{};

  for (final entry in yamlMap.entries) {
    if (entry.value is YamlMap || entry.value is Map) {
      map[entry.key.toString()] = convertYamlMapToMap(entry.value);
    } else {
      map[entry.key.toString()] = entry.value.toString();
    }
  }
  return map;
}

String fullMappingOnly(String yamlContent, Map mappingData) {
  String outputStr = yamlContent;
  YamlMap? variablesList = mappingData['variables'];
  // pour chaque variable de mapdoc, on fait un replaceAll
  if (variablesList != null) {
    variablesList.forEach((key, value) {
      outputStr = outputStr.replaceAll("\$$key", value.toString());
      outputStr = outputStr.replaceAll(key, value.toString());
    });
  }
  return outputStr;
}
