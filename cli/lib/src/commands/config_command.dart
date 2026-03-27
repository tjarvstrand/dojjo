import 'dart:io';

import 'package:args/command_runner.dart';

import 'package:dojjo/src/config.dart';

class ConfigCommand extends Command<void> {
  ConfigCommand(this._configWithSource) {
    addSubcommand(ConfigShowCommand(_configWithSource));
  }

  final ConfigWithSource _configWithSource;

  @override
  String get name => 'config';

  @override
  String get description => 'Configuration management';
}

class ConfigShowCommand extends Command<void> {
  ConfigShowCommand(this._configWithSource);

  final ConfigWithSource _configWithSource;

  @override
  String get name => 'show';

  @override
  String get description => 'Display effective configuration';

  @override
  Future<void> run() async {
    final config = _configWithSource.config;
    final sources = _configWithSource.sources;

    if (sources.isEmpty) {
      stdout.writeln('No config files found.');
    } else {
      stdout.writeln('Config sources (lowest to highest precedence):');
      for (final source in sources) {
        stdout.writeln('  $source');
      }
    }

    stdout.writeln('');
    stdout.writeln('Effective configuration:');
    _show('worktree-path', config.worktreePath);
    _show('merge.squash', config.merge.squash);
    _show('merge.rebase', config.merge.rebase);
    _show('merge.remove', config.merge.remove);
    _show('merge.verify', config.merge.verify);
    _show('list.url', config.list.url);
    if (config.aliases.isNotEmpty) {
      for (final entry in config.aliases.entries) {
        _show('aliases.${entry.key}', entry.value);
      }
    }
  }

  void _show(String key, Object value) {
    final display = value == '' ? '(not set)' : value;
    stdout.writeln('  $key = $display');
  }
}
