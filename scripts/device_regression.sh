#!/usr/bin/env bash
# Long-running TTS lifecycle regression on a connected OpenHarmony device/emulator.
# Drives background/foreground, screen off/on, and manual page turns while
# continuous reading runs, capturing hilog for post-mortem crash/freeze scans.
#
# NOTE: Home/Power churn suspends audio by design, so this run validates
# "no crash / no freeze / process stays alive" across lifecycle switches, NOT
# uninterrupted audio. For the continuous-reading scenario use
# foreground_regression.sh instead.
#
# Usage:
#   bash scripts/device_regression.sh [ROUNDS]
# Overridable env: HDC, HDC_HOME, HDC_TARGET, BUNDLE, ROUNDS, WORKSPACE,
#                  ACTIONS_LOG, HILOG_LOG, SWIPE_FROM, SWIPE_TO, SWIPE_Y.
set -u
WS="${WORKSPACE:-$(cd "$(dirname "$0")/.." && pwd)}"
cd "$WS" || exit 1
HDC="${HDC:-${HDC_HOME:-/c/sandbox/DevEco Studio/sdk/default/openharmony/toolchains}/hdc.exe}"
TARGET="${HDC_TARGET:-127.0.0.1:5555}"
BUNDLE="${BUNDLE:-legado.intrimple.com}"
T="-t $TARGET"
ACT="${ACTIONS_LOG:-scripts/_regression_actions.log}"
LOG="${HILOG_LOG:-scripts/_regression_hilog.log}"
ROUNDS="${1:-${ROUNDS:-20}}"
SWIPE_FROM="${SWIPE_FROM:-1050 1450}"
SWIPE_TO="${SWIPE_TO:-250 1450}"

# hdc exits 0 even for an unknown connect-key, so match the target in `list
# targets` (exact line) instead of trusting the shell command's exit code.
# Strip CR first: hdc on Windows emits CRLF, which breaks exact -x matching.
if ! "$HDC" list targets 2>/dev/null | tr -d '\r' | grep -Fqx -- "$TARGET"; then
  echo "ERROR: hdc target not found: $TARGET (hdc=$HDC)" >&2
  echo "       available targets:" >&2
  "$HDC" list targets 2>/dev/null | sed 's/^/         /' >&2
  echo "       set HDC / HDC_HOME / HDC_TARGET to match your environment" >&2
  exit 2
fi

: > "$ACT"; : > "$LOG"
log(){ echo "[$(date '+%H:%M:%S')] $*" >> "$ACT"; }
"$HDC" $T shell "hilog -r" >/dev/null 2>&1
# hilog with no -x streams forever: follow it in the background and stop on exit.
"$HDC" $T shell "hilog" >> "$LOG" 2>&1 &
CAP=$!
cleanup(){ kill "$CAP" 2>/dev/null || true; }
trap cleanup EXIT INT TERM
log "hilog follower pid=$CAP ; target=$TARGET ; bundle=$BUNDLE ; rounds=$ROUNDS"
for i in $(seq 1 "$ROUNDS"); do
  log "=== round $i/$ROUNDS : lifecycle churn ==="
  "$HDC" $T shell "uitest uiInput keyEvent Home" >/dev/null 2>&1
  sleep 3
  "$HDC" $T shell "aa start -a EntryAbility -b $BUNDLE" >/dev/null 2>&1
  sleep 4
  "$HDC" $T shell "uitest uiInput keyEvent Power" >/dev/null 2>&1
  sleep 3
  "$HDC" $T shell "uitest uiInput keyEvent Power" >/dev/null 2>&1
  sleep 4
  "$HDC" $T shell "uitest uiInput swipe $SWIPE_FROM $SWIPE_TO" >/dev/null 2>&1
  sleep 2
  "$HDC" $T shell "uitest uiInput swipe $SWIPE_FROM $SWIPE_TO" >/dev/null 2>&1
  sleep 2
  psalive=$("$HDC" $T shell "ps -ef" 2>/dev/null | grep -F -c -- "$BUNDLE")
  log "round $i done ; app processes=$psalive"
done
log "=== FINAL: process + last speak ==="
"$HDC" $T shell "ps -ef" 2>/dev/null | grep -F -- "$BUNDLE" >> "$ACT" || true
log "capture stopped"
