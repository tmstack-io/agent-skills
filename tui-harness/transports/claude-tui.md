# claude TUI 起用 — 固有差分

Claude Code の `claude` CLI をペインで起用するときのハーネス固有差分。共通手順の正本は [../SKILL.md](../SKILL.md)（ペイン操作は `mux.sh` 経由）。

## 起動

`mux.sh run` に渡す起動コマンド:

```sh
cd '<プロジェクトルート>' && claude --permission-mode auto --model '<モデルID>'
```

- **モデル ID は必須**: `catalog.sh models claude` が返す `models/claude.txt` 掲載 ID を指定する。Claude CLI からモデル一覧を正確に取得できないため、`opus` / `sonnet` / `fable` 等の可変別名と未掲載 ID は使わない。末尾に `[1m]` が付いた指定（1M トークンコンテキスト版）は、`[1m]` を除いた部分が掲載 ID なら元の値のまま `--model` に渡す。
- 呼び出し側が reasoning effort を指定した場合は `--effort <level>` を付加する（effort は実行設定であり、モデル系統の照合には含めない）。
- **`auto`（auto mode）**: ファイル編集とシェル実行の許否を Claude Code の分類器が判定し、安全と判定した操作は承認ダイアログを出さずに実行する（`acceptEdits` ではシェル実行のたびにダイアログが出て、指揮者裁定が委譲の大半を占めたため）。全面的な権限バイパスは使わない。分類器はプロジェクト全域の編集と、分類器が安全と判定したシェル実行を無確認で通す（成果物置き場外への書き込みを遮断しない。防御の正本は ../SKILL.md「呼び出しパラメータ」の裁定スコープ項）。それでも出るダイアログは共通手順の指揮者裁定へ送る。
- **auto mode の起動確認**: auto mode に対応しないモデル（`claude-haiku-4-5-20251001` で実測）を指定すると、claude はエラーを出さずに `manual mode`（全操作を確認するモード）で起動する。起動シーケンスの末尾に `<mux.sh> read "$PANE" | grep -F 'auto mode on' || echo 'auto-mode=off'` を加えて束ね、`auto-mode=off` が出たら、そのペインを ../SKILL.md「クローズ」の手順で閉じ、「auto mode に対応するモデルを指定し直す（推奨）」「`--permission-mode acceptEdits` で起動し直す（シェル実行のたびに裁定が要る）」「委譲を中止する」を散文提示で確認する。

## trust ダイアログ

未 trust の cwd では `Quick safety check: Is this a project you created or one you trust?` と `No, exit / Yes, I trust this folder` の2択が表示される。`mux.sh wait-output <ペインID> "Quick safety check" 15000` で確定待ちし、マッチしたら `mux.sh read` で `❯` の位置を確認し、既定選択が `No, exit`（Claude Code 2.1.270 で実測。2.1.232 では Yes が既定だった）なら `mux.sh key <ペインID> Down` で `Yes, I trust this folder` へ移してから `mux.sh key <ペインID> Enter` で通過する。ダイアログ表示直後の Enter は TUI 初期化中に吸収されることがあるため、通過後に `mux.sh read` でダイアログが消えたことを確認し、残っていれば Enter を再送する。タイムアウトはダイアログなしの正常分岐とする。同じ cwd の次回起動でダイアログが出ないことを実測済み。

## エージェント検知と受理判定

- エージェント名 `claude`。`agent_session` を報告する — 受理完了の判定は ../SKILL.md の「タスクの委譲」手順2の本則（working ＋ `agent_session`）に従う。
- 完了後は idle に戻る。push の実行可否は未検証のため、pull 安全網を必須とする。

## 直送委譲

`../direct.md`「返答の受け取り」で使う画面マーカー: 指揮者の送信エコーは `❯ ` で始まる行（本文が折り返されると続きの行は行頭が空白）、返答は `⏺ ` で始まる行から次の区切り線（`────`）の手前まで。返答の直後に `✻ ... · done` 行が付く。画面末尾の入力欄（空の `❯`）・ステータス行は返答に含めない。

## 検証記録

2026-10-14 実測（指揮者 = Claude Code、herdr 0.9.3 バックエンド、Claude Code 2.1.299 / claude-sonnet-5。直送上限の見直し）: 3,000〜48,000 文字の `submit` が 1〜3 秒で通り、照合はすべて一致。長い送信本文は会話内で途中が `(N lines hidden)` に畳まれ、先頭数十行と末尾が残る（詳細は `../direct.md` の実測記録）。

2026-10-14 実測（指揮者 = Claude Code、Claude Code 2.1.299、herdr バックエンド）: `claude-sonnet-5` を `--permission-mode auto` で起動し、ステータス行に `⏵⏵ auto mode on` が出ること、`git log` と `gh pr list` の実行がダイアログなしで通ることを確認した。`claude-haiku-4-5-20251001` では同じ起動コマンドでエラーなく `⏸ manual mode on` になった。未検証: auto mode の初回利用時に出うる案内ダイアログ（本機は利用済みのため出なかった）、分類器が操作を拒否したときの画面。

2026-09-15 実測（指揮者 = Claude Code、herdr バックエンド。`mux.sh submit` の導入検証、ADR 0015）: Claude Code 2.1.270 / claude-haiku-4-5-20251001。trust ダイアログ（既定 `No, exit`）を Down → Enter で通過 / `submit` 1 回で送信（送信エコー `❯` と返答 `⏺ OK` を回収）/ `close` の消滅確認。

2026-08-15 実測（指揮者 = codex、Claude Code 2.1.232、herdr バックエンド）: `claude-opus-5` と effort high の明示起動 / TUI 上の `Opus 5 with high effort` 表示 / 未 trust cwd の safety check と Enter による Yes 通過 / 同一 cwd 再起動時のダイアログなし / エージェント検知（`claude`・session）/ send ＋ Enter の委譲 / working 遷移 / `acceptEdits` での回答ファイル作成 / 完了後の idle 復帰 / ペインのクローズ。未検証: ハーネス自身による push、シェル実行の承認ダイアログ形式。

2026-09-15 実測（指揮者 = Claude Code、Claude Code 2.1.270、herdr バックエンド、モデル claude-haiku-4-5-20251001）: trust ダイアログの既定選択が `No, exit` に変わっていることを確認し、Down → Enter で通過。直送委譲の複数行送信（4行 / 19行 1,037 文字）が入力欄に欠けずに入り、Enter 別送で受理、返答を `mux.sh read --scrollback --lines 200` で回収（詳細は `../direct.md` の実測記録）。
