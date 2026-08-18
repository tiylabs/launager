#!/bin/bash
# Release gate — run before EVERY release/version bump:
#   ./scripts/release-check.sh
#
# Stages: unit tests -> universal package -> smoke launch -> health checks -> cleanup.
# Exits non-zero on the first failure; a release only ships on ✅.
set -euo pipefail
cd "$(dirname "$0")/.."

APP="$PWD/dist/Launager.app"
CRASH_DIR="$HOME/Library/Logs/DiagnosticReports"

fail() {
    echo "❌ FAIL: $1"
    exit 1
}

BUILD_HIDDEN=0
HIDDEN_BUILD="$PWD/.build.release-check-hidden"
AUTOTEST_SET=0

restore_build() {
    if [ "$BUILD_HIDDEN" -eq 1 ] && [ -e "$HIDDEN_BUILD" ]; then
        mv "$HIDDEN_BUILD" "$PWD/.build"
        BUILD_HIDDEN=0
    fi
}

cleanup_smoke() {
    if [ "$AUTOTEST_SET" -eq 1 ]; then
        launchctl unsetenv LAUNAGER_AUTOTEST 2>/dev/null || true
        AUTOTEST_SET=0
    fi
    restore_build
}

echo "==> [1/4] swift test"
swift test 2>&1 | tail -2

echo "==> [2/4] package (universal)"
./scripts/make-app.sh universal

for bundle in \
    "$APP/Contents/Resources/Launager_BirthCore.bundle" \
    "$APP/Contents/Resources/Launager_BirthUI.bundle"; do
    [ -d "$bundle" ] || fail "app 内缺少本地化资源包：$bundle"
done

echo "==> [3/4] smoke launch"
# Quit any running instance (path-pinned so a stale /Applications copy
# can't hijack the name).
osascript -e "tell application \"$APP\" to quit" 2>/dev/null || true
pkill -x Launager 2>/dev/null || true
sleep 1

crashes_before=$(ls "$CRASH_DIR" 2>/dev/null | grep -c '^Launager-' || true)

# LAUNAGER_AUTOTEST=inspector drives the advanced table + inspector path —
# the route that once crashed on every click. launchctl setenv + open is
# mandatory: exec-ing the binary from a shell inherits its sandbox.
# Hide SwiftPM's build directory so the smoke launch proves that the app is
# self-contained and cannot fall back to an absolute .build resource path.
if [ -e "$HIDDEN_BUILD" ]; then
    fail "发现上一次 release-check 遗留的隐藏构建目录：$HIDDEN_BUILD"
fi
if [ -e "$PWD/.build" ]; then
    mv "$PWD/.build" "$HIDDEN_BUILD"
    BUILD_HIDDEN=1
    trap cleanup_smoke EXIT
fi
launchctl setenv LAUNAGER_AUTOTEST inspector
AUTOTEST_SET=1
open "$APP"
sleep 12
launchctl unsetenv LAUNAGER_AUTOTEST
AUTOTEST_SET=0
restore_build
trap - EXIT

echo "==> [4/4] health checks"
pid=$(pgrep -x Launager) || fail "进程未存活（启动 12 秒后已退出）"
echo "    进程存活 (PID $pid)"

# Main thread must be idle-parked in the event loop, not wedged.
idle=$(sample Launager 1 -mayDie 2>/dev/null | grep -c mach_msg2_trap || true)
[ "$idle" -ge 1 ] || fail "主线程未回到事件循环（疑似卡死）— 用 sample Launager 10 诊断"
echo "    主线程健康"

crashes_after=$(ls "$CRASH_DIR" 2>/dev/null | grep -c '^Launager-' || true)
[ "$crashes_after" -le "$crashes_before" ] || fail "冒烟期间产生了新的崩溃报告（$CRASH_DIR）"
echo "    零新崩溃"

# Cleanup: quit the smoke instance, undo the autotest's persisted
# selection, relaunch in normal mode.
osascript -e "tell application \"$APP\" to quit" 2>/dev/null || true
sleep 1
defaults write ai.tiy.launager sidebarSelection -string loginApps 2>/dev/null || true

echo "✅ release check passed — dist/Launager.app 可以发布"
