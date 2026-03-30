import 'dart:io';

import 'package:dojjo/src/platform.dart';
import 'package:dojjo/src/util/extensions.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:path/path.dart' as p;
import 'package:toml/toml.dart';

part 'config.freezed.dart';
part 'config.g.dart';

@freezed
sealed class MergeConfig with _$MergeConfig {
  const factory MergeConfig({
    @Default(true) bool squash,
    @Default(true) bool rebase,
    @Default(true) bool remove,
    @Default(true) bool verify,
    @Default(false) bool push,
  }) = _MergeConfig;

  factory MergeConfig.fromJson(Map<String, Object?> json) => _$MergeConfigFromJson(json);
}

@freezed
sealed class ListConfig with _$ListConfig {
  const factory ListConfig({@Default('') String url}) = _ListConfig;

  factory ListConfig.fromJson(Map<String, Object?> json) => _$ListConfigFromJson(json);
}

/// A single hook command with a name.
@freezed
sealed class HookEntry with _$HookEntry {
  const factory HookEntry({required String name, required String command}) = _HookEntry;
}

/// A pipeline step: a list of commands that run in parallel.
/// A hook pipeline is a list of steps that run sequentially.
/// Within each step, all commands run in parallel.
typedef HookStep = List<HookEntry>;
typedef HookPipeline = List<HookStep>;

/// Map from hook type (e.g. "pre-merge") to its pipeline.
typedef HookMap = Map<String, HookPipeline>;

@freezed
sealed class CopyIgnoredConfig with _$CopyIgnoredConfig {
  const factory CopyIgnoredConfig({@Default(<String>[]) List<String> exclude}) = _CopyIgnoredConfig;

  factory CopyIgnoredConfig.fromJson(Map<String, Object?> json) => _$CopyIgnoredConfigFromJson(json);
}

@freezed
sealed class IgnoreWorktrunkHooks with _$IgnoreWorktrunkHooks {
  const factory IgnoreWorktrunkHooks.none() = IgnoreWorktrunkHooksNone;
  const factory IgnoreWorktrunkHooks.all() = IgnoreWorktrunkHooksAll;
  const factory IgnoreWorktrunkHooks.types(List<String> types) = IgnoreWorktrunkHooksTypes;
}

Map<String, String> _aliasesFromJson(Map<String, Object?>? json) =>
    json?.map((key, value) => MapEntry(key, value as String? ?? '')) ?? {};

@freezed
sealed class Config with _$Config {
  @JsonSerializable(fieldRename: FieldRename.kebab)
  const factory Config({
    @Default(true) bool createBookmark,
    @Default('') String workspacePath,
    @Default(MergeConfig()) MergeConfig merge,
    @Default(ListConfig()) ListConfig list,
    @Default(CopyIgnoredConfig()) CopyIgnoredConfig copyIgnored,
    @Default(<String, String>{}) @JsonKey(fromJson: _aliasesFromJson) Map<String, String> aliases,
    @Default(<String, HookPipeline>{}) @JsonKey(includeFromJson: false, includeToJson: false) HookMap hooks,
    @Default(IgnoreWorktrunkHooks.none())
    @JsonKey(includeFromJson: false, includeToJson: false)
    IgnoreWorktrunkHooks ignoreWorktrunkHooks,
  }) = _Config;

  factory Config.fromJson(Map<String, Object?> json) => _$ConfigFromJson(json);
}

/// Sources for config values, tracked for `config show`.
@freezed
sealed class ConfigWithSource with _$ConfigWithSource {
  const factory ConfigWithSource({required Config config, @Default(<String>[]) List<String> sources}) =
      _ConfigWithSource;
}

// HookStep _parseHookStep(Map<String, Object?> map) =>
//     map.entries.map((e) => HookEntry(name: e.key, command: e.value as String? ?? '')).toList();

HookStep _parseHookStep(Map<String, Object?> map) => [
  for (final MapEntry(:key, :value) in map.entries) HookEntry(name: key, command: value as String? ?? ''),
];

HookMap _parseHooks(Map<String, Object?> hooksMap) => {
  for (final MapEntry(key: hookType, :value) in hooksMap.entries)
    if (value is String)
      // Simple form: post-start = "npm install"
      // One step with one command.
      hookType: [
        [HookEntry(name: hookType, command: value)],
      ]
    else if (value is List)
      // Pipeline form: post-start = [{ install = "npm install" }, { build = "npm run build" }]
      // Each list element is a step; commands within a step run in parallel.
      hookType: value.whereType<Map<String, Object?>>().map(_parseHookStep).toList()
    else if (value is Map<String, Object?>)
      // Named form: [hooks.pre-merge] test = "cargo test"
      // One step with parallel commands.
      hookType: [_parseHookStep(value)],
};

/// Preprocess a TOML string into a map ready for [Config.fromJson].
Map<String, Object?> _toTomlMap(String content) {
  final doc = TomlDocument.parse(content).toMap();

  // Flatten step.copy-ignored to top level for Config.fromJson.
  final stepMap = doc['step'];
  if (stepMap is Map<String, Object?>) {
    doc['copy-ignored'] = stepMap['copy-ignored'];
  }

  // Accept worktrunk's worktree-path as fallback.
  if (doc.containsKey('worktree-path') && !doc.containsKey('workspace-path')) {
    doc['workspace-path'] = doc['worktree-path'];
  }

  return doc;
}

/// Parse a preprocessed TOML map into a [Config].
Config _mapToConfig(Map<String, Object?> map) {
  final config = Config.fromJson(map);
  final hooksMap = map['hooks'];
  return config.copyWith(
    hooks: hooksMap is Map<String, Object?> ? _parseHooks(hooksMap) : const {},
    ignoreWorktrunkHooks: _parseIgnoreWorktrunkHooks(map['ignore-worktrunk-hooks']),
  );
}

Config _parseToml(String content) => _mapToConfig(_toTomlMap(content));

IgnoreWorktrunkHooks _parseIgnoreWorktrunkHooks(Object? value) {
  if (value is bool && value) return const IgnoreWorktrunkHooks.all();
  if (value is List) return IgnoreWorktrunkHooks.types(value.cast<String>());
  return const IgnoreWorktrunkHooks.none();
}

HookMap _parseHooksFromMap(Map<String, Object?> map) {
  final hooksMap = map['hooks'];
  return hooksMap is Map<String, Object?> ? _parseHooks(hooksMap) : const {};
}

/// Deep-merge two maps. Nested maps are merged recursively;
/// other values in [override] replace those in [base].
Map<String, Object?> _deepMerge(Map<String, Object?> base, Map<String, Object?> override) {
  final result = Map<String, Object?>.of(base);
  for (final MapEntry(:key, value: overrideValue) in override.entries) {
    final baseValue = result[key];
    result[key] = baseValue is Map<String, Object?> && overrideValue is Map<String, Object?>
        ? _deepMerge(baseValue, overrideValue)
        : overrideValue;
  }
  return result;
}

HookMap _mergeHooks(HookMap base, HookMap override) {
  final result = {...base};
  for (final entry in override.entries) {
    result.update(entry.key, (existing) => [...existing, ...entry.value], ifAbsent: () => entry.value);
  }
  return result;
}

Config _applyEnvOverrides(Config config) {
  final env = Platform.environment;
  return config.copyWith(
    workspacePath: env['DOJJO_WORKSPACE_PATH'] ?? config.workspacePath,
    merge: config.merge.copyWith(
      squash: _envBool(env, 'DOJJO_MERGE__SQUASH') ?? config.merge.squash,
      rebase: _envBool(env, 'DOJJO_MERGE__REBASE') ?? config.merge.rebase,
      remove: _envBool(env, 'DOJJO_MERGE__REMOVE') ?? config.merge.remove,
      verify: _envBool(env, 'DOJJO_MERGE__VERIFY') ?? config.merge.verify,
      push: _envBool(env, 'DOJJO_MERGE__PUSH') ?? config.merge.push,
    ),
  );
}

bool? _envBool(Map<String, String> env, String key) => env[key]?.toLowerCase().let((it) => it == 'true');

Future<Map<String, Object?>?> _tryLoadMap(String path) async {
  final file = File(path);
  if (!await file.exists()) return null;
  return _toTomlMap(await file.readAsString());
}

HookMap _filterWorktrunkHooks(HookMap hooks, IgnoreWorktrunkHooks ignore) => switch (ignore) {
  IgnoreWorktrunkHooksNone() => hooks,
  IgnoreWorktrunkHooksAll() => {},
  IgnoreWorktrunkHooksTypes(:final types) => _filterByPatterns(hooks, types),
};

HookMap _filterByPatterns(HookMap hooks, List<String> patterns) {
  // Split patterns into whole-type ("pre-merge") and named ("pre-merge.lint").
  final wholeTypes = <String>{};
  final namedEntries = <String, Set<String>>{};
  for (final pattern in patterns) {
    final dot = pattern.indexOf('.');
    if (dot == -1) {
      wholeTypes.add(pattern);
    } else {
      final type = pattern.substring(0, dot);
      final name = pattern.substring(dot + 1);
      namedEntries.putIfAbsent(type, () => {}).add(name);
    }
  }

  final result = <String, HookPipeline>{};
  for (final MapEntry(:key, :value) in hooks.entries) {
    if (wholeTypes.contains(key)) continue;

    final ignoredNames = namedEntries[key];
    if (ignoredNames == null) {
      result[key] = value;
      continue;
    }

    // Filter out specific named entries from each step.
    final filteredPipeline = <HookStep>[];
    for (final step in value) {
      final filteredStep = step.where((e) => !ignoredNames.contains(e.name)).toList();
      if (filteredStep.isNotEmpty) {
        filteredPipeline.add(filteredStep);
      }
    }
    if (filteredPipeline.isNotEmpty) {
      result[key] = filteredPipeline;
    }
  }
  return result;
}

/// Load config from all sources, merged in precedence order.
/// Returns the effective config and the list of files that were loaded.
///
/// Scalar config fields are deep-merged at the TOML map level so that
/// only explicitly-set keys override earlier values. Hooks use append
/// semantics (later files add to the pipeline, not replace).
Future<ConfigWithSource> loadConfig({String? projectRoot}) async {
  final home = homeDirectory;
  final root = projectRoot ?? Directory.current.path;

  final wtPaths = [
    (p.join(home, '.config', 'worktrunk', 'config.toml'), 'worktrunk user'),
    (p.join(root, '.config', 'wt.toml'), 'worktrunk project'),
  ];
  final djoPaths = [
    (p.join(home, '.config', 'dojjo', 'config.toml'), 'dojjo user'),
    (p.join(root, 'dojjo.toml'), 'dojjo project'),
    (p.join(root, 'dojjo.local.toml'), 'dojjo project local'),
  ];

  final sources = <String>[];

  // Load worktrunk configs — deep-merge maps, append hooks.
  var wtMap = <String, Object?>{};
  var wtHooks = const <String, HookPipeline>{};
  for (final (path, label) in wtPaths) {
    final map = await _tryLoadMap(path);
    if (map != null) {
      wtMap = _deepMerge(wtMap, map);
      wtHooks = _mergeHooks(wtHooks, _parseHooksFromMap(map));
      sources.add('$label: $path');
    }
  }

  // Load dojjo configs — deep-merge maps, append hooks.
  var djoMap = <String, Object?>{};
  var djoHooks = const <String, HookPipeline>{};
  for (final (path, label) in djoPaths) {
    final map = await _tryLoadMap(path);
    if (map != null) {
      djoMap = _deepMerge(djoMap, map);
      djoHooks = _mergeHooks(djoHooks, _parseHooksFromMap(map));
      sources.add('$label: $path');
    }
  }

  // Filter worktrunk hooks based on dojjo ignore settings.
  final filteredWtHooks = _filterWorktrunkHooks(wtHooks, _parseIgnoreWorktrunkHooks(djoMap['ignore-worktrunk-hooks']));

  // Deep-merge scalar config (dojjo overrides worktrunk).
  final mergedMap = _deepMerge(wtMap, djoMap);
  final config = _mapToConfig(
    mergedMap,
  ).copyWith(hooks: _mergeHooks(filteredWtHooks, djoHooks)).let(_applyEnvOverrides);

  return ConfigWithSource(config: config, sources: sources);
}

// Exposed for testing.
Config parseToml(String content) => _parseToml(content);
Config mergeToml(String base, String override) {
  final baseMap = _toTomlMap(base);
  final overrideMap = _toTomlMap(override);
  final mergedMap = _deepMerge(baseMap, overrideMap);
  return _mapToConfig(
    mergedMap,
  ).copyWith(hooks: _mergeHooks(_parseHooksFromMap(baseMap), _parseHooksFromMap(overrideMap)));
}

Config applyEnvOverrides(Config config) => _applyEnvOverrides(config);
HookMap filterWorktrunkHooks(HookMap hooks, IgnoreWorktrunkHooks ignore) => _filterWorktrunkHooks(hooks, ignore);
