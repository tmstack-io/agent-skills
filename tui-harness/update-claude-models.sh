#!/usr/bin/env bash
# models/claude.txt（claude ペイン起用の静的モデル一覧）を自動収集して書き換える。
#
# 使い方:
#   update-claude-models.sh
#
# 手順:
#   1. 公式ドキュメント「Model deprecations」の Model status 表（Markdown 版）を取得し、
#      Retired 以外（Active / Legacy / Deprecated）の API モデル名を候補とする。
#   2. 候補ごとに claude CLI を -p でツールなし起動し、応答が返るものだけを採用する
#      （限定提供モデル等、実行アカウントで使えない ID を一覧に載せないため）。
#   3. 採用分で models/claude.txt を置き換え、追加・削除・不採用の ID を出力する。
# 取得・解析・起動確認の環境が整わない場合は、一覧を書き換えずに非0で終了する。

set -u -o pipefail

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
MODELS_FILE="$SCRIPT_DIR/models/claude.txt"
STATUS_URL="https://platform.claude.com/docs/en/about-claude/model-deprecations.md"
PROBE_PROMPT="Reply with exactly: OK"

die() { echo "$*" >&2; exit 1; }

TIMEOUT_BIN=$(command -v gtimeout || command -v timeout) \
  || die "timeout 未導入 (macOS は brew install coreutils)"
command -v curl >/dev/null 2>&1 || die "curl 未導入"
command -v claude >/dev/null 2>&1 || die "claude 未導入"
"$TIMEOUT_BIN" 15 claude auth status >/dev/null 2>&1 \
  || die "claude の認証確認に失敗（claude auth login を確認）"

WORK_DIR=$(mktemp -d) || die "作業ディレクトリを作成できない"
trap 'rm -rf "$WORK_DIR"' EXIT

page=$(curl -fsSL -m 30 "$STATUS_URL") || die "提供状況ページの取得に失敗: $STATUS_URL"

# "## Model status" 節の最初の表から、1列目がモデル ID・2列目が Retired 以外の行を抜く。
# 節や表の形式が変わって1件も取れない場合は、黙って空一覧にせず失敗させる。
candidates=$(printf '%s\n' "$page" | awk -F'|' '
  /^## / { in_section = ($0 ~ /^## Model status[[:space:]]*$/); next }
  !in_section || !/^\|/ { next }
  {
    id = $2; state = $3
    gsub(/[[:space:]]/, "", id); gsub(/^[[:space:]]+|[[:space:]]+$/, "", state)
    if (id ~ /^claude-[a-z0-9]+(-[a-z0-9]+)+$/ && state != "Retired") print id
  }
')
[ -n "$candidates" ] || die "提供状況表からモデル ID を抽出できない（ページ形式の変更を確認）: $STATUS_URL"

# 起動確認はプロジェクト外の空ディレクトリで行い、プロジェクトの CLAUDE.md 等を読ませない。
accepted=()
rejected=()
while IFS= read -r id; do
  if out=$(cd "$WORK_DIR" && "$TIMEOUT_BIN" 120 claude -p --model "$id" --tools "" \
      --disable-slash-commands --strict-mcp-config "$PROBE_PROMPT" 2>&1 </dev/null) \
      && [ -n "$out" ]; then
    accepted+=("$id")
  else
    rejected+=("$id: $(printf '%s' "$out" | head -n1 | cut -c1-160)")
  fi
done <<<"$candidates"

[ "${#accepted[@]}" -gt 0 ] || die "起動確認を通ったモデルが無い（認証・ネットワークを確認）。一覧は変更していない"

[ -r "$MODELS_FILE" ] || die "既存の一覧を読めない: $MODELS_FILE"
old_ids=$(awk '!/^#/' "$MODELS_FILE")
tmp_file="$WORK_DIR/claude.txt"
{
  printf '# claude ペイン起用の静的モデル一覧（update-claude-models.sh が生成。取得日: %s）。\n' "$(date +%Y-%m-%d)"
  printf '# 取得元: %s の Retired 以外のうち、claude CLI で起動確認できた ID。\n' "$STATUS_URL"
  printf '%s\n' "${accepted[@]}"
} >"$tmp_file"
mv "$tmp_file" "$MODELS_FILE" || die "一覧の書き込みに失敗: $MODELS_FILE"

new_ids=$(printf '%s\n' "${accepted[@]}")
echo "更新: $MODELS_FILE（${#accepted[@]} 件）"
comm -13 <(printf '%s\n' "$old_ids" | sort) <(printf '%s\n' "$new_ids" | sort) | sed 's/^/  追加: /'
comm -23 <(printf '%s\n' "$old_ids" | sort) <(printf '%s\n' "$new_ids" | sort) | sed '/^$/d; s/^/  削除: /'
for r in ${rejected[@]+"${rejected[@]}"}; do
  echo "  不採用（起動不可）: $r"
done
