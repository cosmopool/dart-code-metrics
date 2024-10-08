import 'package:glob/glob.dart';

/// Represents converted unused code config which contains parsed entities.
class ClassUtilizationAnalysisConfig {
  final Iterable<Glob> globalExcludes;
  final Iterable<Glob> analyzerExcludedPatterns;
  final bool isMonorepo;

  const ClassUtilizationAnalysisConfig(
    this.globalExcludes,
    this.analyzerExcludedPatterns, {
    required this.isMonorepo,
  });

  Map<String, Object?> toJson() => {
        'global-excludes': globalExcludes.map((glob) => glob.pattern).toList(),
        'analyzer-excluded-patterns':
            analyzerExcludedPatterns.map((glob) => glob.pattern).toList(),
        'is-monorepo': isMonorepo,
      };
}

