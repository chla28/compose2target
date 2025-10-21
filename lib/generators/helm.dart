import 'package:yaml/yaml.dart';

/*
  Generates the HAPart internal file based on the input data. 
  Args:
    inputData (Map): A YAML map containing the services and their configurations.

  Returns:
    String: The generated HAPart internal file content as a string.
*/
String generateHelmChart(Map inputData) {
  // Get data from inputFile
  YamlMap containersList = inputData['services'];
  // if a key 'name' is present, a pod will be created and the value will be used for the POD name
  /*String name = inputData['name'] ?? "";
  String podName = "";
  if (name.isNotEmpty) {
    podName = "pod_$name.pod";
  }*/

  String outputStr = "";

  return outputStr;
}
