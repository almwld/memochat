#!/usr/bin/env bash
set -euo pipefail

JDK21="$(find /opt/hostedtoolcache/Java_Temurin-Hotspot_jdk -maxdepth 1 -mindepth 1 -type d -name '21.*' -print -quit 2>/dev/null || true)"
if [[ -n "$JDK21" ]]; then
  export JAVA_HOME="$JDK21"
  export PATH="$JAVA_HOME/bin:$PATH"
fi

cd rules-tests
npm install --no-audit --no-fund
npm test
