// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:pana/pana.dart' as pana;
import 'package:pub_semver/pub_semver.dart';

/// The pattern of [runtimeVersion], should be updated to reflect the current
/// date the change happened, e.g. `2020.02.18`
///
/// While the format follows the semantic version pattern, we do not support
/// extra values (e.g. build numbers or pre-release versions).
///
/// If there is ever a need to have multiple runtimeVersions on the same date, it is suggested that
/// a future dates are used.
final RegExp runtimeVersionPattern = RegExp(r'^\d{4}\.\d{2}\.\d{2}$');

/// The list (and priority order) of runtimeVersions where version-specific data
/// is accepted from.
///
/// Make sure that at least two versions are kept here as the next candidates
/// when the version switch happens.
const acceptedRuntimeVersions = <String>[
  '2021.06.24', // The current [runtimeVersion].
  '2021.06.21',
  '2021.06.16',
];

/// Represents a combined version of the overall toolchain and processing,
/// allowing easy check for data compatibility, age comparison and also reflects
/// whether an analysis needs to be re-done.
///
/// Increment the version when a change is significant enough to trigger
/// reprocessing, including: risk of data corruption in analysis, version change
/// in pana, dartdoc, or the SDKs, or when an feature or bugfix should be picked
/// up by the analysis ASAP.
final String runtimeVersion = acceptedRuntimeVersions.first;
final Version semanticRuntimeVersion = Version.parse(runtimeVersion);

/// The list of runtime versions to use when looking for past version-specific
/// data.
final fallbackRuntimeVersions = acceptedRuntimeVersions.skip(1).toList();

/// The version which marks the earliest version of the data which we'd like to
/// keep during various GC processes. Data prior to this version is subject to
/// delete (unless there is another rule in place to keep it).
final gcBeforeRuntimeVersion = acceptedRuntimeVersions.last;

/// Returns true if the given version should be considered as obsolete and can
/// be deleted.
bool shouldGCVersion(String version) =>
    version.compareTo(gcBeforeRuntimeVersion) < 0;

// keep in-sync with SDK version in .mono_repo.yml and Dockerfile
final String runtimeSdkVersion = '2.13.3';
final String toolStableDartSdkVersion = '2.13.3';
final String toolStableFlutterSdkVersion = '2.2.2';
final String toolPreviewDartSdkVersion = '2.14.0-188.3.beta';
final String toolPreviewFlutterSdkVersion = '2.2.2';

// Value comes from package:pana.
final String panaVersion = pana.packageVersion;
final Version semanticPanaVersion = Version.parse(panaVersion);

// keep in-sync with pkg/pub_dartdoc/pubspec.yaml
final String dartdocVersion = '0.45.0';
final Version semanticDartdocVersion = Version.parse(dartdocVersion);

// Version that control the dartdoc serving.
// Pin this to a specific version when there is a coordinated upgrade of the
// generated documentation template or style. The new version can generate the
// docs without any traffic sent to it, while the old won't accidentally serve
// them.
final dartdocServingRuntime = Version.parse(runtimeVersion);

/// Whether the given runtime version (stored with the dartdoc entry) should
/// be displayed on the live site (or a coordinated upgrade is in progress).
bool shouldServeDartdoc(String? storedRuntimeVersion) {
  if (storedRuntimeVersion == null) return false;
  return acceptedRuntimeVersions.contains(storedRuntimeVersion);
}
