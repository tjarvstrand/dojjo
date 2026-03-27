import 'dart:io';

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
  const factory ListConfig({
    @Default('') String url,
  }) = _ListConfig;
}

@freezed
sealed class Config with _$Config {
  const factory Config({
    @Default('') String worktreePath,
    @Default(MergeConfig()) MergeConfig merge,
    @Default(ListConfig()) ListConfig list,
    @Default(<String, String>{}) Map<String, String> aliases,
  }) = _Config;
}

/// Sources for config values, tracked for `config show`.
@freezed
sealed class ConfigWithSource with _$ConfigWithSource {
  const factory ConfigWithSource({
    required Config config,
    @Default(<String>[]) List<String> sources,
  }) = _ConfigWithSource;
}

Config _parseToml(String content) {
  final doc = TomlDocument.parse(content).toMap();

  final mergeMap = doc['merge'] as Map<String, Object?>? ?? {};
  final listMap = doc['list'] as Map<String, Object?>? ?? {};
  final aliasMap = doc['aliases'] as Map<String, Object?>? ?? {};

  return Config(
    worktreePath: doc['worktree-path'] as String? ?? '',
    merge: MergeConfig(
      squash: mergeMap['squash'] as bool? ?? true,
      rebase: mergeMap['rebase'] as bool? ?? true,
      remove: mergeMap['remove'] as bool? ?? true,
      verify: mergeMap['verify'] as bool? ?? true,
      push: mergeMap['push'] as bool? ?? false,
    ),
    list: ListConfig(
      url: listMap['url'] as String? ?? '',
    ),
    aliases: aliasMap.map(
      (key, value) => MapEntry(key, value as String? ?? ''),
    ),
  );
}

Config _mergeConfigs(Config base, Config override) => Config(
      worktreePath: override.worktreePath.isNotEmpty
          ? override.worktreePath
          : base.worktreePath,
      merge: MergeConfig(
        squash: override.merge.squash,
        rebase: override.merge.rebase,
        remove: override.merge.remove,
        verify: override.merge.verify,
      ),
      list: ListConfig(
        url: override.list.url.isNotEmpty
            ? override.list.url
            : base.list.url,
      ),
      aliases: {...base.aliases, ...override.aliases},
    );

Config _applyEnvOverrides(Config config) {
  final env = Platform.environment;
  return config.copyWith(
    worktreePath:
        env['DOJJO_WORKTREE_PATH'] ?? config.worktreePath,
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
  final home = Platform.environment['HOME'] ?? '';
  final root = projectRoot ?? Directory.current.path;

  final paths = [
    ('$home/.config/worktrunk/config.toml', 'worktrunk user'),
    ('$home/.config/dojjo/config.toml', 'dojjo user'),
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
Config mergeConfigs(Config base, Config override) =>
    _mergeConfigs(base, override);
Config applyEnvOverrides(Config config) => _applyEnvOverrides(config);
