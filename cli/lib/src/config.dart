import 'dart:io';

import 'package:dojjo/src/platform.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:path/path.dart' as p;
import 'package:toml/toml.dart';

part 'config.freezed.dart';

@freezed
sealed class MergeConfig with _$MergeConfig {
  const factory MergeConfig({
    @Default(true) bool squash,
    @Default(true) bool rebase,
    @Default(true) bool remove,
    @Default(true) bool verify,
    @Default(false) bool push,
  }) = _MergeConfig;
}

@freezed
sealed class ListConfig with _$ListConfig {
  const factory ListConfig({@Default('') String url}) = _ListConfig;
}

/// A single hook: a named command string.
/// When parsed from a simple string like `post-start = "npm install"`,
/// the name defaults to the hook type itself.
@freezed
sealed class HookEntry with _$HookEntry {
  const factory HookEntry({required String name, required String command}) = _HookEntry;
}

/// Map from hook type (e.g. "pre-merge") to its entries.
typedef HookMap = Map<String, List<HookEntry>>;

@freezed
sealed class CopyIgnoredConfig with _$CopyIgnoredConfig {
  const factory CopyIgnoredConfig({@Default(<String>[]) List<String> exclude}) = _CopyIgnoredConfig;
}

@freezed
sealed class Config with _$Config {
  const factory Config({
    @Default('') String worktreePath,
    @Default(MergeConfig()) MergeConfig merge,
    @Default(ListConfig()) ListConfig list,
    @Default(CopyIgnoredConfig()) CopyIgnoredConfig copyIgnored,
    @Default(<String, String>{}) Map<String, String> aliases,
    @Default(<String, List<HookEntry>>{}) HookMap hooks,
  }) = _Config;
}

/// Sources for config values, tracked for `config show`.
@freezed
sealed class ConfigWithSource with _$ConfigWithSource {
  const factory ConfigWithSource({required Config config, @Default(<String>[]) List<String> sources}) =
      _ConfigWithSource;
}

HookMap _parseHooks(Map<String, Object?> hooksMap) {
  final result = <String, List<HookEntry>>{};
  for (final entry in hooksMap.entries) {
    final hookType = entry.key;
    final value = entry.value;
    if (value is String) {
      // Simple form: post-start = "npm install"
      result[hookType] = [HookEntry(name: hookType, command: value)];
    } else if (value is Map<String, Object?>) {
      // Named form: [hooks.pre-merge] test = "cargo test"
      result[hookType] = value.entries.map((e) => HookEntry(name: e.key, command: e.value as String? ?? '')).toList();
    }
  }
  return result;
}

Config _parseToml(String content) {
  final doc = TomlDocument.parse(content).toMap();

  final mergeMap = doc['merge'] as Map<String, Object?>? ?? {};
  final listMap = doc['list'] as Map<String, Object?>? ?? {};
  final stepMap = doc['step'] as Map<String, Object?>? ?? {};
  final copyIgnoredMap = stepMap['copy-ignored'] as Map<String, Object?>? ?? {};
  final aliasMap = doc['aliases'] as Map<String, Object?>? ?? {};
  final hooksMap = doc['hooks'] as Map<String, Object?>? ?? {};

  return Config(
    worktreePath: doc['worktree-path'] as String? ?? '',
    merge: MergeConfig(
      squash: mergeMap['squash'] as bool? ?? true,
      rebase: mergeMap['rebase'] as bool? ?? true,
      remove: mergeMap['remove'] as bool? ?? true,
      verify: mergeMap['verify'] as bool? ?? true,
      push: mergeMap['push'] as bool? ?? false,
    ),
    list: ListConfig(url: listMap['url'] as String? ?? ''),
    copyIgnored: CopyIgnoredConfig(exclude: (copyIgnoredMap['exclude'] as List<Object?>?)?.cast<String>() ?? []),
    aliases: aliasMap.map((key, value) => MapEntry(key, value as String? ?? '')),
    hooks: _parseHooks(hooksMap),
  );
}

HookMap _mergeHooks(HookMap base, HookMap override) {
  final result = Map.of(base);
  for (final entry in override.entries) {
    result[entry.key] = entry.value;
  }
  return result;
}

Config _mergeConfigs(Config base, Config override) => Config(
  worktreePath: override.worktreePath.isNotEmpty ? override.worktreePath : base.worktreePath,
  merge: MergeConfig(
    squash: override.merge.squash,
    rebase: override.merge.rebase,
    remove: override.merge.remove,
    verify: override.merge.verify,
    push: override.merge.push,
  ),
  list: ListConfig(url: override.list.url.isNotEmpty ? override.list.url : base.list.url),
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

/// Load config from all sources, merged in precedence order.
/// Returns the effective config and the list of files that were loaded.
Future<ConfigWithSource> loadConfig({String? projectRoot}) async {
  final home = homeDirectory;
  final root = projectRoot ?? Directory.current.path;

  final paths = [
    (p.join(home, '.config', 'worktrunk', 'config.toml'), 'worktrunk user'),
    (p.join(home, '.config', 'dojjo', 'config.toml'), 'dojjo user'),
    (p.join(root, '.config', 'wt.toml'), 'worktrunk project'),
    (p.join(root, '.config', 'djo.toml'), 'dojjo project'),
  ];

  var config = const Config();
  final sources = <String>[];

  for (final (path, label) in paths) {
    final loaded = await _tryLoadFile(path);
    if (loaded != null) {
      config = _mergeConfigs(config, loaded);
      sources.add('$label: $path');
    }
  }

  config = _applyEnvOverrides(config);

  return ConfigWithSource(config: config, sources: sources);
}

// Exposed for testing.
Config parseToml(String content) => _parseToml(content);
Config mergeConfigs(Config base, Config override) => _mergeConfigs(base, override);
Config applyEnvOverrides(Config config) => _applyEnvOverrides(config);
