#!/usr/bin/env bash
# ハーネスカタログの正本 — 候補 CLI の疎通確認（probe）とモデル一覧（models）。
# ハーネスの実行は TUI ペイン起用（SKILL.md ＋ transports/<CLI名>-tui.md）のみで
# 行い、本スクリプトは実行を担わない。
#
# 使い方:
#   catalog.sh probe
#       候補 CLI ごとに「名前<TAB>ok|excluded<TAB>詳細」を1行ずつ出力する。
#       ok の詳細にはモデル一覧等の補足を含める。
#   catalog.sh models <cli>
#       当該 CLI の指定可能モデルを1行1件で出力する（モデル指定の検証の正本）。
#       取得できない場合は理由を stderr に出して非0で終了する。
#   catalog.sh family <cli> <model-spec>
#       CLI 固有の起動指定から、モデル系統（モデル名の先頭ファミリートークン。
#       バージョン・reasoning effort 等は含めない）を出力する。
#       起動時までモデルが決まらない指定は理由を stderr に出して非0で終了する。
#   catalog.sh validate <cli> <model-spec>
#       起動指定が当該 CLI の現在の一覧・設定値で有効かを検証する。
#       <モデル>@<エフォート> 形はエフォート部の許容値も照合する（codex は
#       codex debug models、claude は models/claude-efforts.txt が正本）。
#       effort の設定手段が無い CLI への @ 付き指定は非0で終了する。
#
# 新しい CLI の追加: models_<名前> / validate_<名前> / probe_<名前> を書いて各ディスパッチへ
# 分岐を足す（family は共通の model_family で足り、CLI 固有の接頭辞剥ぎが要る場合のみ
# family_<名前> を書く）。起用には対話 TUI の実測検証と
# transports/<CLI名>-tui.md の作成も必要（SKILL.md のカタログ規定）。

set -u -o pipefail

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
CLAUDE_MODELS_FILE="$SCRIPT_DIR/models/claude.txt"
CLAUDE_EFFORTS_FILE="$SCRIPT_DIR/models/claude-efforts.txt"

TIMEOUT_BIN=$(command -v gtimeout || command -v timeout) || {
  echo "timeout 未導入 (macOS は brew install coreutils)" >&2
  exit 127
}

# --- モデル一覧（1行1件。取得不可は理由を stderr に出して非0終了） ---

codex_models_json() {
  command -v codex >/dev/null 2>&1 || { echo "codex 未導入" >&2; return 1; }
  command -v jq >/dev/null 2>&1 || { echo "jq 未導入のためモデル一覧を取得できない" >&2; return 1; }
  local out json
  out=$("$TIMEOUT_BIN" 60 codex debug models 2>&1) \
    || { echo "疎通失敗: $(printf '%s' "$out" | head -n1)" >&2; return 1; }
  json=$(printf '%s\n' "$out" | sed -n '/^[[:space:]]*{.*"models"/,$p')
  [ -n "$json" ] || { echo "モデル一覧の JSON が見つからない: $(printf '%s' "$out" | head -n1)" >&2; return 1; }
  printf '%s\n' "$json"
}

models_codex() {
  local json parsed
  json=$(codex_models_json) || return 1
  parsed=$(printf '%s\n' "$json" | jq -r '.models[] | select(.visibility == "list") | .slug' 2>&1) \
    || { echo "モデル一覧の解析に失敗: $(printf '%s' "$parsed" | head -n1)" >&2; return 1; }
  [ -n "$parsed" ] || { echo "モデル一覧が空" >&2; return 1; }
  printf '%s\n' "$parsed"
}

models_cursor_agent() {
  command -v cursor-agent >/dev/null 2>&1 || { echo "cursor-agent 未導入" >&2; return 1; }
  local out parsed
  out=$("$TIMEOUT_BIN" 60 cursor-agent --list-models 2>&1) \
    || { echo "疎通失敗: $(printf '%s' "$out" | head -n1)" >&2; return 1; }
  printf '%s' "$out" | grep -q 'No models available' \
    && { echo "認証切れ（cursor-agent login が必要）" >&2; return 1; }
  parsed=$(printf '%s\n' "$out" | grep -E '^[A-Za-z0-9][A-Za-z0-9._-]* - ' | cut -d' ' -f1)
  [ -n "$parsed" ] || { echo "モデル一覧の解析に失敗（cursor-agent --list-models の出力形式変更の可能性）" >&2; return 1; }
  printf '%s\n' "$parsed"
}

models_agy() {
  command -v agy >/dev/null 2>&1 || { echo "agy 未導入" >&2; return 1; }
  local out parsed
  out=$("$TIMEOUT_BIN" 60 agy models 2>&1)
  if [ $? -ne 0 ] || [ -z "$out" ]; then
    echo "$(printf '%s' "$out" | grep -im1 'error' || echo '疎通失敗')" >&2
    return 1
  fi
  # 出力は「slug のみ」（旧形式）と「slug<TAB>表示名」（新形式）のいずれもありうる。
  # タブ区切りの第1フィールドを共通の抽出対象にする（旧形式は行全体がそのまま第1
  # フィールドになるため同じ規則で通る）。見出し行（"Fetching available models..."
  # 等）は空白を含み regex にマッチしないため自然に落ちる。
  parsed=$(printf '%s\n' "$out" | awk -F'\t' '$1 ~ /^[A-Za-z0-9][A-Za-z0-9._-]+$/ {print $1}')
  [ -n "$parsed" ] || { echo "モデル一覧の解析に失敗（agy models の出力形式変更の可能性）" >&2; return 1; }
  printf '%s\n' "$parsed"
}

models_grok() {
  command -v grok >/dev/null 2>&1 || { echo "grok 未導入" >&2; return 1; }
  local out parsed
  out=$("$TIMEOUT_BIN" 60 grok models 2>&1) \
    || { echo "$(printf '%s' "$out" | grep -im1 'error\|log' || echo '疎通失敗')" >&2; return 1; }
  parsed=$(printf '%s\n' "$out" | grep -E '^\s+\*' | awk '{print $2}')
  [ -n "$parsed" ] || { echo "モデル一覧の解析に失敗（grok models の出力形式変更の可能性）" >&2; return 1; }
  printf '%s\n' "$parsed"
}

models_claude() {
  [ -r "$CLAUDE_MODELS_FILE" ] \
    || { echo "Claude モデル一覧を読めない: $CLAUDE_MODELS_FILE" >&2; return 1; }

  awk '
    /^#/ { next }
    $0 !~ /^claude-[a-z0-9]+(-[a-z0-9]+)+$/ {
      print "Claude モデル一覧の行が不正: " $0 > "/dev/stderr"
      exit 1
    }
    seen[$0]++ {
      print "Claude モデル一覧に重複がある: " $0 > "/dev/stderr"
      exit 1
    }
    { print; count++ }
    END {
      if (!count) {
        print "Claude モデル一覧が空" > "/dev/stderr"
        exit 1
      }
    }
  ' "$CLAUDE_MODELS_FILE"
}

efforts_claude() {
  [ -r "$CLAUDE_EFFORTS_FILE" ] \
    || { echo "Claude effort 一覧を読めない: $CLAUDE_EFFORTS_FILE" >&2; return 1; }
  local out
  out=$(grep -v '^#' "$CLAUDE_EFFORTS_FILE" | grep -v '^[[:space:]]*$')
  [ -n "$out" ] || { echo "Claude effort 一覧が空: $CLAUDE_EFFORTS_FILE" >&2; return 1; }
  printf '%s\n' "$out"
}

resolve_claude_model() {
  local spec=$1 ids
  if [[ "$spec" == *"[1m]" ]]; then
    spec=${spec:0:${#spec}-4}
  fi
  [ -n "$spec" ] || { echo "Claude モデル名が空" >&2; return 1; }

  ids=$(models_claude) || return 1
  printf '%s\n' "$ids" | grep -Fxq "$spec" || {
    echo "Claude モデル一覧に一致する ID がない: ${spec}（$CLAUDE_MODELS_FILE を更新するか、掲載 ID を指定）" >&2
    return 1
  }
  printf '%s\n' "$spec"
}

# --- モデル系統（モデル名の先頭ファミリートークン。バージョン・実行設定は含めない） ---

model_family() {
  local spec=$1 token
  # 表示名の空白は区切りとして扱う（例: "Claude Opus 5" → claude）
  spec=$(printf '%s' "$spec" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')
  if [[ "$spec" == *"[1m]" ]]; then
    spec=${spec:0:${#spec}-4}
  fi
  [ -n "$spec" ] || { echo "モデル指定が空" >&2; return 1; }
  case "$spec" in
    auto|auto[-._@]*) echo "実効モデルを起動前に一意確定できない指定: $1" >&2; return 1 ;;
  esac
  token=${spec%%[-._@]*}
  [ -n "$token" ] || { echo "モデル系統を取り出せない指定: $1" >&2; return 1; }
  printf '%s\n' "$token"
}

family_cursor_agent() {
  local spec
  spec=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')
  case "$spec" in
    cursor-*) spec=${spec#cursor-} ;;
  esac
  model_family "$spec"
}

family_claude() {
  # claude CLI が提供するのは Anthropic モデルのみのため、指定値によらず系統は claude。
  # 起動指定としての実在検証は validate_claude（models/claude.txt 照合）が担う。
  printf 'claude\n'
}

# --- 起動指定の検証（一覧照合と CLI 固有設定の許容値） ---

validate_codex() {
  local spec=$1 slug effort json listed_models allowed_efforts
  spec=$(printf '%s' "$spec" | tr '[:upper:]' '[:lower:]')
  case "$spec" in
    auto|auto@*|@*|*@|*@*@*) echo "実効モデルを起動前に一意確定できない指定: $spec" >&2; return 1 ;;
  esac
  slug=${spec%%@*}

  listed_models=$(models_codex) || return 1
  printf '%s\n' "$listed_models" | grep -Fxq "$slug" \
    || { echo "指定可能モデルの一覧にない slug: $slug" >&2; return 1; }

  if [ "$spec" != "$slug" ]; then
    effort=${spec#*@}
    json=$(codex_models_json) || return 1
    allowed_efforts=$(printf '%s\n' "$json" | jq -r --arg slug "$slug" \
      '.models[] | select(.slug == $slug) | .supported_reasoning_levels[]?.effort' 2>/dev/null)
    [ -n "$allowed_efforts" ] \
      || { echo "reasoning effort の一覧を取得できないモデル: $slug" >&2; return 1; }
    printf '%s\n' "$allowed_efforts" | grep -Fxq "$effort" \
      || { echo "未対応の reasoning effort: ${slug}@${effort}（候補: $(printf '%s\n' "$allowed_efforts" | paste -sd, -)）" >&2; return 1; }
  fi
}

validate_cursor_agent() {
  local spec=$1 listed_models
  case "$spec" in
    *@*) echo "reasoning effort の設定手段が無い CLI: cursor-agent（@ 指定を外す）" >&2; return 1 ;;
  esac
  family_cursor_agent "$spec" >/dev/null || return 1
  listed_models=$(models_cursor_agent) || return 1
  printf '%s\n' "$listed_models" | grep -Fxq "$spec" \
    || { echo "指定可能モデルの一覧にない値: $spec" >&2; return 1; }
}

validate_agy() {
  local spec=$1 listed_models
  case "$spec" in
    *@*) echo "reasoning effort の設定手段が無い CLI: agy（@ 指定を外す）" >&2; return 1 ;;
  esac
  model_family "$spec" >/dev/null || return 1
  listed_models=$(models_agy) || return 1
  printf '%s\n' "$listed_models" | grep -Fxq "$spec" \
    || { echo "指定可能モデルの一覧にない値: $spec" >&2; return 1; }
}

validate_claude() {
  local spec=$1 model effort allowed
  case "$spec" in
    @*|*@|*@*@*) echo "エフォート指定の形式が不正: $spec" >&2; return 1 ;;
  esac
  model=${spec%%@*}
  resolve_claude_model "$model" >/dev/null || return 1
  if [ "$spec" != "$model" ]; then
    effort=${spec#*@}
    allowed=$(efforts_claude) || return 1
    printf '%s\n' "$allowed" | grep -Fxq "$effort" \
      || { echo "未対応の reasoning effort: ${model}@${effort}（候補: $(printf '%s\n' "$allowed" | paste -sd, -)）" >&2; return 1; }
  fi
}

validate_grok() {
  local spec=$1 listed_models
  case "$spec" in
    *@*) echo "reasoning effort の設定手段が無い CLI: grok（@ 指定を外す）" >&2; return 1 ;;
  esac
  model_family "$spec" >/dev/null || return 1
  listed_models=$(models_grok) || return 1
  printf '%s\n' "$listed_models" | grep -Fxq "$spec" \
    || { echo "指定可能モデルの一覧にない値: $spec" >&2; return 1; }
}

# --- 疎通確認（probe の1行は models_* の成否と CLI 固有の注記から組み立てる） ---

join_lines() { paste -sd, -; }

probe_codex() {
  command -v codex >/dev/null 2>&1 || { printf 'codex\texcluded\t未導入\n'; return; }
  "$TIMEOUT_BIN" 60 codex login status >/dev/null 2>&1 \
    || { printf 'codex\texcluded\t認証切れ（codex login が必要）\n'; return; }
  local note='reasoning effort は <slug>@<effort> 形で指定'
  local out
  if out=$(models_codex 2>&1); then
    printf 'codex\tok\tmodels: %s ／ %s\n' "$(printf '%s\n' "$out" | join_lines)" "$note"
  else
    printf 'codex\texcluded\tモデル一覧取得不可（%s）／ %s\n' \
      "$(printf '%s' "$out" | head -n1)" "$note"
  fi
}

probe_cursor_agent() {
  command -v cursor-agent >/dev/null 2>&1 || { printf 'cursor-agent\texcluded\t未導入\n'; return; }
  local out
  if out=$(models_cursor_agent 2>&1); then
    printf 'cursor-agent\tok\tmodels: %s\n' "$(printf '%s\n' "$out" | join_lines)"
  else
    printf 'cursor-agent\texcluded\t%s\n' "$(printf '%s' "$out" | head -n1 | cut -c1-160)"
  fi
}

probe_agy() {
  command -v agy >/dev/null 2>&1 || { printf 'agy\texcluded\t未導入\n'; return; }
  local out
  if out=$(models_agy 2>&1); then
    printf 'agy\tok\tmodels: %s\n' "$(printf '%s\n' "$out" | join_lines)"
  else
    printf 'agy\texcluded\t%s\n' "$(printf '%s' "$out" | head -n1 | cut -c1-160)"
  fi
}

probe_claude() {
  command -v claude >/dev/null 2>&1 || { printf 'claude\texcluded\t未導入\n'; return; }
  local auth out
  auth=$("$TIMEOUT_BIN" 15 claude auth status 2>/dev/null) \
    || { printf 'claude\texcluded\t認証確認失敗（claude auth login を確認）\n'; return; }
  printf '%s\n' "$auth" | grep -Eq '"loggedIn"[[:space:]]*:[[:space:]]*true' \
    || { printf 'claude\texcluded\t認証切れ（claude auth login が必要）\n'; return; }
  if out=$(models_claude 2>&1); then
    printf 'claude\tok\tmodels: %s ／ API 取得済み静的一覧（models/claude.txt）／ reasoning effort は <モデル>@<エフォート> 形で指定（許容値: models/claude-efforts.txt）\n' "$(printf '%s\n' "$out" | join_lines)"
  else
    printf 'claude\texcluded\t%s\n' "$(printf '%s' "$out" | head -n1 | cut -c1-160)"
  fi
}

probe_grok() {
  command -v grok >/dev/null 2>&1 || { printf 'grok\texcluded\t未導入\n'; return; }
  local out
  if out=$(models_grok 2>&1); then
    printf 'grok\tok\tmodels: %s\n' "$(printf '%s\n' "$out" | join_lines)"
  else
    printf 'grok\texcluded\t%s\n' "$(printf '%s' "$out" | head -n1 | cut -c1-160)"
  fi
}

case "${1:-}" in
  probe)
    probe_codex
    probe_cursor_agent
    probe_agy
    probe_claude
    probe_grok
    ;;
  models)
    [ $# -eq 2 ] || { echo "usage: catalog.sh models <cli>" >&2; exit 2; }
    case "$2" in
      codex)        models_codex ;;
      cursor-agent) models_cursor_agent ;;
      agy)          models_agy ;;
      claude)       models_claude ;;
      grok)         models_grok ;;
      *) echo "カタログ外の CLI: $2（probe/models に分岐を追加し、transports を検証してから使う）" >&2; exit 2 ;;
    esac
    ;;
  family)
    [ $# -eq 3 ] || { echo "usage: catalog.sh family <cli> <model-spec>" >&2; exit 2; }
    case "$2" in
      codex)        model_family "$3" ;;
      cursor-agent) family_cursor_agent "$3" ;;
      agy)          model_family "$3" ;;
      claude)       family_claude ;;
      grok)         model_family "$3" ;;
      *) echo "カタログ外の CLI: $2（モデル系統を確定できない）" >&2; exit 2 ;;
    esac
    ;;
  validate)
    [ $# -eq 3 ] || { echo "usage: catalog.sh validate <cli> <model-spec>" >&2; exit 2; }
    case "$2" in
      codex)        validate_codex "$3" ;;
      cursor-agent) validate_cursor_agent "$3" ;;
      agy)          validate_agy "$3" ;;
      claude)       validate_claude "$3" ;;
      grok)         validate_grok "$3" ;;
      *) echo "カタログ外の CLI: $2（モデル指定を検証できない）" >&2; exit 2 ;;
    esac
    ;;
  *)
    echo "usage: catalog.sh probe | catalog.sh models <cli> | catalog.sh family <cli> <model-spec> | catalog.sh validate <cli> <model-spec>" >&2
    exit 2
    ;;
esac
