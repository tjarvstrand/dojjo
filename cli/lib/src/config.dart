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
    @Default('') String worktreePath,
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

HookStep _parseHookStep(Map<String, Object?> map) =>
    map.entries.map((e) => HookEntry(name: e.key, command: e.value as String? ?? '')).toList();

HookMap _parseHooks(Map<String, Object?> hooksMap) {
  final result = <String, HookPipeline>{};
  for (final entry in hooksMap.entries) {
    final hookType = entry.key;
    final value = entry.value;
    if (value is String) {
      // Simple form: post-start = "npm install"
      // One step with one command.
      result[hookType] = [
        [HookEntry(name: hookType, command: value)],
      ];
    } else if (value is List) {
      // Pipeline form: post-start = [{ install = "npm install" }, { build = "npm run build" }]
      // Each list element is a step; commands within a step run in parallel.
      result[hookType] = value.whereType<Map<String, Object?>>().map(_parseHookStep).toList();
    } else if (value is Map<String, Object?>) {
      // Named form: [hooks.pre-merge] test = "cargo test"
      // One step with parallel commands.
      result[hookType] = [_parseHookStep(value)];
    }
  }
  return result;
}

Config _parseToml(String content) {
  final doc = TomlDocument.parse(content).toMap();

  // Flatten step.copy-ignored to top level for Config.fromJson.
  final stepMap = doc['step'];
  if (stepMap is Map<String, Object?>) {
    doc['copy-ignored'] = stepMap['copy-ignored'];
  }

  final config = Config.fromJson(doc);
  final hooksMap = doc['hooks'];
  return config.copyWith(
    hooks: hooksMap is Map<String, Object?> ? _parseHooks(hooksMap) : const {},
    ignoreWorktrunkHooks: _parseIgnoreWorktrunkHooks(doc['ignore-worktrunk-hooks']),
  );
}

IgnoreWorktrunkHooks _parseIgnoreWorktrunkHooks(Object? value) {
  if (value is bool && value) return const IgnoreWorktrunkHooks.all();
  if (value is List) return IgnoreWorktrunkHooks.types(value.cast<String>());
  return const IgnoreWorktrunkHooks.none();
}

HookMap _mergeHooks(HookMap base, HookMap override) {
  final result = <String, HookPipeline>{
    for (final entry in base.entries) entry.key: [...entry.value],
  };
  for (final entry in override.entries) {
    result.update(entry.key, (existing) => [...existing, ...entry.value], ifAbsent: () => entry.value);
  }
  return result;
}

Config _mergeConfigs(Config base, Config override) => Config(
  worktreePath: override.worktreePath.nonEmptyOrNull ?? base.worktreePath,
  merge: MergeConfig(
    squash: override.merge.squash,
    rebase: override.merge.rebase,
    remove: override.merge.remove,
    verify: override.merge.verify,
    push: override.merge.push,
  ),
  list: ListConfig(url: override.list.url.nonEmptyOrNull ?? base.list.url),
  copyIgnored: CopyIgnoredConfig(exclude: {...base.copyIgnored.exclude, ...override.copyIgnored.exclude}.toList()),
  aliases: {...base.aliases, ...override.aliases},
  hooks: _mergeHooks(base.hooks, override.hooks),
);

Config _applyEnvOverrides(Config config) {
  final env = Platform.environment;
  return config.copyWith(
    worktreePath: env['DOJJO_WORKTREE_PATH'] ?? config.worktreePath,
    merge: config.merge.copyWith(
      squash: _envBool(env, 'DOJJO_MERGE__SQUASH') ?? config.merge.squash,
      rebase: _envBool(env, 'DOJJO_MERGE__REBASE') ?? config.merge.rebase,
      remove: _envBool(env, 'DOJJO_MERGE__REMOVE') ?? config.merge.remove,
      verify: _envBool(env, 'DOJJO_MERGE__VERIFY') ?? config.merge.verify,
      push: _envBool(env, 'DOJJO_MERGE__PUSH') ?? config.merge.push,
    ),
  );
}

bool? _envBool(Map<String, String> env, String key) {
  final value = env[key];
  if (value == null) return null;
  return value.toLowerCase() == 'true';
}

Future<Config?> _tryLoadFile(String path) async {
  final file = File(path);
  if (!await file.exists()) return null;
  final content = await file.readAsString();
  return _parseToml(content);
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
  for (final entry in hooks.entries) {
    if (wholeTypes.contains(entry.key)) continue;

    final ignoredNames = namedEntries[entry.key];
    if (ignoredNames == null) {
      result[entry.key] = entry.value;
      continue;
    }

    // Filter out specific named entries from each step.
    final filteredPipeline = <HookStep>[];
    for (final step in entry.value) {
      final filteredStep = step.where((e) => !ignoredNames.contains(e.name)).toList();
      if (filteredStep.isNotEmpty) {
        filteredPipeline.add(filteredStep);
      }
    }
    if (filteredPipeline.isNotEmpty) {
      result[entry.key] = filteredPipeline;
    }
  }
  return result;
}

/// Load config from all sources, merged in precedence order.
/// Returns the effective config and the list of files that were loaded.
Future<ConfigWithSource> loadConfig({String? projectRoot}) async {
  final home = homeDirectory;
  final root = projectRoot ?? Directory.current.path;

  final wtPaths = [
    (p.join(home, '.config', 'worktrunk', 'config.toml'), 'worktrunk user'),
    (p.join(root, '.config', 'wt.toml'), 'worktrunk project'),
  ];
  final djoPaths = [
    (p.join(home, '.config', 'dojjo', 'config.toml'), 'dojjo user'),
    (p.join(root, '.config', 'djo.toml'), 'dojjo project'),
  ];

  // Load worktrunk configs first.
  var wtConfig = const Config();
  final sources = <String>[];
  for (final (path, label) in wtPaths) {
    final loaded = await _tryLoadFile(path);
    if (loaded != null) {
      wtConfig = _mergeConfigs(wtConfig, loaded);
      sources.add('$label: $path');
    }
  }

  // Load dojjo configs.
  var djoConfig = const Config();
  for (final (path, label) in djoPaths) {
    final loaded = await _tryLoadFile(path);
    if (loaded != null) {
      djoConfig = _mergeConfigs(djoConfig, loaded);
      sources.add('$label: $path');
    }
  }

  // Filter worktrunk hooks based on dojjo ignore settings.
  final filteredWtHooks = _filterWorktrunkHooks(wtConfig.hooks, djoConfig.ignoreWorktrunkHooks);
  wtConfig = wtConfig.copyWith(hooks: filteredWtHooks);

  // Merge: worktrunk base, dojjo overrides.
  var config = _mergeConfigs(wtConfig, djoConfig);
  config = _applyEnvOverrides(config);

  return ConfigWithSource(config: config, sources: sources);
}

// Exposed for testing.
Config parseToml(String content) => _parseToml(content);
Config mergeConfigs(Config base, Config override) => _mergeConfigs(base, override);
Config applyEnvOverrides(Config config) => _applyEnvOverrides(config);
HookMap filterWorktrunkHooks(HookMap hooks, IgnoreWorktrunkHooks ignore) => _filterWorktrunkHooks(hooks, ignore);
