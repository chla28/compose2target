// To generate exe : dart compile exe bin/compose2target.dart -o compose2target
// To execute:  ./yamlConverter -i ./compose/compose_app_alm.yaml -m mappingFile.yaml -t run
//              ./yamlConverter -i ./compose/compose_app_alm.yaml -m mappingFile.yaml -t compose
//
import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart';
//import 'package:pubspec_parse/pubspec_parse.dart';
import 'package:yaml/yaml.dart';
import 'package:compose2target/generators/compose.dart';
import 'package:compose2target/generators/quadlet.dart';
import 'package:compose2target/generators/run.dart';
import 'package:compose2target/generators/ha.dart';
import 'package:compose2target/generators/helm.dart';
import 'package:compose2target/tools.dart';

const String t = "  ";
const List<String> typeList = [
  'run',
  'compose',
  'k8s',
  'mapping',
  'quadlet',
  'ha',
  'helm',
];

//final pubspec = File('pubspec.yaml').readAsStringSync();
//final parsed = Pubspec.parse(pubspec);

final String version = "0.1.9"; //parsed.version.toString();
final String appName = "compose2target"; //parsed.name;

bool workOnFolder = false;

ArgParser buildParser() {
  return ArgParser()
    ..addFlag(
      'help',
      abbr: 'h',
      negatable: false,
      help: 'Print this usage information.',
    )
    ..addFlag(
      'verbose',
      abbr: 'v',
      negatable: false,
      help: 'Show additional command output.',
    )
    ..addFlag('version', negatable: false, help: 'Print the tool version.')
    ..addFlag(
      'metrics',
      negatable: false,
      help: 'Add metrics parameters in output files',
    )
    ..addFlag(
      'nogeneric',
      negatable: false,
      help: "don't add generic output in output files",
    )
    ..addFlag('nopod', negatable: false, help: "don't add pods in output files")
    ..addFlag('dev', negatable: false, help: "Use dev mode")
    ..addOption(
      'input',
      abbr: 'i',
      mandatory: false,
      help: 'Specify YAML file to use in input',
    )
    ..addOption(
      'output',
      abbr: 'o',
      mandatory: false,
      help: 'Specify YAML file to generate',
    )
    ..addOption(
      'type',
      abbr: 't',
      mandatory: false,
      help:
          'Specify type of YAML file to generate:run|compose|k8s|mapping|quadlet|ha|helm',
    )
    ..addOption(
      'mapfile',
      abbr: 'm',
      mandatory: false,
      help: 'Specify mapping file to use',
    )
    ..addOption(
      'network',
      abbr: 'n',
      mandatory: false,
      help: 'Specify network name',
    )
    ..addOption(
      'script',
      abbr: 's',
      mandatory: false,
      help: 'Specify script name to generate',
    )
    ..addOption(
      'user',
      abbr: 'u',
      mandatory: false,
      help: 'Specify user for ha configuration',
    );
}

void printUsage(ArgParser argParser) {
  print('Usage: $appName <flags> [arguments]');
  print(argParser.usage);
}

Future<String> workOnFile(
  String sourcePathOrYaml,
  String mapFilePath,
  String outputFilePath,
  String scriptName,
  String type,
  String networkName,
  String userName,
  bool addMetrics,
  bool addGenericOutput,
  bool workOnFolder,
  bool devMode,
  bool addPodInOutput,
) async {
  String yamlContent = "";
  String mapFileContent = "";
  if (FileSystemEntity.isFileSync(sourcePathOrYaml)) {
    // Lecture du fichier yaml passé en paramètre, stockage dans une String
    yamlContent = File(sourcePathOrYaml).readAsStringSync();
  }

  Map doc;
  if (type != 'mapping' && type.isNotEmpty) {
    doc = loadYaml(yamlContent) as Map;
  } else {
    doc = {};
  }

  Map mapdoc = {};
  // Lecture du fichier de mapping
  if (mapFilePath.isNotEmpty && FileSystemEntity.isFileSync(mapFilePath)) {
    mapFileContent = File(mapFilePath).readAsStringSync();
    mapdoc = loadYaml(mapFileContent) as Map;
  }

  var outputStr = "";
  switch (type) {
    case 'compose':
      outputStr = generateComposePartInternal(
        mapdoc,
        doc,
        networkName,
        addMetrics,
        addGenericOutput,
        devMode,
        addPodInOutput,
      );
      if (!workOnFolder && outputFilePath.isNotEmpty && scriptName.isNotEmpty) {
        generateComposeScript(scriptName, outputFilePath, null);
      }
      break;
    case 'mapping':
      outputStr = fullMappingOnly(yamlContent, mapdoc);
      break;
    case 'run':
      if (mapdoc.isNotEmpty) {
        outputStr = generateRunPartInternal(
          mapdoc,
          doc,
          networkName,
          addMetrics,
          addGenericOutput,
          devMode,
        );
      } else {
        outputStr = generateRunPartInternalWithoutMapping(
          doc,
          networkName,
          addMetrics,
          addGenericOutput,
        );
      }
      break;
    //case 'rundev':
    //  outputStr += generateRunPartInternal(type, mapdoc, doc);
    //  break;
    default:
      if (mapdoc.isNotEmpty) {
        //This option is only available if mapping file is present
        if (FileSystemEntity.isFileSync("${outputFilePath}_tmp.yaml")) {
          File("${outputFilePath}_tmp.yaml").deleteSync();
        }
        if (FileSystemEntity.isFileSync(outputFilePath)) {
          File(outputFilePath).deleteSync();
        }
        String outputStrTemp = generateComposePartInternal(
          mapdoc,
          doc,
          networkName,
          addMetrics,
          addGenericOutput,
          devMode,
          addPodInOutput,
        );
        // Generate compose file as intermediate file
        await generateOutputFile("${outputFilePath}_tmp.yaml", outputStrTemp);

        // Now we use the generated compose file as source of quadlet part
        String yamlContentTemp = "";
        // Lecture du fichier yaml passé en paramètre, stockage dans une String
        yamlContentTemp = File("${outputFilePath}_tmp.yaml").readAsStringSync();
        Map docTemp = loadYaml(yamlContentTemp) as Map;
        switch (type) {
          case 'k8s':
            //outputStr += generateK8SPartInternal(docTemp);
            break;
          case 'helm':
            // IMPORTANT: HelmChart will be a tar file with a tree inside containing the full helm chart
            outputStr += generateHelmChart(docTemp);
            break;
          case 'quadlet':
            outputStr += generateQuadletPartInternal(docTemp);
            break;
          case 'ha':
            outputStr += generateHAPartInternal(docTemp, userName);
            if (FileSystemEntity.isFileSync("${outputFilePath}_tmp.yaml")) {
              File("${outputFilePath}_tmp.yaml").deleteSync();
            }
            break;
        }
      } else {
        // mapdoc is empty, the input file is supposed to be a valid compose file (no mapping will be done)
        switch (type) {
          case 'k8s':
            //outputStr += generateK8SPartInternal(doc);
            break;
          case 'helm':
            outputStr += generateHelmChart(doc);
            break;
          case 'quadlet':
            outputStr += generateQuadletPartInternal(doc);
            break;
          case 'ha':
            outputStr += generateHAPartInternal(doc, userName);
            break;
        }
      }
  }
  if (outputFilePath.isEmpty) {
    print(outputStr);
  } else {
    generateOutputFile(outputFilePath, outputStr);
    Future.wait(
      [generateOutputFile(outputFilePath, outputStr)],
    ); //, Future.delayed(Duration(seconds: 2), () => print('Final file created'))]);
  }
  return outputStr;
}

void mainFunction(List<String> arguments) async {
  String sourcePathOrYaml = "";
  String mapFilePath = "";
  String outputFilePath = "";
  String type = "";
  String networkName = "";
  String scriptName = "";
  String userName = "";
  bool addMetrics = false;
  bool addGenericOutput = true;
  bool devMode = false;
  bool addPodInOutput = true;

  final ArgParser argParser = buildParser();
  try {
    final ArgResults results = argParser.parse(arguments);
    bool verbose = false;

    // Process the parsed arguments.
    if (results.wasParsed('help')) {
      printUsage(argParser);
      exit(1);
    }
    if (results.wasParsed('version')) {
      print("$appName : $version");
      exit(1);
    }
    if (results.wasParsed('nogeneric')) {
      addGenericOutput = false;
    }
    if (results.wasParsed('nopod')) {
      addPodInOutput = false;
    }

    if (results.wasParsed('metrics')) {
      addMetrics = true;
    }
    if (results.wasParsed('verbose')) {
      verbose = true;
    }
    if (results.wasParsed('dev')) {
      devMode = true;
    }

    // fichier "compose"
    if (results.wasParsed('input')) {
      sourcePathOrYaml = results.option('input')!;
      if (Directory(sourcePathOrYaml).existsSync() == true) {
        workOnFolder = true;
      } else if (File(sourcePathOrYaml).existsSync() == false) {
        print(" File '$sourcePathOrYaml' doesn't exists !");
        exit(1);
      } else {
        workOnFolder = false;
      }
    }

    // WARNING: if workOnFolder is true, outputFilePath must be a[n existing] folder
    if (results.wasParsed('output')) {
      outputFilePath = results.option('output')!;
    }
    if (results.wasParsed('type')) {
      type = results.option('type')!;
      if (typeList.contains(type) == false) {
        print("Type value for -t option is unknowed !");
        exit(1);
      }
    }
    // fichier de mapping pour les ports, les volumes, ...
    if (results.wasParsed('mapfile')) {
      mapFilePath = results.option('mapfile')!;
      if (File(mapFilePath).existsSync() == false) {
        print(" File '$mapFilePath' doesn't exists !");
        exit(1);
      }
    }
    if (results.wasParsed('network')) {
      networkName = results.option('network')!;
    }
    if (results.wasParsed('script')) {
      scriptName = results.option('script')!;
    }
    if (results.wasParsed('user')) {
      userName = results.option('user')!;
    }

    // Act on the arguments provided.
    //print('Positional arguments: ${results.rest}');
    if (verbose) {
      print('[VERBOSE] All arguments: ${results.arguments}');
    }
  } on FormatException catch (e) {
    // Print usage information if an invalid argument was provided.
    print(e.message);
    print('');
    printUsage(argParser);
  }

  /*if (sourcePathOrYaml.isEmpty | mapFilePath.isEmpty | type.isEmpty) {
    printUsage(argParser);
    exit(1);
  }*/

  if (workOnFolder) {
    var dir = Directory(sourcePathOrYaml);
    List<String> fileList = [];
    List<FileSystemEntity> entities = await dir.list().toList();
    Iterable<File> files = entities.whereType<File>();
    for (int i = 0; i < files.length; i++) {
      String filename = basename(files.elementAt(i).path);
      fileList.add(filename);
      //print("filename:${files.elementAt(i).path}");
      workOnFile(
        files.elementAt(i).path,
        mapFilePath,
        '$outputFilePath/$filename',
        scriptName,
        type,
        networkName,
        userName,
        addMetrics,
        addGenericOutput,
        true,
        devMode,
        addPodInOutput,
      );
    }
    if (outputFilePath.isNotEmpty && scriptName.isNotEmpty) {
      generateComposeScript(scriptName, outputFilePath, fileList);
    }
  } else {
    workOnFile(
      sourcePathOrYaml,
      mapFilePath,
      outputFilePath,
      scriptName,
      type,
      networkName,
      userName,
      addMetrics,
      addGenericOutput,
      false,
      devMode,
      addPodInOutput,
    );
  }
}

void main(List<String> arguments) async {
  mainFunction(arguments);
}
