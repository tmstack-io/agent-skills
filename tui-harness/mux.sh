#!/usr/bin/env bash
# tui-harness TUI マルチプレクサラッパーの正本 — ペイン操作の機械的差異を吸収する。
# 呼び出し側も起用したハーネス（通信規約の push）も、ペイン操作は本スクリプト経由で行う
# （マルチプレクサの生コマンドを直接叩かない。セッション毎のばらつき防止）。
#
# バックエンド: herdr（0.7 系コマンド形・検証済み）と cmux（0.64 系・検証済み。要 python3。
# ペイン ID = surface UUID。agent-wait は画面静止推定＋通知高速経路で代替し、agent_session は
# 報告しない。詳細は backends/cmux.md）と Rex（要 python3。ペイン ID = ブロック ID。agent-wait は
# ハーネスが Rex へ申告した状態を読み、申告が無い間は画面静止推定で代替する。agent_session は
# 報告しない。詳細は backends/rex.md）。tmux は未検証のため
# 未対応（detect が検出した場合は stderr に表示だけする）。
# 複数のバックエンドが見える場合は、ターミナルと一体のマルチプレクサ（Rex / cmux）を、
# その上で動く herdr より先に選ぶ（判定順: rex → cmux → herdr）。
#
# 使い方:
#   mux.sh detect
#       利用可能なバックエンドを判定し「backend=<名前>」を stdout に出力する。
#       検証済みバックエンドが無ければ理由を stderr に出して exit 1。
#   mux.sh split <対象ペインID> <right|down>
#       対象ペインを分割し、新ペインの ID だけを1行出力する（フォーカスは移さない）。
#   mux.sh run <ペインID> <コマンド文字列>       … ペインでコマンドを起動する
#   mux.sh submit <ペインID> <テキスト>
#       ハーネスの入力欄へテキストを送って送信する（委譲・question 回答・直送の追送・
#       通信規約の push はすべてこれを使う）。paste → 末尾の出現確認（入力欄での
#       折り返しを許して照合する。貼り付けを [Pasted …] に畳んで表示するハーネスでは
#       畳み表示の増加で確認する）→ Enter →
#       入力欄の変化確認（変化しなければ Enter を再送、合計 3 回）の順で行い、
#       exit 0 = 送信済み / 3 = テキストが画面に現れない（TUI 初期化中の破棄の可能性）/
#       4 = Enter を再送しても入力欄が変わらない。テキストと Enter を同一バーストで
#       送ると Enter が効かないことがある（実測 7/12）ため、send + key Enter を
#       手で組み合わせない。
#   mux.sh answer <ペインID> <テキスト>
#       ダイアログ（番号選択等）へテキストを送って Enter で確定する（send → 1 秒 → Enter）。
#       出現確認が成立しない選択 UI 向け。入力欄への送信には使わない（submit を使う）。
#   mux.sh send <ペインID> <テキスト>            … テキストを打鍵で送る（Enter は送らない）
#   mux.sh paste <ペインID> <テキスト>           … テキストを1回の貼り付けとして送る（Enter は
#       送らない。複数行・長文を入力欄へ入れる経路。cmux の send は改行を Enter として打鍵し、
#       長文の打鍵は途中で止まるため、submit はこちらを使う。Rex は block.event の paste で送る）
#   mux.sh key <ペインID> <キー名>               … キーを送る（例: Enter, y, Down）
#   mux.sh read <ペインID> [--scrollback] [--lines <N>]
#       画面を読む。--scrollback は折り返し前の履歴ソース（alt-screen 描画の
#       ハーネスで必須）。既定は可視画面・20行。
#   mux.sh wait-output <ペインID> <文字列> <タイムアウトms>
#       文字列（リテラルの部分一致。正規表現ではない）の出現を確定待ちする
#       （現れなければ非0終了）。
#   mux.sh agent-wait <ペインID> [--until idle|working|done|blocked] <タイムアウトms>
#       ペインのエージェント状態の到達を確定待ちし、状態 JSON を出力する。
#       --until なしは idle / done / blocked のいずれかで発火する（pull 安全網用）。
#   mux.sh close <ペインID>                      … ペインを閉じ、消滅を確認してから戻る
#
#   send / paste / key / run / submit / answer / close は、対象ペイン ID が list に存在することを
#   確認してから実行する（存在しなければ非0。古い ID への誤送信の防止）。
#   mux.sh self                                  … 本スクリプトを実行しているペイン自身の
#       情報 JSON（pane_id / tab_id / workspace_id）。自ペイン・自ワークスペースの特定は
#       必ずこれを使う（list の focused はユーザーが閲覧中のワークスペースのアクティブ
#       ペインを指すグローバル属性であり、自ペインの特定に使えない）。
#   mux.sh list                                  … 全ペインの一覧 JSON
#   mux.sh tabs                                  … 全タブの一覧 JSON（tab_id と label。
#       ペイン一覧はタブ名を持たないため、タブ名での指定は tabs の label→tab_id を
#       list の tab_id へ突き合わせて解決する）
#   mux.sh layout                                … 自ペインの属するタブのレイアウト JSON
#
# バックエンドの追加: 対話 TUI での実測検証（分割・送信・読み取り・エージェント状態
# 検知・確定待ち）を済ませてから、detect の判定と各サブコマンドの case に
# <バックエンド名>) 分岐を実装する（検証なしに追加しない）。

set -u -o pipefail

detect_backend() {
  if [ -n "${REX_BLOCK:-}" ] && [ -n "${REX_SESSION:-}" ] && command -v rex >/dev/null 2>&1 \
     && rex --autostart=false whoami --json 2>/dev/null | grep -q '"block_id"'; then
    if ! command -v python3 >/dev/null 2>&1; then
      echo "rex: 検出したが python3 が無いため未対応（Rex バックエンドの JSON 処理が python3 を必要とする。導入例: brew install python3）" >&2
      return 1
    fi
    echo rex
    return 0
  fi
  if [ -n "${CMUX_SOCKET_PATH:-}" ] && command -v cmux >/dev/null 2>&1 && cmux ping >/dev/null 2>&1; then
    if ! command -v python3 >/dev/null 2>&1; then
      echo "cmux: 検出したが python3 が無いため未対応（cmux バックエンドの split / agent-wait / list / tabs が python3 を必要とする。導入例: brew install python3）" >&2
      return 1
    fi
    echo cmux
    return 0
  fi
  if [ "${HERDR_ENV:-}" = "1" ] && command -v herdr >/dev/null 2>&1; then
    echo herdr
    return 0
  fi
  command -v cmux >/dev/null 2>&1 && echo "cmux: CLI は存在するが cmux セッション内でない（CMUX_SOCKET_PATH 未設定または socket 不通）ため未対応" >&2
  command -v tmux >/dev/null 2>&1 && echo "tmux: 検出したが未検証のため未対応" >&2
  echo "検証済みの TUI マルチプレクサが無い（対応: herdr / cmux / Rex）" >&2
  return 1
}

extract_pane_id() {
  sed -n 's/.*"pane_id"[[:space:]]*:[[:space:]]*"\{0,1\}\([^",}]*\)"\{0,1\}.*/\1/p' | head -n1
}

# 対象ペイン ID の存在確認（ID はペインの増減で振り直されるため、古い ID への送信を止める）。
require_pane() { # <ペインID> <サブコマンド名>
  case "$BACKEND" in
    # Rex の list はプロセス情報の取得に ps を使う。ps はサンドボックス内（codex の
    # workspace-write で実測）では実行できず、委譲先からの push が通らなくなるため、
    # 存在確認はブロック一覧だけで行う。
    rex) rex block ls -s "$REX_SESSION" --json 2>/dev/null | python3 -c '
import json, sys
sys.exit(0 if any(b["block_id"] == sys.argv[1] for b in json.load(sys.stdin)["blocks"]) else 1)' "$1" 2>/dev/null ;;
    *) "$0" list 2>/dev/null | grep -E -q "\"pane_id\":[[:space:]]*\"$1\"" ;;
  esac \
    || { echo "$2: ペインが存在しない: $1（mux.sh list で ID を取り直す）" >&2; exit 1; }
}

# 画面比較用の正規化: スピナー（点字パターン）と数字（経過秒などのカウンタ）を除く。
normalize_screen() {
  command -v perl >/dev/null 2>&1 || { echo "perl が無いため画面比較ができない（submit が必要とする）" >&2; exit 1; }
  perl -CS -pe 's/[\x{2800}-\x{28FF}0-9]//g'
}

# 送信テキストの出現確認に使う探針: 末尾の空白を除いた本文の末尾 40 文字（文字単位。バイト切りで
# UTF-8 を壊さない）。入力欄は長い本文の末尾（カーソル位置）を表示するため、先頭行は画面外へ
# 押し出されうるが末尾は残る。取り込みの遅い TUI では末尾の出現が取り込み完了の印にもなる。
probe_of() {
  printf '%s' "$1" | perl -CS -0777 -ne 's/\s+\z//; print substr($_, -40)'
}

# 貼り付けの畳み表示（claude: [Pasted text #1 +67 lines] / codex: [Pasted Content 3133 chars] /
# grok: [Pasted: 68 lines]。cmux の貼り付けで実測。hermes: [[ 先頭.. [37 lines] .. 末尾 ]]。Rex の
# 貼り付けで実測）の、画面の読み取り範囲（末尾 40 行）にある個数。
paste_marks_of() { # <ペインID>
  "$0" read "$1" --lines 40 2>/dev/null | perl -CS -0777 -ne 'my $n = () = /\[Pasted[^\]\n]*\]|\[\d+ lines\]/g; print $n'
}

# 送信テキストの出現待ちのタイムアウト（ms）: 6 秒＋1 文字あたり 20ms。長文の貼り付けを
# 取り込みきるまでの時間がハーネスによって大きく異なるため、本文の長さに比例させる。
echo_timeout_of() {
  printf '%s' "$1" | perl -CS -0777 -ne 'print 6000 + 20 * length'
}

# 送信テキストの出現確認: 可視画面に探針が現れるまで待つ（現れなければ非0）。
# TUI の入力欄は長い入力を折り返して表示し、継続行にインデントを付ける（折り返し位置は
# 空白とは限らず、パスの途中でも切れる）。枠付きの入力欄では折り返しの継ぎ目に枠線
# （罫線素片 U+2500–U+257F）やスクロールバー（ブロック要素 U+2580–U+259F）も入る。そのため
# 探針の文字間には画面上の空白・改行・罫線・ブロック要素の挿入を許し、探針内の空白は1文字
# 以上の空白に対応させて照合する（本文の空白が消えた画面は一致させない）。探針は1文字ずつ
# quotemeta し、正規表現として解釈しない。
wait_echo() { # <ペインID> <探針> <タイムアウトms> [送信前の畳み表示の個数]
  local deadline=$(( $(date +%s) + ($3 + 999) / 1000 ))
  while :; do
    # 畳み表示が送信前より増えたら、貼り付けが入力欄に入ったとみなす（本文は画面に出ない）。
    if [ -n "${4:-}" ] && [ "$(paste_marks_of "$1")" -gt "$4" ]; then return 0; fi
    "$0" read "$1" --lines 40 2>/dev/null | perl -CSA -0777 -ne '
      BEGIN { $p = shift @ARGV; $p =~ s/\s+/ /g; $g = "[\\s\\x{2500}-\\x{259F}]*";
              $re = join $g, map { $_ eq " " ? "\\s" : quotemeta } split //, $p }
      exit(/$re/ ? 0 : 1)' -- "$2" && return 0
    [ "$(date +%s)" -ge "$deadline" ] && return 1
    sleep 1
  done
}

cmd=${1:-}
[ -n "$cmd" ] || {
  echo "usage: mux.sh detect|split|run|submit|answer|send|paste|key|read|wait-output|agent-wait|close|self|list|tabs|layout ..." >&2
  exit 2
}
shift

if [ "$cmd" = "detect" ]; then
  BACKEND=$(detect_backend) || exit 1
  echo "backend=$BACKEND"
  if [ "$BACKEND" = "cmux" ]; then
    echo "cmux 注記: agent-wait は画面静止推定＋通知高速経路。通知高速経路は cmux のエージェント連携が効いているハーネスで発火する（発火しなくても静止判定で動作）" >&2
  fi
  exit 0
fi

BACKEND=$(detect_backend) || exit 1

# Rex の program_status の応答（stdin）から、ルートのレコード（id が空）の状態を取り出す。
# ルートのレコードが無ければ空文字（申告なし）。
rex_state() {
  python3 -c '
import json, sys
root = [r for r in json.load(sys.stdin).get("records", []) if not r.get("id")]
print(root[-1]["state"] if root else "")'
}

# エージェント状態（herdr と Rex。cmux は状態 API が無いため空文字。Rex は申告が無ければ空文字）。
agent_status_of() {
  case "$BACKEND" in
    herdr) herdr agent get "$1" 2>/dev/null | sed -n 's/.*"agent_status":"\([a-z]*\)".*/\1/p' ;;
    rex) rex block call -s "$REX_SESSION" -b "$1" program_status 2>/dev/null | rex_state 2>/dev/null || echo "" ;;
    *) echo "" ;;
  esac
}

case "$cmd" in
  submit)
    # 実測（2026-09-15、codex TUI）: send 直後の Enter は 7/12 で入力欄に吸収され、
    # 出現確認を挟むと 0/6、1 秒置くと 0/7 で通った。出現確認は TUI 初期化中の破棄も検出する。
    [ $# -eq 2 ] || { echo "usage: mux.sh submit <ペインID> <テキスト>" >&2; exit 2; }
    pane=$1 text=$2
    require_pane "$pane" submit
    probe=$(probe_of "$text")
    marks=$(paste_marks_of "$pane")
    "$0" paste "$pane" "$text" || exit 1
    wait_echo "$pane" "$probe" "$(echo_timeout_of "$text")" "$marks" \
      || { echo "submit: 送信テキストの末尾がペインの画面に現れない（TUI 初期化中の破棄、または長文の取り込みが待ち時間内に終わらない可能性）: $pane" >&2; exit 3; }
    before=$("$0" read "$pane" --lines 40 | normalize_screen)
    status_before=$(agent_status_of "$pane")
    for _ in 1 2 3; do
      "$0" key "$pane" Enter || exit 1
      # 送信されれば、エージェント状態が working になる（herdr）か、画面（エコー・作業表示・
      # 待ち行列表示）が変わる。3 秒変わらなければ Enter が吸収されたとみなして再送する。
      for _ in 1 2 3; do
        sleep 1
        if [ "$status_before" != working ] && [ "$(agent_status_of "$pane")" = working ]; then exit 0; fi
        after=$("$0" read "$pane" --lines 40 | normalize_screen)
        [ "$after" != "$before" ] && exit 0
      done
    done
    echo "submit: Enter を 3 回送っても入力欄が変わらない（送信されていない）: $pane" >&2
    exit 4
    ;;
  answer)
    [ $# -eq 2 ] || { echo "usage: mux.sh answer <ペインID> <テキスト>" >&2; exit 2; }
    require_pane "$1" answer
    "$0" send "$1" "$2" && sleep 1 && "$0" key "$1" Enter
    exit $?
    ;;
esac

case "$BACKEND" in
  herdr)
    case "$cmd" in
      split)
        [ $# -eq 2 ] || { echo "usage: mux.sh split <対象ペインID> <right|down>" >&2; exit 2; }
        out=$(herdr pane split "$1" --direction "$2" --no-focus) || exit 1
        pane=$(printf '%s' "$out" | extract_pane_id)
        [ -n "$pane" ] || { echo "split の応答から pane_id を取得できない: $out" >&2; exit 1; }
        echo "$pane"
        ;;
      run)
        [ $# -eq 2 ] || { echo "usage: mux.sh run <ペインID> <コマンド文字列>" >&2; exit 2; }
        require_pane "$1" run
        herdr pane run "$1" "$2"
        ;;
      send)
        [ $# -eq 2 ] || { echo "usage: mux.sh send <ペインID> <テキスト>" >&2; exit 2; }
        require_pane "$1" send
        herdr pane send-text "$1" "$2"
        ;;
      paste)
        # herdr の send-text は改行で送信されず、入力欄に1回の入力として入る（実測）ため send と同じ。
        [ $# -eq 2 ] || { echo "usage: mux.sh paste <ペインID> <テキスト>" >&2; exit 2; }
        require_pane "$1" paste
        herdr pane send-text "$1" "$2"
        ;;
      key)
        [ $# -eq 2 ] || { echo "usage: mux.sh key <ペインID> <キー名>" >&2; exit 2; }
        require_pane "$1" key
        herdr pane send-keys "$1" "$2"
        ;;
      read)
        [ $# -ge 1 ] || { echo "usage: mux.sh read <ペインID> [--scrollback] [--lines <N>]" >&2; exit 2; }
        pane=$1; shift
        source=visible lines=20
        while [ $# -gt 0 ]; do
          case "$1" in
            --scrollback) source=recent-unwrapped; shift ;;
            --lines) lines=$2; shift 2 ;;
            *) echo "read: 不明なオプション: $1" >&2; exit 2 ;;
          esac
        done
        herdr pane read "$pane" --source "$source" --lines "$lines"
        ;;
      wait-output)
        [ $# -eq 3 ] || { echo "usage: mux.sh wait-output <ペインID> <文字列> <タイムアウトms>" >&2; exit 2; }
        herdr pane wait-output "$1" --match "$2" --timeout "$3"
        ;;
      agent-wait)
        [ $# -ge 2 ] || { echo "usage: mux.sh agent-wait <ペインID> [--until <状態>] <タイムアウトms>" >&2; exit 2; }
        pane=$1; shift
        until_arg=()
        if [ "$1" = "--until" ]; then
          until_arg=(--until "$2"); shift 2
        fi
        [ $# -eq 1 ] || { echo "usage: mux.sh agent-wait <ペインID> [--until <状態>] <タイムアウトms>" >&2; exit 2; }
        herdr agent wait "$pane" "${until_arg[@]+"${until_arg[@]}"}" --timeout "$1"
        ;;
      close)
        # 消滅を確認してから戻る（cmux 分岐と同じ保証。直後の list で残存が見えるレースを防ぐ）。
        [ $# -eq 1 ] || { echo "usage: mux.sh close <ペインID>" >&2; exit 2; }
        require_pane "$1" close
        herdr pane close "$1" || exit 1
        for _ in 1 2 3 4 5 6; do
          "$0" list 2>/dev/null | grep -E -q "\"pane_id\":[[:space:]]*\"$1\"" || exit 0
          sleep 1
        done
        echo "close: ペインの消滅を確認できない: $1" >&2
        exit 1
        ;;
      self)
        # HERDR_PANE_ID（herdr がペインのシェルへ注入）を既定対象として自ペインを返す。
        # ペイン外の実行では herdr 側が失敗し、そのまま非0で返る（fail fast）。
        herdr pane current
        ;;
      list)
        herdr pane list
        ;;
      tabs)
        herdr tab list
        ;;
      layout)
        # 引数なしの pane layout はユーザーが閲覧中のタブを返すため、--current で
        # 自ペイン（HERDR_PANE_ID）の属するタブに固定する。
        herdr pane layout --current
        ;;
      *)
        echo "不明なサブコマンド: $cmd" >&2
        exit 2
        ;;
    esac
    ;;
  cmux)
    # cmux バックエンド（要 python3）。ペイン ID は surface の UUID を正とする
    # （surface:N 形式の ref は増減で振り直されるため外部インターフェースに使わない）。
    case "$cmd" in
      split)
        [ $# -eq 2 ] || { echo "usage: mux.sh split <対象ペインID> <right|down>" >&2; exit 2; }
        python3 - "$1" "$2" <<'PY'
import json, os, re, subprocess, sys, time
target, direction = sys.argv[1], sys.argv[2]
env = {**os.environ, "CMUX_QUIET": "1"}
def surfaces(ws_id):
    r = subprocess.run(["cmux", "rpc", "surface.list", json.dumps({"workspace_id": ws_id})],
                       capture_output=True, text=True, env=env)
    return json.loads(r.stdout).get("surfaces", []) if r.returncode == 0 else []
ws = json.loads(subprocess.run(["cmux", "workspace", "list", "--json"],
                               capture_output=True, text=True, env=env).stdout)["workspaces"]
wsid, before = None, set()
for w in ws:
    ss = surfaces(w["id"])
    if any(s["id"] == target for s in ss):
        wsid, before = w["id"], {s["id"] for s in ss}
        break
if wsid is None:
    print(f"split: 対象ペインが見つからない: {target}", file=sys.stderr); sys.exit(1)
r = subprocess.run(["cmux", "new-split", direction, "--surface", target, "--focus", "false"],
                   capture_output=True, text=True, env=env)
if r.returncode != 0:
    print(r.stderr or r.stdout, file=sys.stderr); sys.exit(1)
# new-split は新ペインの ref（surface:N）を出力するが、surface.list に現れるのは 0.5〜1 秒後
# （実測）。出力の ref が一覧に現れるまで待ち、その UUID を返す。
m = re.search(r"surface:\d+", r.stdout)
if not m:
    print(f"split: new-split の出力から新ペインの ref を読めない: {r.stdout.strip()}", file=sys.stderr); sys.exit(1)
deadline = time.time() + 10
while True:
    new = [s["id"] for s in surfaces(wsid) if s.get("ref") == m.group(0) and s["id"] not in before]
    if new:
        break
    if time.time() >= deadline:
        print(f"split: 新ペイン {m.group(0)} が 10 秒以内に一覧に現れない", file=sys.stderr); sys.exit(1)
    time.sleep(0.5)
print(new[0])
PY
        ;;
      run)
        # cmux にはペイン内コマンド実行 API が無いため、シェルへの打鍵で代替する。
        # 分割直後のシェル初期化中は送信テキストが破棄されるため、コマンド文字列が
        # 画面（入力行）に現れたことを確定してから Enter を送る（現れなければ再送、計2回）。
        [ $# -eq 2 ] || { echo "usage: mux.sh run <ペインID> <コマンド文字列>" >&2; exit 2; }
        pane=$1 cmdstr=$2
        require_pane "$pane" run
        # まずシェルの初期化完了を画面静止（連続2サンプル一致）で確認する。初期化中に
        # 打鍵したテキストは画面にエコーされたまま破棄されるため、出現確認だけでは足りない。
        prev="" settled=""
        for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15; do
          cur=$(cmux read-screen --surface "$pane" --lines 40 2>/dev/null) \
            || { echo "run: read-screen 失敗: $pane" >&2; exit 1; }
          if [ -n "$cur" ] && [ "$cur" = "$prev" ]; then settled=1; break; fi
          prev=$cur
          sleep 1
        done
        [ -n "$settled" ] || { echo "run: ペインの画面が静止しない（初期化未完了）: $pane" >&2; exit 1; }
        probe=$(probe_of "$cmdstr")
        ok=""
        for attempt in 1 2; do
          cmux send --surface "$pane" "$cmdstr" >/dev/null || exit 1
          if wait_echo "$pane" "$probe" 6000; then
            ok=1; break
          fi
        done
        [ -n "$ok" ] || { echo "run: コマンド文字列がペインの画面に現れない（シェル未初期化の可能性）: $pane" >&2; exit 1; }
        sleep 1
        cmux send-key --surface "$pane" enter >/dev/null
        ;;
      send)
        [ $# -eq 2 ] || { echo "usage: mux.sh send <ペインID> <テキスト>" >&2; exit 2; }
        require_pane "$1" send
        cmux send --surface "$1" "$2" >/dev/null
        ;;
      paste)
        [ $# -eq 2 ] || { echo "usage: mux.sh paste <ペインID> <テキスト>" >&2; exit 2; }
        require_pane "$1" paste
        cmux send --paste --surface "$1" "$2" >/dev/null
        ;;
      key)
        # cmux の send-key は特殊キー（enter / esc / ctrl+c 等）用で、平文字の単キーは
        # 効かない（grok の trust ダイアログで実測）。平文字1文字はテキスト送信で代替する。
        [ $# -eq 2 ] || { echo "usage: mux.sh key <ペインID> <キー名>" >&2; exit 2; }
        require_pane "$1" key
        case "$2" in
          [A-Za-z0-9])
            cmux send --surface "$1" "$2" >/dev/null
            ;;
          *)
            cmux send-key --surface "$1" "$(printf '%s' "$2" | tr 'A-Z' 'a-z')" >/dev/null
            ;;
        esac
        ;;
      read)
        [ $# -ge 1 ] || { echo "usage: mux.sh read <ペインID> [--scrollback] [--lines <N>]" >&2; exit 2; }
        pane=$1; shift
        sb=() lines=20
        while [ $# -gt 0 ]; do
          case "$1" in
            --scrollback) sb=(--scrollback); shift ;;
            --lines) lines=$2; shift 2 ;;
            *) echo "read: 不明なオプション: $1" >&2; exit 2 ;;
          esac
        done
        cmux read-screen --surface "$pane" ${sb[@]+"${sb[@]}"} --lines "$lines"
        ;;
      wait-output)
        # herdr の --match と同じリテラル部分一致（バックエンド間で意味を揃える）。
        [ $# -eq 3 ] || { echo "usage: mux.sh wait-output <ペインID> <文字列> <タイムアウトms>" >&2; exit 2; }
        pane=$1 pattern=$2 timeout_ms=$3
        deadline=$(( $(date +%s) + (timeout_ms + 999) / 1000 ))
        while :; do
          screen=$(cmux read-screen --surface "$pane" --lines 80 2>/dev/null) \
            || { echo "wait-output: read-screen 失敗: $pane" >&2; exit 1; }
          printf '%s' "$screen" | grep -F -q -- "$pattern" && exit 0
          [ "$(date +%s)" -ge "$deadline" ] && { echo "wait-output: タイムアウト (${timeout_ms}ms)" >&2; exit 1; }
          sleep 1
        done
        ;;
      agent-wait)
        # 画面静止推定＋通知高速経路による代替。仕組みと意味を持つ --until の正本は backends/cmux.md。
        [ $# -ge 2 ] || { echo "usage: mux.sh agent-wait <ペインID> [--until <状態>] <タイムアウトms>" >&2; exit 2; }
        pane=$1; shift
        until_state=""
        if [ "$1" = "--until" ]; then until_state=$2; shift 2; fi
        [ $# -eq 1 ] || { echo "usage: mux.sh agent-wait <ペインID> [--until <状態>] <タイムアウトms>" >&2; exit 2; }
        case "$until_state" in
          ""|working|idle) : ;;
          *)
            echo "agent-wait: cmux バックエンドで意味を持つ --until は working / idle のみ（done / blocked への到達は確認できない。--until なしで発火させ、画面を読んで三分類する）: $until_state" >&2
            exit 2
            ;;
        esac
        timeout_ms=$1
        quiet_s=$(( (${MUX_CMUX_QUIET_MS:-15000} + 999) / 1000 ))
        start=$(date +%s)
        deadline=$(( start + (timeout_ms + 999) / 1000 ))
        last_change=$start prev="" first=1 changed=0
        base_notifs=$(cmux list-notifications --json 2>/dev/null | python3 -c \
          'import json,sys; print(" ".join(n["id"] for n in json.load(sys.stdin)))' 2>/dev/null || echo "")
        emit() { printf '{"result":{"agent":{"agent_status":"%s","pane_id":"%s","source":"%s"},"type":"agent_info"}}\n' "$1" "$pane" "$2"; }
        while :; do
          now=$(date +%s)
          screen=$(cmux read-screen --surface "$pane" --lines 80 2>/dev/null) \
            || { echo "agent-wait: read-screen 失敗: $pane" >&2; exit 1; }
          if [ "$first" = 1 ]; then
            prev=$screen first=0
          elif [ "$screen" != "$prev" ]; then
            prev=$screen last_change=$now changed=1
          fi
          if [ "$until_state" = "working" ]; then
            [ "$changed" = 1 ] && { emit working cmux-quiescence; exit 0; }
          else
            newn=$(cmux list-notifications --json 2>/dev/null | python3 -c '
import json, sys
base = set(sys.argv[1].split()); pane = sys.argv[2]
try: ns = json.load(sys.stdin)
except Exception: ns = []
print(1 if any(n.get("surface_id") == pane and n["id"] not in base for n in ns) else 0)' \
              "$base_notifs" "$pane" 2>/dev/null || echo 0)
            [ "$newn" = 1 ] && { emit idle cmux-notification; exit 0; }
            [ $(( now - last_change )) -ge "$quiet_s" ] && { emit idle cmux-quiescence; exit 0; }
          fi
          [ "$now" -ge "$deadline" ] && { echo "agent-wait: タイムアウト (${timeout_ms}ms)" >&2; exit 1; }
          if [ "$until_state" = "working" ]; then sleep 1; else sleep 2; fi
        done
        ;;
      close)
        # close-surface の反映は非同期（実測 1〜2 秒）のため、消滅を確認してから戻る
        # （直後の list で残存が見えるレースを防ぐ）。
        [ $# -eq 1 ] || { echo "usage: mux.sh close <ペインID>" >&2; exit 2; }
        require_pane "$1" close
        # close-surface は --workspace が無いと $CMUX_WORKSPACE_ID の既定に頼り、未設定（cmux 端末外）
        # や別ワークスペースのペインでは失敗するため、ペインの属するワークスペースを list から引いて渡す。
        # cmux 0.65 以降はプロセスが動いているペインの close に --force を要する（実測）。クローズは
        # ハーネスが動いたままのペインを閉じる手順なので常に付ける（herdr の close と同じ挙動）。
        ws=$("$0" list | python3 -c 'import json,sys; print(next(p["workspace_id"] for p in json.load(sys.stdin)["result"]["panes"] if p["pane_id"] == sys.argv[1]))' "$1") \
          || { echo "close: ペインの属するワークスペースを特定できない: $1" >&2; exit 1; }
        cmux close-surface --force --workspace "$ws" --surface "$1" >/dev/null || exit 1
        for _ in 1 2 3 4 5 6; do
          "$0" list 2>/dev/null | grep -F -q "\"pane_id\": \"$1\"" || exit 0
          sleep 1
        done
        echo "close: ペインの消滅を確認できない: $1" >&2
        exit 1
        ;;
      self)
        # CMUX_SURFACE_ID / CMUX_WORKSPACE_ID（cmux が端末へ自動設定する env）から
        # 自ペインを組み立てる。未設定（cmux 端末外・旧バージョン）は fail fast。
        # tab_id はワークスペース ID を充てる（cmux 分岐の list / tabs と同じ ID 空間）。
        [ -n "${CMUX_SURFACE_ID:-}" ] && [ -n "${CMUX_WORKSPACE_ID:-}" ] \
          || { echo "self: CMUX_SURFACE_ID / CMUX_WORKSPACE_ID が未設定のため自ペインを特定できない（cmux 端末内での実行が前提）" >&2; exit 1; }
        printf '{"result":{"pane":{"pane_id":"%s","tab_id":"%s","workspace_id":"%s"},"type":"pane_current"}}\n' \
          "$CMUX_SURFACE_ID" "$CMUX_WORKSPACE_ID" "$CMUX_WORKSPACE_ID"
        ;;
      list)
        python3 - <<'PY'
import json, os, subprocess
from collections import defaultdict
env = {**os.environ, "CMUX_QUIET": "1"}
def run(args):
    return subprocess.run(args, capture_output=True, text=True, env=env).stdout
ws = json.loads(run(["cmux", "workspace", "list", "--json"]))["workspaces"]
def ws_name(w):
    return w.get("custom_title") or w.get("title") or w.get("name") or w.get("current_directory") or w["id"]
panes = []
for w in ws:
    try:
        sl = json.loads(run(["cmux", "rpc", "surface.list", json.dumps({"workspace_id": w["id"]})]))
    except Exception:
        continue
    for s in sl.get("surfaces", []):
        panes.append({
            "pane_id": s["id"], "ref": s["ref"], "tab_id": w["id"], "workspace_id": w["id"],
            "workspace_name": ws_name(w), "terminal_title_stripped": s.get("title") or "",
            "focused": bool(s.get("focused")), "cwd": s.get("requested_working_directory"),
            "commands": [],
        })
# surface 配下のプロセスのコマンドライン（agent 判定の代替材料）
kids = defaultdict(list)
for line in run(["cmux", "top", "--processes", "--flat", "--format", "tsv"]).splitlines():
    c = line.split("\t")
    if len(c) >= 7 and c[3] == "process":
        kids[c[5]].append(c[4])   # parent(ref または pid) -> pid
def descendants(ref):
    out, stack = [], list(kids.get(ref, []))
    while stack:
        p = stack.pop(); out.append(p); stack.extend(kids.get(p, []))
    return out
pid_of = {p["pane_id"]: descendants(p["ref"]) for p in panes}
all_pids = [x for v in pid_of.values() for x in v]
cmd_of = {}
if all_pids:
    for line in run(["ps", "-o", "pid=,command=", "-p", ",".join(all_pids)]).splitlines():
        line = line.strip()
        if line:
            pid, _, cmdl = line.partition(" ")
            cmd_of[pid] = cmdl.strip()
for p in panes:
    p["commands"] = [cmd_of[x] for x in pid_of[p["pane_id"]] if x in cmd_of]
print(json.dumps({"result": {"panes": panes, "type": "pane_list"}}, ensure_ascii=False))
PY
        ;;
      tabs)
        CMUX_QUIET=1 cmux workspace list --json | python3 -c '
import json, sys
ws = json.load(sys.stdin)["workspaces"]
def name(w):
    return w.get("custom_title") or w.get("title") or w.get("name") or w.get("current_directory") or w["id"]
print(json.dumps({"result": {"tabs": [{"tab_id": w["id"], "label": name(w), "workspace_id": w["id"]} for w in ws],
                             "type": "tab_list"}}, ensure_ascii=False))'
        ;;
      layout)
        # 自ワークスペースへ固定する（引数なしのスコープは未確認のため使わない）。
        [ -n "${CMUX_WORKSPACE_ID:-}" ] \
          || { echo "layout: CMUX_WORKSPACE_ID が未設定のため自ワークスペースを特定できない（cmux 端末内での実行が前提）" >&2; exit 1; }
        cmux list-panes --workspace "$CMUX_WORKSPACE_ID" --json
        ;;
      *)
        echo "不明なサブコマンド: $cmd" >&2
        exit 2
        ;;
    esac
    ;;
  rex)
    # Rex バックエンド（要 python3）。ペイン = Rex のブロック、タブ = ウィンドウ、ワークスペース =
    # セッション。ブロック ID は増減で振り直されない。対象は自セッション（REX_SESSION）に限る。
    # 読み替えの正本は backends/rex.md。
    S=$REX_SESSION
    # ペインの画面と履歴の末尾 N 行（rex capture は画面と履歴の全体を返し、行数指定を持たない）。
    rex_tail() { # <ペインID> <行数> [capture の追加オプション...]
      local pane=$1 lines=$2; shift 2
      rex capture -s "$S" -b "$pane" --trim "$@" | tail -n "$lines"
    }
    case "$cmd" in
      split)
        [ $# -eq 2 ] || { echo "usage: mux.sh split <対象ペインID> <right|down>" >&2; exit 2; }
        case "$2" in
          right) dir=right ;;
          down) dir=below ;;
          *) echo "split: 方向は right または down: $2" >&2; exit 2 ;;
        esac
        out=$(rex split -s "$S" -b "$1" --split="$dir" --focus=false --json) || exit 1
        pane=$(printf '%s' "$out" | python3 -c 'import json,sys; print(json.load(sys.stdin)["block_ids"][0])') \
          || { echo "split の応答から新ペインの ID を取得できない: $out" >&2; exit 1; }
        echo "$pane"
        ;;
      run)
        # ペインのシェルへコマンド文字列を書き込み、入力行への出現を確認してから Enter を送る。
        [ $# -eq 2 ] || { echo "usage: mux.sh run <ペインID> <コマンド文字列>" >&2; exit 2; }
        require_pane "$1" run
        rex send -s "$S" -b "$1" -- "$2" >/dev/null || exit 1
        wait_echo "$1" "$(probe_of "$2")" 10000 \
          || { echo "run: コマンド文字列がペインの画面に現れない: $1" >&2; exit 1; }
        sleep 1
        rex send-key -s "$S" -b "$1" enter >/dev/null
        ;;
      send)
        # rex send は打鍵ではなくバイト列をそのまま書き込む（改行は Enter ではなく LF として届く）。
        [ $# -eq 2 ] || { echo "usage: mux.sh send <ペインID> <テキスト>" >&2; exit 2; }
        require_pane "$1" send
        rex send -s "$S" -b "$1" -- "$2" >/dev/null
        ;;
      paste)
        # 1回の貼り付けとして送る（rex send には貼り付けの指定が無いため block.event の paste を使う）。
        # 相手が bracketed paste を有効にしていれば、複数行も1回の貼り付けとして入力欄に入る。
        # 要求全体の上限が約 64KiB のため、ASCII 以外を \uXXXX に変換せず UTF-8 のまま送る
        # （変換すると日本語は1文字 6 バイトになり、約 1 万文字で上限に達する。実測）。
        [ $# -eq 2 ] || { echo "usage: mux.sh paste <ペインID> <テキスト>" >&2; exit 2; }
        require_pane "$1" paste
        python3 -c 'import json, sys
print(json.dumps({"block_id": sys.argv[1], "event": {"type": "paste", "payload": {"text": sys.argv[2]}}}, ensure_ascii=False))' "$1" "$2" \
          | rex api call -s "$S" block.event - >/dev/null
        ;;
      key)
        [ $# -eq 2 ] || { echo "usage: mux.sh key <ペインID> <キー名>" >&2; exit 2; }
        require_pane "$1" key
        rex send-key -s "$S" -b "$1" "$2" >/dev/null
        ;;
      read)
        [ $# -ge 1 ] || { echo "usage: mux.sh read <ペインID> [--scrollback] [--lines <N>]" >&2; exit 2; }
        pane=$1; shift
        unwrap=() lines=20
        while [ $# -gt 0 ]; do
          case "$1" in
            --scrollback) unwrap=(--unwrap); shift ;;
            --lines) lines=$2; shift 2 ;;
            *) echo "read: 不明なオプション: $1" >&2; exit 2 ;;
          esac
        done
        rex_tail "$pane" "$lines" ${unwrap[@]+"${unwrap[@]}"}
        ;;
      wait-output)
        # herdr の --match と同じリテラル部分一致（バックエンド間で意味を揃える）。
        [ $# -eq 3 ] || { echo "usage: mux.sh wait-output <ペインID> <文字列> <タイムアウトms>" >&2; exit 2; }
        pane=$1 pattern=$2 timeout_ms=$3
        deadline=$(( $(date +%s) + (timeout_ms + 999) / 1000 ))
        while :; do
          screen=$(rex_tail "$pane" 80 2>/dev/null) \
            || { echo "wait-output: 画面の読み取りに失敗: $pane" >&2; exit 1; }
          printf '%s' "$screen" | grep -F -q -- "$pattern" && exit 0
          [ "$(date +%s)" -ge "$deadline" ] && { echo "wait-output: タイムアウト (${timeout_ms}ms)" >&2; exit 1; }
          sleep 1
        done
        ;;
      agent-wait)
        # ハーネスが Rex へ申告した状態を読む。申告が無い間は画面静止推定で代替する
        # （--until の意味と申告しないハーネスの正本は backends/rex.md）。
        [ $# -ge 2 ] || { echo "usage: mux.sh agent-wait <ペインID> [--until <状態>] <タイムアウトms>" >&2; exit 2; }
        pane=$1; shift
        until_state=""
        if [ "$1" = "--until" ]; then until_state=$2; shift 2; fi
        [ $# -eq 1 ] || { echo "usage: mux.sh agent-wait <ペインID> [--until <状態>] <タイムアウトms>" >&2; exit 2; }
        case "$until_state" in
          ""|idle|working|done|blocked) : ;;
          *) echo "agent-wait: 不明な状態: $until_state" >&2; exit 2 ;;
        esac
        timeout_ms=$1
        quiet_s=$(( (${MUX_REX_QUIET_MS:-15000} + 999) / 1000 ))
        start=$(date +%s)
        deadline=$(( start + (timeout_ms + 999) / 1000 ))
        last_change=$start prev="" first=1 changed=0
        emit() { printf '{"result":{"agent":{"agent_status":"%s","pane_id":"%s","source":"%s"},"type":"agent_info"}}\n' "$1" "$pane" "$2"; }
        while :; do
          now=$(date +%s)
          status=$(rex block call -s "$S" -b "$pane" program_status 2>/dev/null) \
            || { echo "agent-wait: 状態の読み取りに失敗: $pane" >&2; exit 1; }
          state=$(printf '%s' "$status" | rex_state) || exit 1
          if [ -n "$state" ]; then
            # --until idle は、ターンを終えて入力を待つ done でも成立させる（完了後に idle へ
            # 戻らず done のまま次の入力を待つハーネスがある）。
            case "$until_state:$state" in
              :idle|:done|:blocked|:error|idle:idle|idle:done|working:working|done:done|blocked:blocked)
                emit "$state" rex-program-status; exit 0 ;;
            esac
            first=1 changed=0
          else
            screen=$(rex_tail "$pane" 80 2>/dev/null) \
              || { echo "agent-wait: 画面の読み取りに失敗: $pane" >&2; exit 1; }
            if [ "$first" = 1 ]; then
              prev=$screen first=0 last_change=$now
            elif [ "$screen" != "$prev" ]; then
              prev=$screen last_change=$now changed=1
            fi
            case "$until_state" in
              working) [ "$changed" = 1 ] && { emit working rex-quiescence; exit 0; } ;;
              ""|idle) [ $(( now - last_change )) -ge "$quiet_s" ] && { emit idle rex-quiescence; exit 0; } ;;
            esac
          fi
          [ "$now" -ge "$deadline" ] && { echo "agent-wait: タイムアウト (${timeout_ms}ms)" >&2; exit 1; }
          if [ "$until_state" = "working" ]; then sleep 1; else sleep 2; fi
        done
        ;;
      close)
        # 消滅を確認してから戻る（他バックエンドと同じ保証）。
        [ $# -eq 1 ] || { echo "usage: mux.sh close <ペインID>" >&2; exit 2; }
        require_pane "$1" close
        rex block close -s "$S" "$1" >/dev/null || exit 1
        for _ in 1 2 3 4 5 6; do
          "$0" list 2>/dev/null | grep -F -q "\"pane_id\": \"$1\"" || exit 0
          sleep 1
        done
        echo "close: ペインの消滅を確認できない: $1" >&2
        exit 1
        ;;
      self)
        # rex whoami が、実行元のブロック・ウィンドウ・セッションを返す。
        rex --autostart=false whoami --json | python3 -c '
import json, sys
me = json.load(sys.stdin)
print(json.dumps({"result": {"pane": {"pane_id": me["block_id"], "tab_id": me["window_id"],
                                      "workspace_id": me["session_id"]}, "type": "pane_current"}}))'
        ;;
      list)
        python3 - <<'PY'
import json, os, subprocess, sys
S = os.environ["REX_SESSION"]
def rex(*args):
    return subprocess.run(["rex", *args], capture_output=True, text=True)
r = rex("block", "ls", "-s", S, "--json")
if r.returncode != 0:
    sys.stderr.write(r.stderr); sys.exit(1)
panes = []
for b in json.loads(r.stdout)["blocks"]:
    # ブロックで動くプロセスのコマンドライン（既存ペインの起用での CLI 判定の材料）。
    # process を持たないブロックと、一覧の取得後に閉じたブロックは空にする。
    p = rex("block", "call", "-s", S, "-b", b["block_id"], "process")
    proc = json.loads(p.stdout) if p.returncode == 0 else {}
    fg = proc.get("foreground") or {}
    pids = [str(x["pid"]) for x in (proc.get("child"), fg) if x and x.get("pid")]
    commands = []
    if pids:
        ps = subprocess.run(["ps", "-o", "command=", "-p", ",".join(dict.fromkeys(pids))],
                            capture_output=True, text=True)
        commands = [line.strip() for line in ps.stdout.splitlines() if line.strip()]
    panes.append({"pane_id": b["block_id"], "label": b.get("label") or "", "tab_id": b.get("window_id"),
                  "workspace_id": S, "cwd": fg.get("cwd"), "commands": commands})
print(json.dumps({"result": {"panes": panes, "type": "pane_list"}}, ensure_ascii=False))
PY
        ;;
      tabs)
        rex window ls -s "$S" --json | python3 -c '
import json, sys
v = json.load(sys.stdin)
print(json.dumps({"result": {"tabs": [{"tab_id": w["window_id"], "label": w.get("label") or "",
                                       "workspace_id": v["session_id"]} for w in v["windows"]],
                             "type": "tab_list"}}, ensure_ascii=False))'
        ;;
      layout)
        # 自ペインの属するウィンドウの各ペインを返す。Rex のレイアウトは割合（frame）でしか
        # 取れないため、セル数（rect の width / height）はペインごとの size で補う。
        python3 - <<'PY'
import json, os, subprocess, sys
S = os.environ["REX_SESSION"]
def rex(*args):
    r = subprocess.run(["rex", *args], capture_output=True, text=True)
    if r.returncode != 0:
        sys.stderr.write(r.stderr); sys.exit(1)
    return json.loads(r.stdout)
me = rex("--autostart=false", "whoami", "--json")
panes = []
def walk(node):
    if "block_id" in node:
        size = rex("block", "call", "-s", S, "-b", node["block_id"], "size")
        x, y, w, h = node["rect"]
        panes.append({"pane_id": node["block_id"],
                      "rect": {"width": size["columns"], "height": size["rows"]},
                      "frame": {"x": x, "y": y, "width": w, "height": h}})
    elif "split" in node:
        walk(node["split"]["before"]); walk(node["split"]["after"])
for layer in rex("window", "inspect", "-s", S, me["window_id"], "--json").get("layers", []):
    walk(layer.get("layout") or {})
print(json.dumps({"result": {"layout": {"tab_id": me["window_id"], "panes": panes}, "type": "pane_layout"}}))
PY
        ;;
      *)
        echo "不明なサブコマンド: $cmd" >&2
        exit 2
        ;;
    esac
    ;;
esac
