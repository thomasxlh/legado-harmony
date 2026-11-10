#!/usr/bin/env bash
# Real ArkTS compile check for this project (no DevEco IDE needed).
# Usage: bash scripts/build_check.sh
# Runs hvigor's CompileArkTS via assembleHap with the SDK env wired up.
set -o pipefail
cd "$(dirname "$0")/.." || exit 2
export DEVECO_SDK_HOME="C:/sandbox/DevEco Studio/sdk"
NODE="/c/sandbox/nodejs/node.exe"
HVIGOR="/c/sandbox/DevEco Studio/tools/hvigor/bin/hvigorw.js"
LOG="scripts/_build_check.log"
"$NODE" "$HVIGOR" --mode module -p product=default assembleHap > "$LOG" 2>&1
rc=$?
# hvigor regenerates two BuildProfile.ets build artifacts on every run;
# restore them byte-exactly from HEAD so the working tree stays clean.
PY="C:/Users/riska/.dsh/dsh-runtimes/dsh-next-primary-runtime/dependencies/python/python.exe"
"$PY" -c "
import subprocess
for p in ['entry/oh_modules/@devzeng/quickjs/BuildProfile.ets','quickjs/BuildProfile.ets']:
    data = subprocess.check_output(['git','show','HEAD:'+p])
    with open(p,'wb') as f: f.write(data)
" 2>/dev/null || true
# Surface only errors + the final verdict + any ArkTS error lines
echo "=== BUILD rc=$rc ==="
grep -aE "BUILD (SUCCESSFUL|FAILED)|ArkTS:ERROR|error:|Finished :entry:default@CompileArkTS|ERROR:" "$LOG" | head -60
echo "=== full log: $LOG ==="
exit $rc
