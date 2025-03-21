import 'package:compose2target/tools.dart';
import 'package:yaml/yaml.dart';

String generateRunPartInternal(Map mappingData, Map inputData, String networkName, bool addMetrics, bool addGrpcTraces, bool addGenericOutput) {
  YamlMap servicesList = mappingData['services'];
  YamlMap variablesList = mappingData['variables'];
  YamlMap containersList = inputData['services'];

  String outputStr = "";

  // Pour chaque clef de "services" correspond un container
  containersList.forEach((key, value) {
    String image = servicesList[key]['image'];

    String command = "";
    if (servicesList[key]['command'] != null) {
      String foundStr = searchIfVarUsed(servicesList[key]['command'], variablesList);
      if (foundStr.isNotEmpty) {
        command = foundStr;
      } else {
        command = servicesList[key]['command'].toString();
      }
    } else {
      if (containersList[key]['command'] != null) {
        String foundStr = searchIfVarUsed(containersList[key]['command'], variablesList);
        if (foundStr.isNotEmpty) {
          command = foundStr;
        } else {
          command = containersList[key]['command'].toString();
        }
      }
    }

    String portListStr = "";
    if (containersList[key]['ports'] != null) {
      YamlList portsList = containersList[key]['ports'];
      for (var value in portsList) {
        if (value is String) {
          var idx = value.indexOf(":");
          String portStr = value.substring(0, idx);
          String portValue = value.substring(idx + 1);
          String searchPortValue = searchVarValue(portStr, variablesList);
          portListStr += "-p $searchPortValue:$portValue ";
        } else {
          Map port = value;
          String portStr = port.keys.first;
          String searchPortValue = searchVarValue(portStr, variablesList);
          portListStr += "-p $searchPortValue:${port.values.first} ";
        }
      }
    }

    String envListStr = "";
    if (containersList[key]['environment'] != null) {
      YamlList envList = containersList[key]['environment'];
      for (var value in envList) {
        String foundStr = searchIfVarUsed(value, variablesList);
        if (foundStr.isNotEmpty) {
          envListStr += "-e $foundStr ";
        }
      }
      if (servicesList[key]['environment'] != null) {
        YamlList envList = servicesList[key]['environment'];
        for (var value in envList) {
          String foundStr = searchIfVarUsed(value, variablesList);
          if (foundStr.isNotEmpty) {
            envListStr += "-e $foundStr ";
          }
        }
      }
    }

    String volListStr = "";
    if (containersList[key]['volumes'] != null) {
      YamlList mountList = containersList[key]['volumes'];
      for (var value in mountList) {
        if (value is String) {
          var idx = value.indexOf(":");
          String mountStrCont = value.substring(idx + 1);
          String retStr = searchMountValue(mountStrCont, key, servicesList);
          if (retStr.isNotEmpty) {
            volListStr += "-v $retStr:$mountStrCont:Z ";
          }
        } else {
          //outputStr += "$t$t$t- $value\n";
          String retStr = searchMountValue(value.values.first, key, servicesList);
          if (retStr.isNotEmpty) {
            volListStr += "-v $retStr:${value.values.first}:Z ";
          }
        }
      }
    }
    outputStr += "podman run -d -it --name $key\\\n";
    if (portListStr.isNotEmpty) {
      outputStr += "    $portListStr \\\n";
    }
    if (envListStr.isNotEmpty) {
      outputStr += "    $envListStr \\\n";
    }
    if (volListStr.isNotEmpty) {
      outputStr += "    $volListStr \\\n";
    }
    outputStr += "    $image $command\n\n";
  });

  return outputStr;
}
