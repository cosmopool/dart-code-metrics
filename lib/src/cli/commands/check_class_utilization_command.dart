// ignore_for_file: public_member_api_docs

import 'dart:io';

import '../../analyzers/class_utilization_analyzer/class_utilization_analyzer.dart';
import '../../config_builder/config_builder.dart';
import '../../logger/logger.dart';
import '../models/flag_names.dart';
import 'base_command.dart';

class CheckClassUtilizationCommand extends BaseCommand {
  final ClassUtilizationAnalyzer _analyzer;

  final Logger _logger;

  @override
  String get name => 'check-class-utilization';

  @override
  String get description => 'Check class utilization in *.dart files.';

  @override
  String get invocation =>
      '${runner?.executableName} $name [arguments] <directories>';

  CheckClassUtilizationCommand(this._logger)
      : _analyzer = ClassUtilizationAnalyzer(_logger) {
    _addFlags();
  }

  @override
  Future<void> runCommand() async {
    _logger
      ..isSilent = isNoCongratulate
      ..isVerbose = isVerbose
      ..progress.start('Checking class utilization');

    final rootFolder = argResults[FlagNames.rootFolder] as String;
    final folders = argResults.rest;
    final excludePath = argResults[FlagNames.exclude] as String;
    // final reporterName = argResults[FlagNames.reporter] as String;
    final isMonorepo = argResults[FlagNames.isMonorepo] as bool;
    final shouldPrintConfig = argResults[FlagNames.printConfig] as bool;

    final config = ConfigBuilder.getClassUtilizationConfigFromArgs(
      [excludePath],
      isMonorepo: isMonorepo,
      shouldPrintConfig: shouldPrintConfig,
    );

    final classUtilizationResult = await _analyzer.runCliAnalysis(
      folders,
      rootFolder,
      config,
      sdkPath: findSdkPath(),
    );

    _logger.progress.complete('Analysis is completed. Preparing the results:');

    // await _analyzer
    //     .getReporter(
    //       name: reporterName,
    //       output: stdout,
    //     )
    //     ?.report(
    //       unusedCodeResult,
    //       additionalParams:
    //           UnusedCodeReportParams(congratulate: !isNoCongratulate),
    //     );

    for (final map in classUtilizationResult.entries) {
      print('${map.key} : ${map.value}');
    }

    if (classUtilizationResult.isNotEmpty &&
        (argResults[FlagNames.fatalOnUnused] as bool)) {
      exit(1);
    }
  }

  void _addFlags() {
    _usesReporterOption();
    addCommonFlags();
    _usesIsMonorepoOption();
    _usesExitOption();
  }

  void _usesReporterOption() {
    argParser
      ..addSeparator('')
      ..addOption(
        FlagNames.reporter,
        abbr: 'r',
        help: 'The format of the output of the analysis.',
        valueHelp: FlagNames.consoleReporter,
        allowed: [
          FlagNames.consoleReporter,
          FlagNames.jsonReporter,
        ],
        defaultsTo: FlagNames.consoleReporter,
      );
  }

  void _usesIsMonorepoOption() {
    argParser
      ..addSeparator('')
      ..addFlag(
        FlagNames.isMonorepo,
        help: 'Treat all exported code as unused by default.',
      );
  }

  void _usesExitOption() {
    argParser
      ..addSeparator('')
      ..addFlag(
        FlagNames.fatalOnUnused,
        help: 'Treat find unused code as fatal.',
        defaultsTo: true,
      );
  }
}
