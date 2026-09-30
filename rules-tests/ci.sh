#!/usr/bin/env bash
set -euo pipefail
cd rules-tests
npm install --no-audit --no-fund
npm test
