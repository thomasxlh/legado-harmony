#!/usr/bin/env bash
# Foreground continuous-reading regression: keep TTS playing while driving
# manual page turns / taps (the "听书时翻页不顺畅/高亮卡住" scenario).
# No Home/Power (those suspend audio and invalidate the test).
#
# Precondition: TTS must already be playing before this script starts. Tap the
# reader's quick-TTS button (e.g. bottom-right area) and confirm live
#   hdc -t <target> shell "hilog -x" | grep "\[TTS\]"
# shows "pcm data buffered" / "system pcm segment ready" lines.
#
# Usage:
#   bash scripts/foreground_regression.sh [ROUNDS]
# Overridable env: HDC, HDC_HOME, HDC_TARGET, BUNDLE, ROUNDS, WORKSPACE,
#                  ACTIONS_LOG, HILOG_LOG, SWIPE_NEXT, SWIPE_BACK, TAP_XY.
set -u
WS="${WORKSPACE:-$(cd "$(dirname "$0")/.." && pwd)}"
cd "$WS" || exit 1
HDC="${HDC:-${HDC_HOME:-/c/sandbox/DevEco Studio/sdk/default/openharmony/toolchains}/hdc.exe}"
TARGET="${HDC_TARGET:-127.0.0.1:5555}"
BUNDLE="${BUNDLE:-legado.intrimple.com}"
T="-t $TARGET"
ACT="${ACTIONS_LOG:-scripts/_fg_actions.log}"
LOG="${HILOG_LOG:-scripts/_fg_hilog.log}"
ROUNDS="${1:-${ROUNDS:-30}}"
SWIPE_NEXT="${SWIPE_NEXT:-1050 1500 250 1500}"
SWIPE_BACK="${SWIPE_BACK:-250 1500 1050 1500}"
TAP_XY="${TAP_XY:-640 1400}"

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
  # manual page turn: swipe right-to-left (next page) then occasional back
  "$HDC" $T shell "uitest uiInput swipe $SWIPE_NEXT" >/dev/null 2>&1
  sleep 3
  if [ $((i % 5)) -eq 0 ]; then
    "$HDC" $T shell "uitest uiInput swipe $SWIPE_BACK" >/dev/null 2>&1
    sleep 2
  fi
  if [ $((i % 7)) -eq 0 ]; then
    # tap center to show/hide menu (exercise floating capsule overlap)
    "$HDC" $T shell "uitest uiInput click $TAP_XY" >/dev/null 2>&1
    sleep 1
    "$HDC" $T shell "uitest uiInput click $TAP_XY" >/dev/null 2>&1
  fi
  n=$("$HDC" $T shell "hilog -x" 2>/dev/null | grep -ac "\\[TTS\\]")
  log "round $i/$ROUNDS done ; [TTS] in live snapshot=$n"
  sleep 3
done
log "=== FINAL process ==="
"$HDC" $T shell "ps -ef" 2>/dev/null | grep -F -- "$BUNDLE" >> "$ACT" || true
log "capture stopped"
