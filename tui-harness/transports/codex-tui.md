# codex TUI 起用 — 固有差分

codex をペインで起用するときのハーネス固有差分。共通手順の正本は [../SKILL.md](../SKILL.md)（ペイン操作は `mux.sh` 経由）。

## 起動

`mux.sh run` に渡す起動コマンド:

```sh
codex --sandbox workspace-write -c approval_policy=on-request -c approvals_reviewer=auto_review -C '<プロジェクトルート>'
```

- **sandbox は `workspace-write`**: read-only は回答ファイルの書き出しと通信規約の push まで遮断するため使わない。workspace-write はワークスペース全域への書き込みを通す（防御の正本は ../SKILL.md「呼び出しパラメータ」の裁定スコープ項）。
- **`on-request` ＋ `auto_review`**: 承認要求（sandbox 昇格・MCP ツール承認等）を codex のリスク評価サブエージェントに自動裁定させる公式機構で、無人運用の成立要件。`never` は承認要求を裁定に乗せないため使わない。
- ../SKILL.md「委譲先の確定と検証」で確定したモデルを必ず付加する: `-m <slug>`、effort 付き（`<slug>@<effort>` 解決時）はさらに `-c model_reasoning_effort=<effort>`。実測モデル名はペイン下部の表示（例: `gpt-5.6-terra max`）で確認できる（利用スキル側の実測記録の追記等、指定と実効の照合に使う）。モデル名は TUI 起動時に検証されず、誤指定は最初のターンで API エラーとして顕在化する（`catalog.sh validate codex` による事前検証が呼び出し側の規定）。

## trust ダイアログ

cwd の trust が `~/.codex/config.toml` に未記録だと、git リポジトリでも初回起動時に trust ダイアログが出る。文言は版で異なる — 旧版は "Do you trust the contents of this directory?"（選択肢 `1. Yes, continue`）、v0.159.1 は "Folder access / Trust this folder? … Your trust decision will be saved."（選択肢 `1. Trust and continue` / `2. Quit`）。現行版では `mux.sh wait-output <ペインID> "Trust this folder" 15000` で確定待ちし（旧版では `"Do you trust"`）、マッチしたら `mux.sh answer <ペインID> "1"` で通過する（どちらの版も 1 が trust して続行。タイムアウト＝ダイアログなしは正常分岐）。両版に共通する小文字の `trust` で待ってはならない — `wait-output` はリテラルの部分一致で画面全体を見るため、起動コマンド行の `-C` のパスに `trust` が含まれるとダイアログ描画前に一致し、`answer "1"` が空振りする（実測）。**ダイアログ表示中も `agent-wait --until idle` は idle を返す**（実測）ため、idle 到達はダイアログ通過の証拠にならない。確定待ちがタイムアウトした場合は、ブリーフ送信前に `mux.sh read` で入力欄（"Ask Codex to do anything"）の表示を確認する。この Yes は config.toml にプロジェクトの `trust_level = "trusted"` を永続記録する。同一セッションで同一プロジェクトの Yes 通過またはダイアログなし起動を観測済みなら、以後の起動では確定待ちを省いてよい。

## エージェント検知と受理判定

- エージェント名 `codex`。`agent_session`（codex セッション ID）を報告する — 受理完了の判定は ../SKILL.md の「タスクの委譲」手順2の本則（working ＋ `agent_session`）に従う。**`agent_session` 無しの working 応答は実測で発生する** — その場合は同手順3の「作業表示がある → 受理完了」の分岐で受理を確定する。
- 完了後に done を報告せず idle に戻るだけのことがある（実測）— pull 安全網は ../SKILL.md の規定どおり `--until` 無しで張る。

## 検証記録

2026-07-30 実測（利用スキルからの委譲2件・同一ペインへの追送を含む計5回の実運用）: trust 済みプロジェクトでのダイアログなし起動 / エージェント検知（`codex`・status・session）/ `agent_session` 無し working 応答と pane read 二分での受理確定 / auto_review による書き込み・push の無人裁定 / 完了 push の到達（5/5）/ 同一ペインへの次の委譲での文脈保持 / ペイン表示での実測モデル確認（`gpt-5.6-terra max`）。

2026-09-15 実測（指揮者 = Claude Code、Codex v0.154.0 / gpt-6-astra high、herdr バックエンド。入力欄への Enter 送信の再現実験、有効試行 40 件）: `send` 直後に間を置かず `key Enter` を送ると、起動直後 idle・処理後の安定 idle・working 中のいずれでも入力欄にテキストが残って送信されない（12 試行中 7 件。残存時は Enter 単独の再送 1 回で毎回回復）。`send` → 1 秒 → Enter（7/7）、`send` → 画面への出現確認 → Enter（6/6）、herdr の一体送信 API `pane run`（8/8）・`agent prompt`（6/6）はすべて送信された。working 中に送信されたメッセージは Codex の「次のツール呼び出し後に送信」待ち行列に入り、Tab は不要。この実測が `mux.sh submit` の根拠（ADR 0015）。`submit` 自体の実測: idle 中 3 回・日本語本文・3 行本文・working 中の各 1 回がすべて送信され、二重送信なし。`answer "1"` による trust ダイアログの通過、`close` の消滅確認も実測。副次観測: `herdr agent wait --until idle` が、`agent get` では idle を返す状態でタイムアウトすることが 2 回あった（同じコマンドが直後には即時に返る）。また Codex はターン完了後に idle でなく done を報告することがある（実験スクリプトでは idle または done を待って解消）。

2026-09-30 実測（指揮者 = Claude Code、codex-cli 0.159.1 / gpt-6.1-sol high、herdr バックエンド。tandem からの委譲 3 ラウンド）: 未 trust の cwd（git なし）で trust ダイアログが新文言 "Trust this folder?"（選択肢 `1. Trust and continue` / `2. Quit`）で表示され、旧記述の確定待ち文字列 "Do you trust" に一致せず wait-output がタイムアウトした。起動シーケンスの agent-wait はダイアログ表示中のまま idle を返し、`mux.sh read` で検知して `answer "1"` で通過、入力欄 "Ask Codex to do anything" の表示を確認した。以後 3 ラウンドの委譲で受理（working ＋ `agent_session`）/ 完了 push の到達（3/3）/ 同一ペインへの追送での文脈保持 / `close` の消滅確認を実測。改訂の検証として未 trust の一時ディレクトリで起動し、(1) 確定待ち文字列を小文字の `trust` にするとパス（`codextrust.XXXXXX`）の起動コマンド行に一致してダイアログ描画前に `answer "1"` が空振りし、ダイアログが残ること、(2) `"Trust this folder"` では一致 → `answer "1"` → 入力欄 "Ask Codex to do anything" の表示まで通ることを確認した。

2026-08-15 実測（指揮者 = codex のスモーク検証。herdr バックエンド）: codex（on-request + auto_review + workspace-write、cwd はプロジェクト外の一時ディレクトリ）が指揮者として `mux.sh` 全サブコマンド（detect / list / layout / split / run / send / key / read / wait-output / agent-wait / close）を承認要求ゼロで実行 / 内側 codex への委譲 → done push → 回答ファイル回収 → クローズの一巡が成立 / 前面の同期 `agent-wait`（バックグラウンド実行なし）で 240 秒のブロック実行を中断なく完走 / trust ダイアログは指揮者 codex の起用時に表示され `send "1"` ＋ `key Enter` で通過（trust の config.toml への永続記録により、同一 cwd の内側 codex ではダイアログなしの正常分岐）。
