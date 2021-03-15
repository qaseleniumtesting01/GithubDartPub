// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:gcloud/db.dart';
import 'package:test/test.dart';

import 'package:pub_dev/frontend/handlers/documentation.dart';
import 'package:pub_dev/package/backend.dart';
import 'package:pub_dev/shared/urls.dart';

import '../../frontend/handlers/_utils.dart';
import '../../shared/handlers_test_utils.dart';
import '../../shared/test_services.dart';

void main() {
  group('path parsing', () {
    void testUri(String rqPath, String package, [String version, String path]) {
      final p = parseRequestUri(Uri.parse('$siteRoot$rqPath'));
      if (package == null) {
        expect(p, isNull);
      } else {
        expect(p, isNotNull);
        expect(p.package, package);
        expect(p.version, version);
        expect(p.path, path);
      }
    }

    test('bad prefix', () {
      testUri('/doc/pkg/latest/', null);
    });

    test('insufficient prefix', () {
      testUri('/documentation', null);
      testUri('/documentation/', null);
    });

    test('bad package name', () {
      testUri('/documentation//latest/', null);
      testUri('/documentation/<pkg>/latest/', null);
      testUri('/documentation/pkg with space/latest/', null);
    });

    test('no version specified', () {
      testUri('/documentation/angular', 'angular');
      testUri('/documentation/angular/', 'angular');
    });

    test('bad version', () {
      testUri('/documentation/pkg//', 'pkg');
      testUri('/documentation/pkg/first-release/', 'pkg');
      testUri('/documentation/pkg/1.2.3.4.5.6/', 'pkg');
    });

    test('version without path', () {
      testUri('/documentation/angular/4.0.0+2', 'angular', '4.0.0+2');
      testUri('/documentation/angular/4.0.0+2/', 'angular', '4.0.0+2',
          'index.html');
    });

    test('version with a path', () {
      testUri('/documentation/angular/4.0.0+2/subdir/', 'angular', '4.0.0+2',
          'subdir/index.html');
      testUri('/documentation/angular/4.0.0+2/file.html', 'angular', '4.0.0+2',
          'file.html');
      testUri('/documentation/angular/4.0.0+2/file.html', 'angular', '4.0.0+2',
          'file.html');
    });
  });

  group('dartdoc handlers', () {
    testWithProfile('/documentation/flutter redirect', fn: () async {
      await expectRedirectResponse(
        await issueGet('/documentation/flutter'),
        'https://api.flutter.dev/',
      );
    });

    testWithProfile('/documentation/flutter/version redirect', fn: () async {
      await expectRedirectResponse(
        await issueGet('/documentation/flutter/version'),
        'https://api.flutter.dev/',
      );
    });

    testWithProfile('/documentation/foobar_pkg/bar redirect', fn: () async {
      await expectRedirectResponse(
        await issueGet('/documentation/oxygen/bar'),
        '/documentation/oxygen/latest/',
      );
    });

    testWithProfile('trailing slash redirect', fn: () async {
      await expectRedirectResponse(await issueGet('/documentation/oxygen'),
          '/documentation/oxygen/latest/');
    });

    testWithProfile('/documentation/oxygen - no entry redirect', fn: () async {
      await expectRedirectResponse(await issueGet('/documentation/oxygen/'),
          '/documentation/oxygen/latest/');
    });

    testWithProfile('/d/oxygen/latest/ redirect', fn: () async {
      await expectRedirectResponse(
          await issueGet('/documentation/oxygen/latest/'),
          '/packages/oxygen/versions');
    });

    testWithProfile('/d/oxygen/latest/unknown.html redirect', fn: () async {
      await expectRedirectResponse(
          await issueGet('/documentation/oxygen/latest/unknown.html'),
          '/packages/oxygen/versions');
    });

    testWithProfile('withheld package gets rejected', fn: () async {
      final pkg = await packageBackend.lookupPackage('oxygen');
      await dbService.commit(inserts: [pkg..isWithheld = true]);
      await expectNotFoundResponse(
          await issueGet('/documentation/oxygen/latest/'));
    });
  });
}
