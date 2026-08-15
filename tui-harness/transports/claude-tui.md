# claude TUI 起用 — 固有差分

Claude Code の `claude` CLI をペインで起用するときのハーネス固有差分。共通手順の正本は [../SKILL.md](../SKILL.md)（ペイン操作は `mux.sh` 経由）。

## 起動

`mux.sh run` に渡す起動コマンド:

```sh
cd '<プロジェクトルート>' && claude --permission-mode acceptEdits --model '<モデルID>'
```

- **モデル ID は必須**: `catalog.sh models claude` が返す `models/claude.txt` 掲載 ID を指定する。Claude CLI からモデル一覧を正確に取得できないため、`opus` / `sonnet` / `fable` 等の可変別名と未掲載 ID は使わない。
- 呼び出し側が reasoning effort を指定した場合は `--effort <level>` を付加する（effort は実行設定であり、モデル系統の照合には含めない）。
- **`acceptEdits`**: 成果物ファイルの作成・編集を受理し、シェル実行等の追加承認は共通手順の指揮者裁定へ送る。全面的な権限バイパスは使わない。ただし `acceptEdits` はプロジェクト全域のファイル編集を自動受理するため、**書き込みの遮断はブリーフの規律（成果物置き場にのみ書く）が第一の防御**である（codex の workspace-write と同じ扱い）。

## trust ダイアログ

未 trust の cwd では `Quick safety check: Is this a project you created or one you trust?` と `1. Yes, I trust this folder / 2. No, exit` が表示される。`mux.sh wait-output <ペインID> "Quick safety check" 15000` で確定待ちし、マッチしたら既定選択が Yes であることを `mux.sh read` で確認して `mux.sh key <ペインID> Enter` で通過する。タイムアウトはダイアログなしの正常分岐とする。同じ cwd の次回起動でダイアログが出ないことを実測済み。

## エージェント検知と受理判定

- エージェント名 `claude`。`agent_session` を報告する — 受理完了の判定は ../SKILL.md の「タスクの委譲」手順2の本則（working ＋ `agent_session`）に従う。
- 完了後は idle に戻る。push の実行可否は未検証のため、pull 安全網を必須とする。

## 検証記録

2026-08-15 実測（指揮者 = codex、Claude Code 2.1.232、herdr バックエンド）: `claude-opus-5` と effort high の明示起動 / TUI 上の `Opus 5 with high effort` 表示 / 未 trust cwd の safety check と Enter による Yes 通過 / 同一 cwd 再起動時のダイアログなし / エージェント検知（`claude`・session）/ send ＋ Enter の委譲 / working 遷移 / `acceptEdits` での回答ファイル作成 / 完了後の idle 復帰 / ペインのクローズ。未検証: ハーネス自身による push、シェル実行の承認ダイアログ形式。
