// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// @dart=2.9

import 'dart:convert';

import 'package:pub_dev/search/dart_sdk_mem_index.dart';
import 'package:pub_dev/search/models.dart';
import 'package:test/test.dart';

import 'package:pub_dev/search/flutter_sdk_mem_index.dart';
import 'package:pub_dev/search/mem_index.dart';
import 'package:pub_dev/search/result_combiner.dart';
import 'package:pub_dev/search/search_service.dart';

void main() {
  group('ResultCombiner', () {
    final primaryIndex = InMemoryPackageIndex();
    final dartSdkMemIndex = DartSdkMemIndex();
    final flutterSdkMemIndex = FlutterSdkMemIndex();
    final combiner = SearchResultCombiner(
      primaryIndex: primaryIndex,
      dartSdkMemIndex: dartSdkMemIndex,
      flutterSdkMemIndex: flutterSdkMemIndex,
    );

    setUpAll(() async {
      await primaryIndex.addPackage(PackageDocument(
        package: 'stringutils',
        version: '1.0.0',
        description: 'many utils utils',
        readme: 'Many useful string methods like substring.',
        popularity: 0.4,
        grantedPoints: 110,
        maxPoints: 110,
        uploaderEmails: ['foo@example.com'],
      ));
      dartSdkMemIndex.setDartdocIndex(
        DartdocIndex.fromJsonList([
          {
            'name': 'dart:core',
            'qualifiedName': 'dart:core',
            'href': 'dart-core/dart-core-library.html',
            'type': 'library',
            'overriddenDepth': 0,
            'packageName': 'Dart'
          },
          {
            'name': 'String',
            'qualifiedName': 'dart:core.String',
            'href': 'dart-core/String-class.html',
            'type': 'class',
            'overriddenDepth': 0,
            'packageName': 'Dart',
            'enclosedBy': {'name': 'dart:core', 'type': 'library'}
          },
          {
            'name': 'substring',
            'qualifiedName': 'dart:core.String.substring',
            'href': 'dart-core/String/substring.html',
            'type': 'method',
            'overriddenDepth': 0,
            'packageName': 'Dart',
            'enclosedBy': {'name': 'String', 'type': 'class'}
          },
          {
            // fake method for checking the package name matches
            'name': 'stringutils',
            'qualifiedName': 'dart:core.String.stringutils',
            'href': 'dart-core/String/stringutils.html',
            'type': 'method',
            'overriddenDepth': 0,
            'packageName': 'Dart',
            'enclosedBy': {'name': 'String', 'type': 'class'}
          },
        ]),
        version: '2.0.0',
      );
      await primaryIndex.markReady();
    });

    test('non-text ranking', () async {
      final results = await combiner
          .search(ServiceSearchQuery.parse(order: SearchOrder.popularity));
      expect(json.decode(json.encode(results.toJson())), {
        'timestamp': isNotNull,
        'totalCount': 1,
        'sdkLibraryHits': [],
        'packageHits': [
          {'package': 'stringutils', 'score': 0.4},
        ],
      });
    });

    test('no actual text query', () async {
      final results = await combiner
          .search(ServiceSearchQuery.parse(query: 'email:foo@example.com'));
      expect(json.decode(json.encode(results.toJson())), {
        'timestamp': isNotNull,
        'totalCount': 1,
        'sdkLibraryHits': [],
        'packageHits': [
          {'package': 'stringutils', 'score': closeTo(0.8, 0.01)},
        ],
      });
    });

    test('search: substring', () async {
      final results =
          await combiner.search(ServiceSearchQuery.parse(query: 'substring'));
      expect(json.decode(json.encode(results.toJson())), {
        'timestamp': isNotNull,
        'totalCount': 1,
        'sdkLibraryHits': [
          {
            'sdk': 'dart',
            'version': '2.0.0',
            'library': 'dart:core',
            'url':
                'https://api.dart.dev/stable/2.0.0/dart-core/dart-core-library.html',
            'score': closeTo(0.98, 0.01),
            'apiPages': [
              {
                'title': null,
                'path': 'dart-core/String/substring.html',
                'url':
                    'https://api.dart.dev/stable/2.0.0/dart-core/String/substring.html'
              }
            ]
          },
        ],
        'packageHits': [
          {'package': 'stringutils', 'score': closeTo(0.59, 0.01)}
        ],
      });
    });

    test('exact name match: stringutils', () async {
      final results =
          await combiner.search(ServiceSearchQuery.parse(query: 'stringutils'));
      expect(json.decode(json.encode(results.toJson())), {
        'timestamp': isNotNull,
        'totalCount': 1,
        'highlightedHit': {'package': 'stringutils'},
        'sdkLibraryHits': [
          {
            'sdk': 'dart',
            'version': '2.0.0',
            'library': 'dart:core',
            'url':
                'https://api.dart.dev/stable/2.0.0/dart-core/dart-core-library.html',
            'score': closeTo(0.98, 0.01),
            'apiPages': [
              {
                'title': null,
                'path': 'dart-core/String/stringutils.html',
                'url':
                    'https://api.dart.dev/stable/2.0.0/dart-core/String/stringutils.html'
              }
            ]
          },
        ],
        'packageHits': [],
      });
    });
  });
}
