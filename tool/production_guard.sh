#!/usr/bin/env bash
set -euo pipefail
fail(){ echo "❌ Production guard: $1" >&2; exit 1; }
test -f pubspec.yaml || fail "pubspec.yaml is missing"
test -f analysis_options.yaml || fail "analysis_options.yaml is missing"
test -f firestore.rules || fail "firestore.rules is missing"
test -f .github/workflows/flutter.yml || fail "Flutter CI workflow is missing"
test -f android/app/build.gradle || fail "Android build configuration is missing"
grep -Eq '^version:[[:space:]]+[0-9]+\.[0-9]+\.[0-9]+\+[0-9]+' pubspec.yaml || fail "pubspec.yaml does not contain a production version"
grep -Eq 'applicationId[[:space:]]+"com\.memo\.app"' android/app/build.gradle || fail "Android applicationId is not com.memo.app"
grep -Eq 'compileSdk[[:space:]]+35' android/app/build.gradle || fail "Android compileSdk baseline is not 35"
grep -Eq 'targetSdk[[:space:]]+35' android/app/build.gradle || fail "Android targetSdk baseline is not 35"
if git grep -nE -- '-----BEGIN (RSA |EC |OPENSSH |DSA )?PRIVATE KEY-----' -- . ':!tool/production_guard.sh'; then fail "a private key block is tracked in the repository"; fi
echo "✅ Production guard passed."
