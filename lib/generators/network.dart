import 'package:compose2target/tools.dart';

String generateNetworksPart(String network) {
  String outputStr = "";
  if (network.isNotEmpty && network != "podman") {
    outputStr += "";
    outputStr += "networks:\n";
    outputStr += "$t$network:\n";
    outputStr += "$t${t}name: $network\n";
    outputStr += "$t${t}driver: bridge\n";
    outputStr += "$t${t}external: true\n";
    /*outputStr += "x-podman:\n";
      outputStr += "$t${t}default_net_name_compat: true\n";*/ // to get compatibility of default network names with docker compose
  } /* else {
    outputStr += "networks:\n";
    outputStr += "${t}- podman\n";
  }*/
  return outputStr;
}
