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
    _show('workspace-path', config.workspacePath);
    _show('merge.squash', config.merge.squash);
    _show('merge.rebase', config.merge.rebase);
    _show('merge.remove', config.merge.remove);
    _show('merge.verify', config.merge.verify);
    _show('merge.push', config.merge.push);
    _show('list.url', config.list.url);
    for (final MapEntry(:key, value: pipeline) in config.aliases.entries) {
      final commands = pipeline.expand((step) => step.map((e) => e.command)).toList();
      if (commands.length == 1) {
        _show('aliases.$key', commands.first);
      } else {
        _show('aliases.$key', '[${commands.length} commands]');
        for (final step in pipeline) {
          for (final entry in step) {
            _show('aliases.$key.${entry.name}', entry.command);
          }
        }
      }
    }
  }

  void _show(String key, Object value) {
    final display = value == '' ? '(not set)' : value;
    stdout.writeln('  $key = $display');
  }
}
