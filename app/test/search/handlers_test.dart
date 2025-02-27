// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// @dart=2.9

import 'dart:async';

import 'package:test/test.dart';

import 'package:pub_dev/search/backend.dart';
import 'package:pub_dev/search/dart_sdk_mem_index.dart';
import 'package:pub_dev/search/flutter_sdk_mem_index.dart';
import 'package:pub_dev/search/mem_index.dart';
import 'package:pub_dev/search/search_service.dart';

import '../shared/handlers_test_utils.dart';
import '../shared/utils.dart';

import 'handlers_test_utils.dart';

void main() {
  group('handlers', () {
    group('not found', () {
      scopedTest('/xxx', () async {
        await expectNotFoundResponse(await issueGet('/xxx'));
      });
      scopedTest('/packages', () async {
        await expectNotFoundResponse(await issueGet('/packages'));
      });

      scopedTest('/packages/pkg_foo', () async {
        registerSearchBackend(MockSearchBackend());
        await expectNotFoundResponse(await issueGet('/packages/unknown'));
      });
    });

    group('search', () {
      Future<void> setUpInServiceScope() async {
        registerSearchBackend(MockSearchBackend());
        registerPackageIndex(InMemoryPackageIndex());
        registerDartSdkMemIndex(DartSdkMemIndex());
        registerFlutterSdkMemIndex(FlutterSdkMemIndex());
        await packageIndex
            .addPackage(await searchBackend.loadDocument('pkg_foo'));
        await packageIndex.markReady();
      }

      scopedTest('Finds package by name', () async {
        await setUpInServiceScope();
        await expectJsonResponse(await issueGet('/search?q=pkg_foo'), body: {
          'timestamp': isNotNull,
          'totalCount': 1,
          'highlightedHit': {'package': 'pkg_foo'},
          'sdkLibraryHits': [],
          'packageHits': [],
        });
      });

      scopedTest('Finds text in description or readme', () async {
        await setUpInServiceScope();
        await expectJsonResponse(await issueGet('/search?q=json'), body: {
          'timestamp': isNotNull,
          'totalCount': 1,
          'sdkLibraryHits': [],
          'packageHits': [
            {
              'package': 'pkg_foo',
              'score': closeTo(0.45, 0.01),
            },
          ],
        });
      });

      scopedTest('pkg-prefix doesn\'t affect score', () async {
        await setUpInServiceScope();
        await expectJsonResponse(await issueGet('/search?q=json&pkg-prefix=pk'),
            body: {
              'timestamp': isNotNull,
              'totalCount': 1,
              'sdkLibraryHits': [],
              'packageHits': [
                {
                  'package': 'pkg_foo',
                  'score': closeTo(0.45, 0.01),
                },
              ],
            });
      });

      scopedTest('Finds package by package-prefix search only', () async {
        await setUpInServiceScope();
        await expectJsonResponse(await issueGet('/search?q=package:pk'), body: {
          'timestamp': isNotNull,
          'totalCount': 1,
          'sdkLibraryHits': [],
          'packageHits': [
            {
              'package': 'pkg_foo',
              'score': closeTo(0.51, 0.01),
            },
          ],
        });
      });

      scopedTest('pkg-prefix filters out results', () async {
        await setUpInServiceScope();
        await expectJsonResponse(await issueGet('/search?q=json+package:foo'),
            body: {
              'timestamp': isNotNull,
              'totalCount': 0,
              'sdkLibraryHits': [],
              'packageHits': [],
            });
      });
    });
  });
}

class MockSearchBackend implements SearchBackend {
  List<String> packages = ['pkg_foo'];

  @override
  Future<PackageDocument> loadDocument(String packageName,
      {bool requireAnalysis = false}) async {
    if (!packages.contains(packageName)) {
      return null;
    }
    return PackageDocument(
      package: packageName,
      version: '1.0.1',
      tags: ['sdk:dart'],
      description: 'Foo package about nothing really. Maybe JSON.',
      readme: 'Some JSON to XML mapping.',
      popularity: 0.1,
    );
  }

  @override
  Stream<PackageDocument> loadMinimumPackageIndex() async* {
    throw UnimplementedError();
  }
}
