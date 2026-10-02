#!/usr/bin/env bash
set -euo pipefail

fail(){ echo "❌ Production guard: $1" >&2; exit 1; }

test -f pubspec.yaml || fail "pubspec.yaml is missing"
test -f analysis_options.yaml || fail "analysis_options.yaml is missing"
test -f firestore.rules || fail "firestore.rules is missing"
test -f .github/workflows/flutter.yml || fail "Flutter CI workflow is missing"
test -f android/app/build.gradle || fail "Android app Gradle configuration is missing"

grep -Eq '^version:[[:space:]]+[0-9]+\.[0-9]+\.[0-9]+\+[0-9]+' pubspec.yaml ||
  fail "pubspec.yaml does not contain a production version"

# Validate the committed Android production configuration directly.
# The Flutter CI may regenerate platform scaffolding, so these checks must not
# depend on implementation details inside the secret-bearing workflow file.
grep -Eq 'applicationId[[:space:]]+"com\.memo\.app"' android/app/build.gradle ||
  fail "Android configuration does not set applicationId com.memo.app"
grep -Eq 'compileSdk[[:space:]]+35' android/app/build.gradle ||
  fail "Android configuration does not enforce compileSdk 35"
grep -Eq 'targetSdkVersion[[:space:]]+35' android/app/build.gradle ||
  fail "Android configuration does not enforce targetSdk 35"
grep -Eq 'minSdkVersion[[:space:]]+23' android/app/build.gradle ||
  fail "Android configuration does not enforce minSdk 23"

if git grep -nE -- '-----BEGIN (RSA |EC |OPENSSH |DSA )?PRIVATE KEY-----' -- . ':!tool/production_guard.sh'; then
  fail "a private key block is tracked in the repository"
fi

echo "✅ Production guard passed."
