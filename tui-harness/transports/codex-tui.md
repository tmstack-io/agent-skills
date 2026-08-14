# codex TUI 起用 — 固有差分

codex をペインで起用するときのハーネス固有差分。共通手順の正本は [../SKILL.md](../SKILL.md)（ペイン操作は `mux.sh` 経由）。

## 起動

`mux.sh run` に渡す起動コマンド:

```sh
codex --sandbox workspace-write -c approval_policy=on-request -c approvals_reviewer=auto_review -C '<プロジェクトルート>'
```

- **sandbox は `workspace-write`**: read-only は回答ファイルの書き出しと通信規約の push まで遮断するため使わない。書き込みの遮断はブリーフの規律が担う。
- **`on-request` ＋ `auto_review`**: 承認要求（sandbox 昇格・MCP ツール承認等）を codex のリスク評価サブエージェントに自動裁定させる公式機構で、無人運用の成立要件。`never` は承認要求を裁定に乗せないため使わない。
- 呼び出し側が `--model` を指定した場合のみ付加する: `-m <slug>`、effort 付き（`<slug>@<effort>` 解決時）はさらに `-c model_reasoning_effort=<effort>`。省略時は `~/.codex/config.toml` の既定。実測モデル名はペイン下部の表示（例: `gpt-5.6-terra max`）で確認できる。モデル名は TUI 起動時に検証されず、誤指定は最初のターンで API エラーとして顕在化する（`catalog.sh models codex` による事前検証が呼び出し側の規定）。

## trust ダイアログ

cwd の trust が `~/.codex/config.toml` に未記録だと、git リポジトリでも初回起動時に trust ダイアログ（"Do you trust the contents of this directory?"）が出る。`mux.sh wait-output <ペインID> "Do you trust" 15000` で確定待ちし、マッチしたら `mux.sh send <ペインID> "1"` ＋ `mux.sh key <ペインID> Enter` で「Yes, continue」を選ぶ（タイムアウト＝ダイアログなしは正常分岐）。この Yes は config.toml にプロジェクトの `trust_level = "trusted"` を永続記録する。同一セッションで同一プロジェクトの Yes 通過またはダイアログなし起動を観測済みなら、以後の起動では確定待ちを省いてよい。

## エージェント検知と受理判定

- エージェント名 `codex`。`agent_session`（codex セッション ID）を報告する — 受理完了の判定は ../SKILL.md の「タスクの委譲」手順2の本則（working ＋ `agent_session`）に従う。**`agent_session` 無しの working 応答は実測で発生する** — その場合は同手順3の二分（`mux.sh read` で実作業を確認）で受理を確定する。
- 完了後に done を報告せず idle に戻るだけのことがある（実測）— pull 安全網は ../SKILL.md の規定どおり `--until` 無しで張る。

## 検証記録

2026-07-30 実測（合議2件・計5ラウンドの実運用）: trust 済みプロジェクトでのダイアログなし起動 / エージェント検知（`codex`・status・session）/ `agent_session` 無し working 応答と pane read 二分での受理確定 / auto_review による書き込み・push の無人裁定 / 完了 push の到達（5/5）/ ラウンド間の同一ペイン追送による文脈保持 / ペイン表示での実測モデル確認（`gpt-5.6-terra max`）。

2026-08-15 実測（指揮者 = codex のスモーク検証。herdr バックエンド）: codex（on-request + auto_review + workspace-write、cwd はプロジェクト外の一時ディレクトリ）が指揮者として `mux.sh` 全サブコマンド（detect / list / layout / split / run / send / key / read / wait-output / agent-wait / close）を承認要求ゼロで実行 / 内側 codex への委譲 → done push → 回答ファイル回収 → クローズの一巡が成立 / 前面の同期 `agent-wait`（バックグラウンド実行なし）で 240 秒のブロック実行を中断なく完走 / trust ダイアログは指揮者 codex の起用時に表示され `send "1"` ＋ `key Enter` で通過（trust の config.toml への永続記録により、同一 cwd の内側 codex ではダイアログなしの正常分岐）。
