import 'dart:io';

const _minimumApplicationCoverage = 65.0;
const _minimumCriticalServiceCoverage = 85.0;

const _criticalFiles = <String>{
  'lib/screens/home_screen.dart',
  'lib/screens/weekly_summary_screen.dart',
  'lib/services/calorie_deficit_service.dart',
  'lib/services/data_transfer_service.dart',
  'lib/services/day_summary_service.dart',
  'lib/services/entries_repository.dart',
  'lib/services/food_library_service.dart',
  'lib/services/metabolic_profile_history_service.dart',
  'lib/services/nutrition_target_service.dart',
  'lib/services/openai_service.dart',
  'lib/services/update_coordinator.dart',
  'lib/services/update_service.dart',
  'lib/services/weekly_deficit_calculator.dart',
};

const _strictCoverageFiles = <String>{
  'lib/services/calorie_deficit_service.dart',
  'lib/services/data_transfer_service.dart',
  'lib/services/macro_ratio_preset_catalog.dart',
  'lib/services/nutrition_target_service.dart',
  'lib/services/openai_service.dart',
  'lib/services/update_service.dart',
  'lib/services/weekly_deficit_calculator.dart',
  'lib/utils/app_date_utils.dart',
};

void main(List<String> arguments) {
  final reportPath =
      arguments.isEmpty ? 'coverage/lcov.info' : arguments.single;
  final report = File(reportPath);
  if (!report.existsSync()) {
    stderr.writeln('Coverage report not found: $reportPath');
    exitCode = 1;
    return;
  }

  final coverage = _parseLcov(report.readAsLinesSync());
  final applicationCoverage = Map.of(coverage)
    ..removeWhere((path, _) => _isGeneratedLocalization(path));

  final failures = <String>[];
  final totalLines = applicationCoverage.values.fold<int>(
    0,
    (sum, file) => sum + file.totalLines,
  );
  final coveredLines = applicationCoverage.values.fold<int>(
    0,
    (sum, file) => sum + file.coveredLines,
  );
  final totalPercentage = _percentage(coveredLines, totalLines);

  stdout.writeln(
    'Application coverage: ${totalPercentage.toStringAsFixed(2)}% '
    '($coveredLines/$totalLines lines)',
  );
  if (totalPercentage < _minimumApplicationCoverage) {
    failures.add(
      'Application coverage is below '
      '${_minimumApplicationCoverage.toStringAsFixed(0)}%.',
    );
  }

  for (final path in _criticalFiles.toList()..sort()) {
    final file = applicationCoverage[path];
    if (file == null || file.totalLines == 0) {
      failures.add('Critical production file is absent from coverage: $path');
    }
  }

  for (final path in _strictCoverageFiles.toList()..sort()) {
    final file = applicationCoverage[path];
    if (file == null || file.totalLines == 0) {
      failures.add('Strict-coverage file is absent from coverage: $path');
      continue;
    }
    final percentage = _percentage(file.coveredLines, file.totalLines);
    stdout.writeln(
      'Strict coverage: ${percentage.toStringAsFixed(2)}% '
      '(${file.coveredLines}/${file.totalLines}) $path',
    );
    if (percentage < _minimumCriticalServiceCoverage) {
      failures.add(
        '$path coverage is below '
        '${_minimumCriticalServiceCoverage.toStringAsFixed(0)}%.',
      );
    }
  }

  if (failures.isEmpty) {
    stdout.writeln('Coverage policy passed.');
    return;
  }

  stderr.writeln('Coverage policy failed:');
  for (final failure in failures) {
    stderr.writeln('- $failure');
  }
  exitCode = 1;
}

Map<String, _FileCoverage> _parseLcov(List<String> lines) {
  final result = <String, _FileCoverage>{};
  String? currentPath;

  for (final line in lines) {
    if (line.startsWith('SF:')) {
      currentPath = _normalizePath(line.substring(3));
      continue;
    }
    if (!line.startsWith('DA:') || currentPath == null) {
      continue;
    }

    final values = line.substring(3).split(',');
    if (values.length < 2) {
      continue;
    }
    final lineNumber = int.tryParse(values[0]);
    final hitCount = int.tryParse(values[1]);
    if (lineNumber == null || hitCount == null) {
      continue;
    }

    final file = result.putIfAbsent(currentPath, _FileCoverage.new);
    file.hits.update(
      lineNumber,
      (existing) => existing + hitCount,
      ifAbsent: () => hitCount,
    );
  }

  result.removeWhere((path, _) => !path.startsWith('lib/'));
  return result;
}

String _normalizePath(String path) {
  var normalized = path.replaceAll('\\', '/');
  if (normalized.startsWith('./')) {
    normalized = normalized.substring(2);
  }
  final libMarker = normalized.lastIndexOf('/lib/');
  if (libMarker >= 0) {
    normalized = normalized.substring(libMarker + 1);
  }
  return normalized;
}

bool _isGeneratedLocalization(String path) {
  return path.startsWith('lib/l10n/app_localizations') &&
      path.endsWith('.dart');
}

double _percentage(int covered, int total) {
  return total == 0 ? 0 : covered * 100 / total;
}

class _FileCoverage {
  final hits = <int, int>{};

  int get totalLines => hits.length;

  int get coveredLines => hits.values.where((hits) => hits > 0).length;
}
