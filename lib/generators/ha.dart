import 'package:compose2target/tools.dart';
import 'package:yaml/yaml.dart';

/*
  Generates the HAPart internal file based on the input data. 
  Args:
    inputData (Map): A YAML map containing the services and their configurations.

  Returns:
    String: The generated HAPart internal file content as a string.
*/
String generateHAPartInternal(Map inputData, String userName) {
  // Get data from inputFile
  YamlMap containersList = inputData['services'];
  // if a key 'name' is present, a pod will be created and the value will be used for the POD name
  /*String name = inputData['name'] ?? "";
  String podName = "";
  if (name.isNotEmpty) {
    podName = "pod_$name.pod";
  }*/

  String outputStr = "";

  // Each key 'services' present is associated to a container
  containersList.forEach((key, value) {
    String containerName = key;
    outputStr +=
        "pcs resource create $containerName ocf:other:podmanrootless user=$userName \\\n";
    outputStr +=
        "\timage=\"${containersList[containerName]['image']}\" name=\"$containerName\" \\\n";
    outputStr += "\tallow_pull=false reuse=false \\\n";

    //String tmpVolListOutputStr = "";
    String volListStr = "";
    if (containersList[key]['volumes'] != null) {
      YamlList mountList = containersList[key]['volumes'];
      for (var value in mountList) {
        if (value is String) {
          final (localStr, mountStrCont) = extractStrings(value);
          String tmp = checkSpecialVolumes(mountStrCont, true);
          volListStr += "-v $localStr:$tmp ";
          //tmpVolListOutputStr += localStr;
        } else {
          String tmp = checkSpecialVolumes(value.values.first, true);
          volListStr += "-v ${value.keys.first}:$tmp ";
          //tmpVolListOutputStr += "${value.keys.first}";
        }
        //tmpVolListOutputStr += ",";
      }
      // mount_points is not needed
      //outputStr += "\tmount_points=\"$tmpVolListOutputStr\" \\\n";
    }

    var cmd2 = containersList[containerName]['command'];
    if (cmd2 != null) {
      String cmd = "";
      if (cmd2 is String) {
        outputStr += "\trun_cmd=\"$cmd $cmd2\"\\\n";
      } else if (cmd2 is YamlList) {
        String cmdStr = "";
        for (var value in cmd2) {
          cmdStr += " $value";
        }
        outputStr += "\trun_cmd=\"$cmd $cmdStr\"\\\n";
      }
    }
    String portListStr = "";
    if (containersList[key]['ports'] != null) {
      YamlList portsList = containersList[key]['ports'];
      for (var value in portsList) {
        if (value is String) {
          var idx = value.indexOf(":");
          if (idx == -1) {
            portListStr += "-p $value ";
          } else {
            String portStr = value.substring(0, idx);
            String portValue = value.substring(idx + 1);
            portListStr += "-p $portStr:$portValue ";
          }
        } else if (value is int) {
          portListStr += "-p $value ";
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
      envListStr = envListStr.replaceAll(RegExp(r'"'), '\\"');
    }

    String envSecuListStr = "";
    YamlList? securityOptList = containersList[key]['security_opt'];
    if (securityOptList != null) {
      for (var value in securityOptList) {
        if (value is String && value.startsWith("label=")) {
          envSecuListStr += "--security-opt $value ";
        }
      }
      envSecuListStr = envSecuListStr.replaceAll(RegExp(r'"'), '\\"');
    }

    String envLogStr =
        "--log-driver k8s-file --log-opt path=/var/asntraces/$containerName.log --log-opt max-size=100m";

    outputStr +=
        "\trun_opts=\"$portListStr $envLogStr $envListStr $volListStr $envSecuListStr\" \\\n";

    String annotationsListStr = "";
    if (containersList[key]['annotations'] != null) {
      YamlList annotationsList = containersList[key]['annotations'];
      for (var value in annotationsList) {
        if (value is String) {
          String optionsStr = "";
          var idx = value.indexOf("=");
          if (value.startsWith("c2t.ha.start=") && idx != -1) {
            optionsStr = value.substring(idx + 2, value.length - 1);
            annotationsListStr += "\top start $optionsStr \\\n";
          }
          if (value.startsWith("c2t.ha.stop=") && idx != -1) {
            optionsStr = value.substring(idx + 2, value.length - 1);
            annotationsListStr += "\top stop $optionsStr \\\n";
          }
          if (value.startsWith("c2t.ha.monitor=") && idx != -1) {
            optionsStr = value.substring(idx + 2, value.length - 1);
            annotationsListStr += "\top monitor $optionsStr \\\n";
          }
          if (value.startsWith("c2t.ha.monitorcmd=") && idx != -1) {
            optionsStr = value.substring(idx + 2, value.length - 1);
            annotationsListStr += "\tmonitor_cmd=$optionsStr \\\n";
          }
        }
      }
      //annotationsListStr = annotationsListStr.replaceAll(RegExp(r'"'), '\\"');
    }
    outputStr += annotationsListStr;
    // Replace last "\\\n" in the outputStr vu "\n"
    if (outputStr.length > 2) {
      outputStr = "${outputStr.substring(0, outputStr.length - 2)}\n";
    }
    //outputStr += "\top monitor timeout=\"30s\" interval=\"30s\" start-delay=\"30s\" \n";
  });

  return outputStr;
}
