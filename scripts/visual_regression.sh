#!/usr/bin/env bash
# 阅读页视觉回归：抓一组固定状态的截图，供前后对比。
#
# 用法：
#   bash scripts/visual_regression.sh capture <输出目录>
#   bash scripts/visual_regression.sh diff <基线目录> <新目录>
#
# 环境变量覆盖：
#   HDC            hdc 可执行文件路径
#   HDC_TARGET     设备 connect-key（默认取 list targets 第一条）
#   BUNDLE         bundle 名（默认 legado.intrimple.com）
#   PYTHON         带 Pillow 的 python（默认 python3）
#
# 关键点：每一步都轮询 dumpLayout 确认界面真的到位了才截图，
# 否则书架卡片加载慢、目录拉取慢都会让「翻页前后」抓到不同页面，
# 断出来的 diff 全是假的。

set -uo pipefail

HDC="${HDC:-${HDC_HOME:-/c/sandbox/DevEco Studio/sdk/default/openharmony/toolchains}/hdc.exe}"
BUNDLE="${BUNDLE:-legado.intrimple.com}"
TARGET="${HDC_TARGET:-}"
WORKSPACE="${WORKSPACE:-$(cd "$(dirname "$0")/.." && pwd)}"
PYTHON="${PYTHON:-python3}"
DEVICE_DIR="/data/local/tmp"
STATE_JSON="$WORKSPACE/scripts/_vr_state.json"
TEXT_PY="$WORKSPACE/scripts/device_screen_text.py"

# 书架：底部四个 tab 都在
SHELF_RE='书架.*发现'
# 加载态 / 失败态文案：这些界面也可能带 "1/1"，不能当成可用的阅读页
LOADING_RE='正在打开书籍|正在获取目录|不再等待|正在加载|加载失败|请点击右上角'
PAGED_RE='[0-9]+/[0-9]+'
# 覆盖在阅读页之上的弹层：页码会透出来，所以必须单独识别并关掉
DIALOG_RE='已搜索.*个书源|换源|书源登录|目录.*共|缓存.*章'

if [ ! -x "$HDC" ]; then
  echo "hdc not found: $HDC" >&2
  exit 2
fi

if [ -z "$TARGET" ]; then
  TARGET="$("$HDC" list targets 2>/dev/null | tr -d '\r' | head -1)"
fi
if [ -z "$TARGET" ] || ! "$HDC" list targets 2>/dev/null | tr -d '\r' | grep -Fqx -- "$TARGET"; then
  echo "no usable device (target='$TARGET')" >&2
  "$HDC" list targets >&2
  exit 2
fi

H() { "$HDC" -t "$TARGET" "$@"; }
say() { echo "[$(date +%H:%M:%S)] $*"; }
tap() { H shell "uitest uiInput click $1 $2" >/dev/null 2>&1; }
swipe() { H shell "uitest uiInput swipe $1 $2 $3 $4 $5" >/dev/null 2>&1; }
key() { H shell "uitest uiInput keyEvent $1" >/dev/null 2>&1; }

screen_text() {
  H shell "uitest dumpLayout -p $DEVICE_DIR/_vr_layout.json" >/dev/null 2>&1
  H file recv "$DEVICE_DIR/_vr_layout.json" "$STATE_JSON" >/dev/null 2>&1
  "$PYTHON" "$TEXT_PY" "$STATE_JSON" 2>/dev/null
}

wait_until() {
  local pattern="$1" timeout="${2:-40}" desc="${3:-condition}"
  local i=0
  while [ "$i" -lt "$timeout" ]; do
    if screen_text | grep -Eq -- "$pattern"; then
      say "ready: $desc"
      return 0
    fi
    sleep 1
    i=$((i + 1))
  done
  echo "TIMEOUT waiting for $desc (${timeout}s): $pattern" >&2
  return 1
}

reader_ready() {
  local t
  t="$(screen_text)"
  if echo "$t" | grep -Eq "$LOADING_RE"; then
    return 1
  fi
  # 有弹层时即使页码可见也不算就绪
  if echo "$t" | grep -Eq "$DIALOG_RE"; then
    return 1
  fi
  echo "$t" | grep -Eq "$PAGED_RE"
}

# 已经明确失败/放弃的界面，不必再等满超时
reader_failed() {
  screen_text | grep -Eq '加载失败|不再等待|没有可用'
}

# 弹层（例如换源对话框）盖在阅读页上时页码仍然可见，会污染截图，
# 需要先按返回键关掉。返回 true 表示「当前有弹层」。
dialog_open() {
  screen_text | grep -Eq "$DIALOG_RE"
}

dismiss_dialogs() {
  local i=0
  while [ "$i" -lt 3 ]; do
    if ! dialog_open; then
      return 0
    fi
    say "dismissing overlay dialog"
    key Back
    sleep 2
    i=$((i + 1))
  done
  ! dialog_open
}

shot() {
  local out="$1"
  local remote="$DEVICE_DIR/_vr_shot.jpeg"
  H shell "snapshot_display -f $remote" >/dev/null 2>&1
  H file recv "$remote" "$out" >/dev/null 2>&1
  if [ ! -s "$out" ]; then
    echo "capture failed: $out" >&2
    return 1
  fi
  say "saved $(basename "$out") ($(wc -c <"$out") bytes)"
}

open_reader() {
  say "restart app"
  H shell "aa force-stop $BUNDLE" >/dev/null 2>&1
  sleep 2
  H shell "aa start -a EntryAbility -b $BUNDLE" >/dev/null 2>&1
  sleep 4
  wait_until "$SHELF_RE" 60 "bookshelf" || return 1

  # 依次试前几张卡片：不同书的目录缓存状态不同，
  # 有的要联网拉目录会长时间停在加载页，换一本已缓存的即可。
  local taps="700:440 700:980 700:1720 700:2300"
  local cand x y i
  for cand in $taps; do
    x="${cand%%:*}"
    y="${cand##*:}"
    say "try book at $x,$y"
    tap "$x" "$y"
    i=0
    while [ "$i" -lt 30 ]; do
      if reader_ready; then
        say "reader ready (page indicator present)"
        sleep 2
        return 0
      fi
      if dialog_open; then
        say "overlay dialog on top of reader, dismissing"
        dismiss_dialogs
        sleep 2
        i=$((i + 2))
        continue
      fi
      if reader_failed; then
        say "book at $y reported load failure"
        break
      fi
      sleep 2
      i=$((i + 2))
    done
    say "book at $y did not open, go back"
    key Back
    sleep 3
    wait_until "$SHELF_RE" 30 "bookshelf" || return 1
  done
  echo "TIMEOUT: no book could reach reader page" >&2
  return 1
}

case "${1:-}" in
capture)
  OUT="${2:?usage: capture <outdir>}"
  mkdir -p "$OUT"
  open_reader || exit 1
  sleep 2
  shot "$OUT/01-reader.jpeg"

  swipe 1050 1500 250 1500 400
  sleep 5
  dismiss_dialogs
  shot "$OUT/02-page-next.jpeg"

  swipe 250 1500 1050 1500 400
  sleep 5
  dismiss_dialogs
  shot "$OUT/03-page-prev.jpeg"

  tap 640 1400
  sleep 3
  shot "$OUT/04-menu.jpeg"

  # The quick-TTS button only exists while the reader menu is open; with the
  # menu closed that region is one of the 3x3 page-turn tap zones.
  tap 1133 2181
  sleep 6
  shot "$OUT/05-tts.jpeg"

  say "capture done -> $OUT"
  ;;

diff)
  BASE="${2:?usage: diff <baselineDir> <newDir>}"
  NEW="${3:?usage: diff <baselineDir> <newDir>}"
  "$PYTHON" "$WORKSPACE/scripts/visual_diff.py" "$BASE" "$NEW"
  ;;

*)
  echo "usage: $0 capture <outdir> | diff <baselineDir> <newDir>" >&2
  exit 2
  ;;
esac
