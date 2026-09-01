#!/usr/bin/env bash
# tui-harness TUI マルチプレクサラッパーの正本 — ペイン操作の機械的差異を吸収する。
# 呼び出し側も起用したハーネス（通信規約の push）も、ペイン操作は本スクリプト経由で行う
# （マルチプレクサの生コマンドを直接叩かない。セッション毎のばらつき防止）。
#
# バックエンド: herdr（0.7 系コマンド形・検証済み）と cmux（0.64 系・検証済み。要 python3。
# ペイン ID = surface UUID。agent-wait は画面静止推定＋通知高速経路で代替し、agent_session は
# 報告しない。詳細は SKILL.md「マルチプレクサ」節のバックエンド差分）。tmux は未検証のため
# 未対応（detect が検出した場合は stderr に表示だけする）。
#
# 使い方:
#   mux.sh detect
#       利用可能なバックエンドを判定し「backend=<名前>」を stdout に出力する。
#       検証済みバックエンドが無ければ理由を stderr に出して exit 1。
#   mux.sh split <対象ペインID> <right|down>
#       対象ペインを分割し、新ペインの ID だけを1行出力する（フォーカスは移さない）。
#   mux.sh run <ペインID> <コマンド文字列>       … ペインでコマンドを起動する
#   mux.sh send <ペインID> <テキスト>            … テキストを送る（Enter は送らない）
#   mux.sh key <ペインID> <キー名>               … キーを送る（例: Enter, y）
#   mux.sh read <ペインID> [--scrollback] [--lines <N>]
#       画面を読む。--scrollback は折り返し前の履歴ソース（alt-screen 描画の
#       ハーネスで必須）。既定は可視画面・20行。
#   mux.sh wait-output <ペインID> <パターン> <タイムアウトms>
#       パターンの出現を確定待ちする（現れなければ非0終了）。
#   mux.sh agent-wait <ペインID> [--until idle|working|done|blocked] <タイムアウトms>
#       ペインのエージェント状態の到達を確定待ちし、状態 JSON を出力する。
#       --until なしは idle / done / blocked のいずれかで発火する（pull 安全網用）。
#   mux.sh close <ペインID>
#   mux.sh list                                  … 全ペインの一覧 JSON
#   mux.sh tabs                                  … 全タブの一覧 JSON（tab_id と label。
#       ペイン一覧はタブ名を持たないため、タブ名での指定は tabs の label→tab_id を
#       list の tab_id へ突き合わせて解決する）
#   mux.sh layout                                … フォーカス中タブのレイアウト JSON
#
# バックエンドの追加: 対話 TUI での実測検証（分割・送信・読み取り・エージェント状態
# 検知・確定待ち）を済ませてから、detect の判定と各サブコマンドの case に
# <バックエンド名>) 分岐を実装する（検証なしに追加しない）。

set -u -o pipefail

detect_backend() {
  if [ "${HERDR_ENV:-}" = "1" ] && command -v herdr >/dev/null 2>&1; then
    echo herdr
    return 0
  fi
  if [ -n "${CMUX_SOCKET_PATH:-}" ] && command -v cmux >/dev/null 2>&1 && cmux ping >/dev/null 2>&1; then
    echo cmux
    return 0
  fi
  command -v cmux >/dev/null 2>&1 && echo "cmux: CLI は存在するが cmux セッション内でない（CMUX_SOCKET_PATH 未設定または socket 不通）ため未対応" >&2
  command -v tmux >/dev/null 2>&1 && echo "tmux: 検出したが未検証のため未対応" >&2
  echo "検証済みの TUI マルチプレクサが無い（対応: herdr / cmux）" >&2
  return 1
}

extract_pane_id() {
  sed -n 's/.*"pane_id"[[:space:]]*:[[:space:]]*"\{0,1\}\([^",}]*\)"\{0,1\}.*/\1/p' | head -n1
}

cmd=${1:-}
[ -n "$cmd" ] || {
  echo "usage: mux.sh detect|split|run|send|key|read|wait-output|agent-wait|close|list|tabs|layout ..." >&2
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
        herdr pane run "$1" "$2"
        ;;
      send)
        [ $# -eq 2 ] || { echo "usage: mux.sh send <ペインID> <テキスト>" >&2; exit 2; }
        herdr pane send-text "$1" "$2"
        ;;
      key)
        [ $# -eq 2 ] || { echo "usage: mux.sh key <ペインID> <キー名>" >&2; exit 2; }
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
        [ $# -eq 3 ] || { echo "usage: mux.sh wait-output <ペインID> <パターン> <タイムアウトms>" >&2; exit 2; }
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
        [ $# -eq 1 ] || { echo "usage: mux.sh close <ペインID>" >&2; exit 2; }
        herdr pane close "$1"
        ;;
      list)
        herdr pane list
        ;;
      tabs)
        herdr tab list
        ;;
      layout)
        herdr pane layout
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
import json, os, subprocess, sys
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
new = [s["id"] for s in surfaces(wsid) if s["id"] not in before]
if len(new) != 1:
    print(f"split: 新ペインを特定できない: {new}", file=sys.stderr); sys.exit(1)
print(new[0])
PY
        ;;
      run)
        # cmux にはペイン内コマンド実行 API が無いため、シェルへの打鍵で代替する。
        # 分割直後のシェル初期化中は送信テキストが破棄されるため、コマンド文字列が
        # 画面（入力行）に現れたことを確定してから Enter を送る（現れなければ再送、計2回）。
        [ $# -eq 2 ] || { echo "usage: mux.sh run <ペインID> <コマンド文字列>" >&2; exit 2; }
        pane=$1 cmdstr=$2
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
        probe=$(printf '%s' "$cmdstr" | head -c 40)
        ok=""
        for attempt in 1 2; do
          cmux send --surface "$pane" "$cmdstr" >/dev/null || exit 1
          if "$0" wait-output "$pane" "$(printf '%s' "$probe" | sed 's/[][(){}.*+?^$|\\]/\\&/g')" 6000 >/dev/null 2>&1; then
            ok=1; break
          fi
        done
        [ -n "$ok" ] || { echo "run: コマンド文字列がペインの画面に現れない（シェル未初期化の可能性）: $pane" >&2; exit 1; }
        sleep 1
        cmux send-key --surface "$pane" enter >/dev/null
        ;;
      send)
        [ $# -eq 2 ] || { echo "usage: mux.sh send <ペインID> <テキスト>" >&2; exit 2; }
        cmux send --surface "$1" "$2" >/dev/null
        ;;
      key)
        # cmux の send-key は特殊キー（enter / esc / ctrl+c 等）用で、平文字の単キーは
        # 効かない（grok の trust ダイアログで実測）。平文字1文字はテキスト送信で代替する。
        [ $# -eq 2 ] || { echo "usage: mux.sh key <ペインID> <キー名>" >&2; exit 2; }
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
        [ $# -eq 3 ] || { echo "usage: mux.sh wait-output <ペインID> <パターン> <タイムアウトms>" >&2; exit 2; }
        pane=$1 pattern=$2 timeout_ms=$3
        deadline=$(( $(date +%s) + (timeout_ms + 999) / 1000 ))
        while :; do
          screen=$(cmux read-screen --surface "$pane" --lines 80 2>/dev/null) \
            || { echo "wait-output: read-screen 失敗: $pane" >&2; exit 1; }
          printf '%s' "$screen" | grep -E -q -- "$pattern" && exit 0
          [ "$(date +%s)" -ge "$deadline" ] && { echo "wait-output: タイムアウト (${timeout_ms}ms)" >&2; exit 1; }
          sleep 1
        done
        ;;
      agent-wait)
        # エージェント状態 API が無いため画面静止推定＋通知高速経路で代替する:
        #   working = 画面が直近のサンプル間で変化した / idle = MUX_CMUX_QUIET_MS（既定 15000ms）静止、
        #   または開始後に対象 surface 宛の新着通知（cmux hooks 導入ハーネスのみ発火する高速経路）。
        #   blocked / done は個別に報告せず idle に含める（呼び出し側の三分類が画面から裁く）。
        #   agent_session は報告しない（受理判定は working 遷移のみ）。
        [ $# -ge 2 ] || { echo "usage: mux.sh agent-wait <ペインID> [--until <状態>] <タイムアウトms>" >&2; exit 2; }
        pane=$1; shift
        until_state=""
        if [ "$1" = "--until" ]; then until_state=$2; shift 2; fi
        [ $# -eq 1 ] || { echo "usage: mux.sh agent-wait <ペインID> [--until <状態>] <タイムアウトms>" >&2; exit 2; }
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
        cmux close-surface --surface "$1" >/dev/null || exit 1
        for _ in 1 2 3 4 5 6; do
          "$0" list 2>/dev/null | grep -F -q "\"pane_id\": \"$1\"" || exit 0
          sleep 1
        done
        echo "close: ペインの消滅を確認できない: $1" >&2
        exit 1
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
        cmux list-panes --json
        ;;
      *)
        echo "不明なサブコマンド: $cmd" >&2
        exit 2
        ;;
    esac
    ;;
esac
