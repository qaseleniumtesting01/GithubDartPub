// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// @dart=2.9

import 'dart:convert';

import 'package:test/test.dart';

import 'package:pub_dev/search/mem_index.dart';
import 'package:pub_dev/search/search_service.dart';
import 'package:pub_dev/search/text_utils.dart';

void main() {
  group('angular', () {
    InMemoryPackageIndex index;

    setUpAll(() async {
      index = InMemoryPackageIndex();
      await index.addPackage(PackageDocument(
        package: 'angular',
        version: '4.0.0',
        description: compactDescription('Fast and productive web framework.'),
      ));
      await index.addPackage(PackageDocument(
        package: 'angular_ui',
        version: '0.6.5',
        description: compactDescription('Port of Angular-UI to Dart.'),
      ));
      await index.markReady();
    });

    test('angular', () async {
      final PackageSearchResult result = await index.search(
          ServiceSearchQuery.parse(query: 'angular', order: SearchOrder.text));
      expect(json.decode(json.encode(result)), {
        'timestamp': isNotNull,
        'totalCount': 2,
        'highlightedHit': {'package': 'angular'},
        'sdkLibraryHits': [],
        'packageHits': [
          {
            'package': 'angular_ui',
            'score': closeTo(0.88, 0.01),
          },
        ],
      });
    });
  });
}
