#!/bin/sh
# Fast gate: build and run one test class, niced. Usage: ./check.sh [TestClass]
cd "$(dirname "$0")"
nice -n 19 swift test -j 2 ${1:+--filter "$1"} 2>&1 | grep -E 'error:|failed|Executed|first difference|expected:|actual:' | head -40
