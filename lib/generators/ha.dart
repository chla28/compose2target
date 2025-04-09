import 'package:compose2target/tools.dart';
import 'package:yaml/yaml.dart';

String generateHAPartInternal(Map inputData) {
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
    outputStr += "pcs resource create $containerName ocf:other:podmanrootless \n";
    outputStr += "\timage=\"${containersList[containerName]['image']}\" name=\"$containerName\" \n";
    outputStr += "\tallow_pull=false reuse=false \n";

    String tmpVolListOutputStr = "";
    String volListStr = "";
    if (containersList[key]['volumes'] != null) {
      YamlList mountList = containersList[key]['volumes'];
      for (var value in mountList) {
        if (value is String) {
          final (localStr, mountStrCont) = extractStrings(value);
          String tmp = checkSpecialVolumes(mountStrCont, true);
          volListStr += "-v $localStr:$tmp ";
          tmpVolListOutputStr += localStr;
        } else {
          String tmp = checkSpecialVolumes(value.values.first, true);
          volListStr += "-v ${value.keys.first}:$tmp ";
          tmpVolListOutputStr += "${value.keys.first}";
        }
        tmpVolListOutputStr += ",";
      }
      outputStr += "\tmount_points=\"$tmpVolListOutputStr\" \n";
    }

    var cmd2 = containersList[containerName]['command'];
    if (cmd2 != null) {
      String cmd = "";
      if (cmd2 is String) {
        outputStr += "\trun_cmd=\"$cmd $cmd2\"\n";
      } else if (cmd2 is YamlList) {
        String cmdStr = "";
        for (var value in cmd2) {
          cmdStr += " $value";
        }
        outputStr += "\trun_cmd=\"$cmd $cmdStr\"\n";
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
          portListStr += "-p $portStr:$portValue ";
        } else {
          Map port = value;
          String portStr = "";
          if (port.keys.first is int) {
            portStr = port.keys.first.toString();
          } else {
            portStr = port.keys.first;
          }
          portListStr += "-p $portStr:${port.values.first} ";
        }
      }
    }
    String envListStr = "";
    if (containersList[key]['environment'] != null) {
      YamlList envList = containersList[key]['environment'];
      for (var value in envList) {
        envListStr += "-e $value ";
      }
    }

    outputStr += "\trun_opts=\"$portListStr $envListStr $volListStr\" \n";
    outputStr += "\top monitor timeout=\"30s\" interval=\"30s\" depth=\"0\" \n";
  });

  return outputStr;
}
