#!/usr/bin/env bash
set -euo pipefail

fail(){ echo "❌ Production guard: $1" >&2; exit 1; }

test -f pubspec.yaml || fail "pubspec.yaml is missing"
test -f analysis_options.yaml || fail "analysis_options.yaml is missing"
test -f firestore.rules || fail "firestore.rules is missing"
test -f .github/workflows/flutter.yml || fail "Flutter CI workflow is missing"

grep -Eq '^version:[[:space:]]+[0-9]+\.[0-9]+\.[0-9]+\+[0-9]+' pubspec.yaml ||
  fail "pubspec.yaml does not contain a production version"

# The Flutter CI intentionally generates the Android platform at build time.
# Validate the committed workflow's Android configuration instead of requiring
# generated android/app/build.gradle to exist in the repository.
grep -Eq 'flutter create --platforms=android' .github/workflows/flutter.yml ||
  fail "Flutter CI does not generate the Android platform"
grep -Eq 'applicationId[[:space:]]+"com\.memo\.app"' .github/workflows/flutter.yml ||
  fail "Flutter CI does not configure applicationId com.memo.app"
grep -Eq 'compileSdk 35' .github/workflows/flutter.yml ||
  fail "Flutter CI does not enforce compileSdk 35"
grep -Eq 'targetSdk 35' .github/workflows/flutter.yml ||
  fail "Flutter CI does not enforce targetSdk 35"
grep -Eq 'minSdk 23' .github/workflows/flutter.yml ||
  fail "Flutter CI does not enforce minSdk 23"

if git grep -nE -- '-----BEGIN (RSA |EC |OPENSSH |DSA )?PRIVATE KEY-----' -- . ':!tool/production_guard.sh'; then
  fail "a private key block is tracked in the repository"
fi

echo "✅ Production guard passed."
