import 'package:compose2target/tools.dart';

String generateNetworksPart(String target, String network) {
  String outputStr = "";
  if (network.isNotEmpty) {
    switch (target) {
      case 'compose':
        outputStr += "";
        outputStr += "networks:\n";
        outputStr += "$t$network:\n";
        outputStr += "$t${t}network_name: $network\n";
        outputStr += "$t${t}driver: bridge\n";
        outputStr += "$t${t}external: true\n";
        /*outputStr += "x-podman:\n";
      outputStr += "$t${t}default_net_name_compat: true\n";*/
        break;
      case 'run':
        outputStr += "TBD\n";
        break;
      case 'kube':
        outputStr += "TBD\n";
        break;
      case 'k8s':
        outputStr += "TBD\n";
        break;
      case 'ha':
        outputStr += "TBD\n";
        break;
    }
  }
  return outputStr;
}
