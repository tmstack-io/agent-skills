# agent-skills

自作 Claude Code スキルの正本リポジトリ。`~/.claude/skills/` からは各スキルディレクトリへのシンボリックリンクで参照する。

## 使い方（新しいマシンでの展開）

```sh
git clone <このリポジトリ> ~/Development/repos/agent-skills
for s in ~/Development/repos/agent-skills/*/; do
  ln -s "${s%/}" ~/.claude/skills/"$(basename "$s")"
done
```

## 収録スキル

| スキル | 概要 |
|---|---|
| clarify-ja | AI 生成の難解な日本語を意味を変えずに平易化する事後リライト |
| client-docs | クライアント提出資料の生成（対応報告書 / 意思決定資料の2モード） |
| codex-review-loop | codex レビュー→修正→再レビューを GREEN までループする品質ゲート |
| decruft | 不要記述（メタ環境依存・履歴/変更ナラティブ等）の検出・削除。`--session` で実装直後の後処理 |
| deep-pr-review | GitHub PR の高精度レビュー（多エージェント＋codex＋architect メタ検証を統合レビュー1本に集約） |
| impact-investigation | CVE・指摘・バグ報告起点の影響範囲調査レポート生成（調査と修正を分離。`--client` で非エンジニア向けの平易な日本語に） |
| maestro | 高性能モデルを非実装の指揮者に固定し、実装・調査をサブエージェントへ委譲するセッションモード（`--deep` / `--fast` で検収深度を上書き） |
| memory-dream | 全プロジェクトの auto-memory を再編・統合する consolidation 手順 |
| session-to-prompt | セッションの決定事項から宛先別の自己完結実装プロンプトを生成 |
| skill-refine | 既存スキルの査読→承認→洗練を行うメタスキル（`--project` でプロジェクト専用スキル向けの基準に切り替え） |
| smart-commit | 未コミット変更を論理単位の atomic コミットへ自動分割・登録（規約検出・単位ごと軽量検証つき） |
