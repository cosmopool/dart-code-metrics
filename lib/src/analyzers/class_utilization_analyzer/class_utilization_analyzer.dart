import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/element/element.dart';

import '../../config_builder/config_builder.dart';
import '../../config_builder/models/analysis_options.dart';
import '../../logger/logger.dart';
import '../../reporters/models/reporter.dart';
import '../../utils/analyzer_utils.dart';
import '../../utils/suppression.dart';
import '../unused_code_analyzer/models/file_elements_usage.dart';
import '../unused_code_analyzer/used_code_visitor.dart';
import 'class_utilization_analysis_config.dart';
import 'class_utilization_config.dart';
import 'models/unused_code_file_report.dart';
import 'public_code_visitor.dart';
import 'reporters/reporter_factory.dart';
import 'reporters/unused_code_report_params.dart';

typedef ClassUtilization = Map<String, int>;

/// The analyzer responsible for collecting the number of dependencies of a class.
class ClassUtilizationAnalyzer {
  static const _ignoreName = 'unused-code';

  final Logger? _logger;

  const ClassUtilizationAnalyzer([this._logger]);

  /// Returns a reporter for the given [name]. Use the reporter
  /// to convert analysis reports to console, JSON or other supported format.
  Reporter<UnusedCodeFileReport, ClassUtilizationReportParams>? getReporter({
    required String name,
    required IOSink output,
  }) =>
      reporter(
        name: name,
        output: output,
      );

  /// Returns a list of unused code reports
  /// for analyzing all files in the given [folders].
  /// The analysis is configured with the [config].
  Future<ClassUtilization> runCliAnalysis(
    Iterable<String> folders,
    String rootFolder,
    ClassUtilizationConfig config, {
    String? sdkPath,
  }) async {
    final collection =
        createAnalysisContextCollection(folders, rootFolder, sdkPath);

    final codeUsages = FileElementsUsage();
    final publicCode = <String, Set<Element>>{};

    for (final context in collection.contexts) {
      final analysisConfig = _getAnalysisConfig(context, rootFolder, config);

      if (config.shouldPrintConfig) {
        _logger?.printConfig(analysisConfig.toJson());
      }

      final filePaths = getFilePaths(
        folders,
        context,
        rootFolder,
        analysisConfig.globalExcludes,
      );

      final analyzedFiles =
          filePaths.intersection(context.contextRoot.analyzedFiles().toSet());

      final contextsLength = collection.contexts.length;
      final filesLength = analyzedFiles.length;
      final updateMessage = contextsLength == 1
          ? 'Checking code utilization for $filesLength file(s)'
          : 'Checking code utilization for ${collection.contexts.indexOf(context) + 1}/$contextsLength contexts with $filesLength file(s)';
      _logger?.progress.update(updateMessage);

      for (final filePath in analyzedFiles) {
        _logger?.infoVerbose('Analyzing $filePath');

        final unit = await context.currentSession.getResolvedUnit(filePath);

        final codeUsage = _analyzeFileCodeUsages(unit);
        if (codeUsage != null) {
          codeUsages.merge(codeUsage);
        }

        if (!analysisConfig.analyzerExcludedPatterns
            .any((pattern) => pattern.matches(filePath))) {
          publicCode[filePath] = _analyzeFilePublicCode(unit);
        }
      }
    }

    if (!config.isMonorepo) {
      _logger?.infoVerbose(
        'Removing globally exported files with code usages from the analysis: ${codeUsages.exports.length}',
      );
      codeUsages.exports.forEach(publicCode.remove);
    }

    return _getReports(codeUsages, publicCode);
  }

  ClassUtilizationAnalysisConfig _getAnalysisConfig(
    AnalysisContext context,
    String rootFolder,
    ClassUtilizationConfig config,
  ) {
    final analysisOptions = analysisOptionsFromContext(context) ??
        analysisOptionsFromFilePath(rootFolder, context);

    final contextConfig =
        ConfigBuilder.getClassUtilizationConfigFromOption(analysisOptions)
            .merge(config);

    return ConfigBuilder.getClassUtilizationConfig(contextConfig, rootFolder);
  }

  FileElementsUsage? _analyzeFileCodeUsages(SomeResolvedUnitResult unit) {
    if (unit is ResolvedUnitResult) {
      final visitor = UsedCodeVisitor();
      unit.unit.visitChildren(visitor);

      return visitor.fileElementsUsage;
    }

    return null;
  }

  Set<Element> _analyzeFilePublicCode(SomeResolvedUnitResult unit) {
    if (unit is ResolvedUnitResult) {
      final suppression = Suppression(unit.content, unit.lineInfo);
      final isSuppressed = suppression.isSuppressed(_ignoreName);
      if (isSuppressed) {
        return {};
      }

      final visitor = PublicCodeVisitor(suppression, _ignoreName);
      unit.unit.visitChildren(visitor);

      return visitor.topLevelElements;
    }

    return {};
  }

  ClassUtilization _getReports(
    FileElementsUsage codeUsages,
    Map<String, Set<Element>> publicCodeElements,
  ) {
    final utilization = <String, int>{};

    publicCodeElements.forEach((path, elements) {
      for (final element in elements) {
        assert(element.name != null, 'an element must have an name');
        if (element.kind != ElementKind.CLASS) continue;

        final className = element.name!;
        final timesUsed = utilization[className];
        utilization[className] = (timesUsed ?? 0) + 1;
      }
    });

    return utilization;
  }
}
