// Copyright (c) 2020, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// @dart=2.9

/// Creates a report about recent uploaders.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:pool/pool.dart';
import 'package:pub_dev/account/backend.dart';

import 'package:pub_dev/package/models.dart';
import 'package:pub_dev/service/entrypoint/tools.dart';
import 'package:pub_dev/shared/datastore.dart';

Future main(List<String> args) async {
  final ArgParser parser = ArgParser()
    ..addOption('max-age',
        defaultsTo: '7', help: 'The maximum age of the package in days.')
    ..addOption('output', help: 'The report output file (or stdout otherwise)');
  final argv = parser.parse(args);
  final maxAgeDays = int.parse(argv['max-age'] as String);

  final byUploaders = <String, List<String>>{};
  final byPublishers = <String, List<String>>{};

  final pool = Pool(10);

  await withToolRuntime(() async {
    final updatedAfter = DateTime.now().subtract(Duration(days: maxAgeDays));
    final query = dbService.query<Package>()
      ..filter('updated >=', updatedAfter);
    final futures = <Future>[];
    await for (final p in query.run()) {
      Future<void> process() async {
        if (p.publisherId != null) {
          byPublishers.putIfAbsent(p.publisherId, () => <String>[]).add(p.name);
        } else {
          final uploaderEmails =
              await accountBackend.getEmailsOfUserIds(p.uploaders);
          uploaderEmails.forEach((email) {
            byUploaders.putIfAbsent(email, () => <String>[]).add(p.name);
          });
        }
      }

      futures.add(pool.withResource(process));
    }
    await Future.wait(futures);
  });
  await pool.close();

  Map<String, List<String>> sortByCountAndTrim(Map<String, List<String>> map) {
    final keys = map.keys.toList();
    keys.sort((a, b) => -map[a].length.compareTo(map[b].length));
    final mapped = <String, List<String>>{};
    for (final key in keys) {
      mapped[key] = map[key].take(3).toList();
    }
    return mapped;
  }

  final String json = JsonEncoder.withIndent('  ').convert({
    'byUploaders': sortByCountAndTrim(byUploaders),
    'byPublishers': sortByCountAndTrim(byPublishers),
  });
  if (argv['output'] != null) {
    final File outputFile = File(argv['output'] as String);
    print('Writing report to ${outputFile.path}');
    await outputFile.parent.create(recursive: true);
    await outputFile.writeAsString(json + '\n');
  } else {
    print(json);
  }
}
