#!/usr/bin/env bash
# tui-harness/mux.sh の入力出現確認（submit / cmux の run）の回帰検証。
# herdr / cmux のモック（mock/）を PATH の先頭に置き、実際の mux.sh の経路を通して
# 終了コードと Enter 送信の有無を確かめる。要 bash・perl・python3。
#
# 使い方: bash tests/tui-harness/run.sh [検証対象 mux.sh のパス]
#   既定はリポジトリの tui-harness/mux.sh。全ケース合格で exit 0。
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
MUX=${1:-$HERE/../../tui-harness/mux.sh}
export PATH="$HERE/mock:$PATH"
fail=0
MOCK_DIR=""
# 中断時も含め、作成済みの一時ディレクトリを削除する。
cleanup() { [ -n "$MOCK_DIR" ] && rm -rf "$MOCK_DIR"; MOCK_DIR=""; }
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

LONG='[job-1] done /home/example/projects/sample-app/.work/job-1/report-job-1-t7-2.md'
SYM='sym .*+?[](){}|^$\ 終わり /tmp/a b'
JA='完了しました。報告は /tmp/報告書 にあります'
LAUNCH="cd '/home/example/projects/sample-app' && some-harness --model example-model"

# check <バックエンド> <サブコマンド> <名前> <期待終了コード> <期待 Enter（有/無）> <MOCK_MODE> <MOCK_WIDTH> <テキスト> [事前画面]
# Enter 有 = 送信キーの記録が Enter だけ（herdr は Enter、cmux は enter）で1件以上、無 = 記録なし。
# それ以外のキーが記録されていれば「他キー」として不合格にする。
check() {
  local backend=$1 sub=$2 name=$3 want_rc=$4 want_enter=$5 rc enter enter_key=Enter
  [ "$backend" = cmux ] && enter_key=enter
  export MOCK_DIR MOCK_MODE=$6 MOCK_WIDTH=$7
  MOCK_DIR=$(mktemp -d) || { echo "mktemp に失敗" >&2; exit 1; }
  printf '%s' "${9:-}" > "$MOCK_DIR/screen"
  : > "$MOCK_DIR/keys"
  if [ "$backend" = herdr ]; then
    HERDR_ENV=1 "$MUX" "$sub" p1 "$8" >/dev/null 2>&1; rc=$?
  else
    HERDR_ENV=0 CMUX_SOCKET_PATH=mock "$MUX" "$sub" p1 "$8" >/dev/null 2>&1; rc=$?
  fi
  if [ ! -s "$MOCK_DIR/keys" ]; then
    enter=無
  elif grep -v -x -F -- "$enter_key" "$MOCK_DIR/keys" >/dev/null; then
    enter=他キー
  else
    enter=有
  fi
  cleanup
  if [ "$rc" = "$want_rc" ] && [ "$enter" = "$want_enter" ]; then
    echo "PASS [$backend $sub] $name (rc=$rc Enter=$enter)"
  else
    echo "FAIL [$backend $sub] $name (rc=$rc Enter=$enter, 期待 rc=$want_rc Enter=$want_enter)"
    fail=1
  fi
}

for b in herdr cmux; do
  check $b submit "空白位置での折り返し"         0 有 word   60 "$LONG"
  check $b submit "単語・パス途中の折り返し"     0 有 hard   20 "$LONG"
  check $b submit "折り返しなしの短い入力"       0 有 word   60 "hello"
  check $b submit "日本語の途中での折り返し"     0 有 hard   20 "$JA"
  check $b submit "正規表現記号"                 0 有 word   60 "$SYM"
  check $b submit "先頭がハイフンの入力が届く"   0 有 word   60 "-foo bar"
  check $b submit "入力が届かない"               3 無 drop   60 "$LONG"
  check $b submit "短い接頭辞だけが画面にある"   3 無 drop   60 "$LONG" $'❯ [job-1] done\n'
  check $b submit "本文の空白が画面で消えている" 3 無 squash 60 "$LONG"
  check $b submit "先頭がハイフンの入力が届かない" 3 無 drop 60 "--help" $'❯ unrelated\n'
  check $b submit "探針が perl コード風で届かない" 3 無 drop 60 '-e;BEGIN{print qq(EXECUTED);exit 0}' $'❯ unrelated\n'
done
check cmux run "シェル入力行で途中折り返し" 0 有 shell 20 "$LAUNCH" $'$ \n'
check cmux run "コマンド文字列が届かない"   1 無 drop  20 "$LAUNCH" $'$ \n'
exit $fail
