#!/usr/bin/env bash
# 変更後の検証を1コマンドにまとめる: gdformat → gdlint → ヘッドレステスト → 起動スモーク → サーバー → オンライン。
# 引数なし: git で変更のある .gd だけを整形・lint する。 --all: scripts/ と tools/ の全 .gd。
# 出力は要点だけに絞る(ログ全文は logs/check_*.log)。
set -u
GODOT="${GODOT:-C:/Users/omezi/Documents/Godot_v4.6.2-stable_win64_console.exe}"
# 1回の実行の上限(秒)。コンパイルに失敗したスクリプトは quit() まで届かず終わらないため。
GODOT_TIMEOUT="${GODOT_TIMEOUT:-600}"
PY_SCRIPTS="C:/Users/omezi/AppData/Roaming/Python/Python314/Scripts"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
mkdir -p logs

if [ "${1:-}" = "--all" ]; then
  FILES=$(git ls-files -co --exclude-standard 'scripts/*.gd' 'tools/*.gd' 'tools/**/*.gd')
else
  FILES=$( (git diff --name-only; git diff --cached --name-only; git ls-files --others --exclude-standard) | sort -u | grep '\.gd$' | while read -r f; do [ -f "$f" ] && echo "$f"; done)
fi

status=0
if [ -n "$FILES" ]; then
  echo "== gdformat/gdlint ($(echo "$FILES" | wc -l) files)"
  "$PY_SCRIPTS/gdformat.exe" $FILES >/dev/null 2>&1 || true
  "$PY_SCRIPTS/gdlint.exe" $FILES > logs/check_lint.log 2>&1 || { status=1; cat logs/check_lint.log; }
else
  echo "== gdformat/gdlint: 変更された .gd なし"
fi

# class_name の登録(.godot はgit管理外)が古いと、テストはコンパイルに失敗したまま固まる。足りなければ登録し直す。
CLASS_CACHE=.godot/global_script_class_cache.cfg
missing=$(git ls-files -co --exclude-standard 'scripts/*.gd' 'tools/*.gd' 'tools/**/*.gd' | xargs -r grep -h '^class_name ' | awk '{print $2}' | while read -r c; do grep -q "\"class\": &\"$c\"" "$CLASS_CACHE" 2>/dev/null || echo "$c"; done)
if [ -n "$missing" ]; then
  echo "== class_name の登録を更新 ($(echo "$missing" | wc -l) 件)"
  timeout "$GODOT_TIMEOUT" "$GODOT" --headless --path . --import > logs/check_import.log 2>&1
fi

echo "== headless tests"
timeout "$GODOT_TIMEOUT" "$GODOT" --headless --path . --script res://tools/tests/run_tests.gd > logs/check_tests.log 2>&1
grep -E "tests passed|FAILED|SCRIPT ERROR|Parse Error" logs/check_tests.log | head -20
grep -qE "FAILED|SCRIPT ERROR|Parse Error" logs/check_tests.log && status=1
grep -q "tests passed" logs/check_tests.log || status=1

echo "== startup smoke"
# メインシーンが無いと Godot はエラーのあと終了しないため、未設定の間は飛ばす。
if ! grep -q '^run/main_scene=' project.godot; then
  echo "skip(run/main_scene 未設定)"
else
  timeout "$GODOT_TIMEOUT" "$GODOT" --headless --path . --quit-after 60 > logs/check_smoke.log 2>&1
  if grep -E "SCRIPT ERROR|Parse Error|Failed to load" logs/check_smoke.log | head -10 | grep -q .; then
    grep -E "SCRIPT ERROR|Parse Error|Failed to load" logs/check_smoke.log | head -10
    status=1
  else
    echo "ok"
  fi
fi

echo "== server (export_rules → tsc → node --test)"
if [ ! -d server/node_modules ]; then
  echo "NG: server/node_modules が無い(cd server && npm install)"
  status=1
else
  timeout "$GODOT_TIMEOUT" "$GODOT" --headless --path . --script res://tools/export_rules.gd > logs/check_export.log 2>&1     || { status=1; grep -vE "^Godot Engine|^$" logs/check_export.log | head -5; }
  if (cd server && npx tsc --noEmit && node --test test/*.test.ts) > logs/check_server.log 2>&1; then
    echo "ok"
  else
    status=1
    grep -E "✖|error|FAIL" logs/check_server.log | head -10
  fi
fi

# 通信に関わる変更があるときだけ、wrangler dev を立てて2クライアントで試合を通す(1分ほど掛かる)。
echo "== online (wrangler dev + 2 clients)"
ONLINE_PORT="${ONLINE_PORT:-8788}"
CHANGED=$( (git diff --name-only HEAD; git ls-files --others --exclude-standard) | sort -u)
if [ "${1:-}" != "--all" ] && ! echo "$CHANGED" | grep -qE '^(server/|scripts/net/|scripts/logic/|data/|tools/online_match_test\.gd)'; then
  echo "skip(通信に関わる変更なし)"
elif [ -d server/node_modules ]; then
  (cd server && WRANGLER_SEND_METRICS=false exec npx wrangler dev --port "$ONLINE_PORT" --ip 127.0.0.1) > logs/check_wrangler.log 2>&1 &
  WRANGLER_PID=$!
  for _ in $(seq 1 60); do curl -s "http://127.0.0.1:$ONLINE_PORT/" > /dev/null && break; sleep 0.5; done
  timeout "$GODOT_TIMEOUT" "$GODOT" --headless --path . --script res://tools/online_match_test.gd -- --server="ws://127.0.0.1:$ONLINE_PORT" > logs/check_online.log 2>&1
  grep -E "online tests|FAILED|SCRIPT ERROR|Parse Error" logs/check_online.log | head -20
  grep -q "online tests passed" logs/check_online.log || status=1
  WINPID=$(cat "/proc/$WRANGLER_PID/winpid" 2>/dev/null)
  if [ -n "$WINPID" ]; then taskkill //F //T //PID "$WINPID" > /dev/null 2>&1; else kill "$WRANGLER_PID" 2> /dev/null; fi
fi

[ $status -eq 0 ] && echo "== ALL OK" || echo "== NG (logs/check_*.log)"
exit $status
