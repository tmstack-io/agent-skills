# agent-skills

自作コーディングエージェント用の**汎用**スキルの正本リポジトリ。基本のベース運用は Claude Code（`~/.claude/skills/` からは各スキルディレクトリへのシンボリックリンクで参照する）で、codex 等の他エージェントでも動く。Claude Code 専用スキル（codex-review-loop / deep-pr-review / maestro / memory-dream）は [claude-skills](https://github.com/tmstack-io/claude-skills) を参照。

## 使い方（新しいマシンでの展開）

### Claude Code（シンボリックリンク運用）

```sh
git clone git@github.com:tmstack-io/agent-skills.git <任意のパス>
cd <任意のパス>
for s in "$PWD"/*/; do
  ln -s "${s%/}" ~/.claude/skills/"$(basename "$s")"
done
```

### codex（シンボリックリンク運用）

```sh
cd <クローン先のパス>
for s in "$PWD"/*/; do
  ln -s "${s%/}" ~/.codex/skills/"$(basename "$s")"
done
```

### npx skills（パッケージマネージャ配布）

[vercel-labs/skills](https://github.com/vercel-labs/skills) の `npx skills` でもインストールできる（GitHub がレジストリ。Claude Code / Codex を含む多数のエージェントに対応）:

```sh
npx skills add tmstack-io/agent-skills                      # 対話ピッカーで選択
npx skills add tmstack-io/agent-skills --skill clarify-ja   # 単体指定
```

注意: `npx skills add` は**スキルディレクトリ単体のコピー**を配置する。シンボリックリンク運用と併用すると同名エントリが衝突するため、マシンごとにどちらか一方の運用に統一する。

## 収録スキル

| スキル | 概要 |
|---|---|
| clarify-ja | AI 生成の難解な日本語を平易化する事後リライト（既定は意味厳守、`--plain` で非技術者向けの読者適応。GitHub PR / issue も入力可） |
| client-docs | クライアント提出資料の生成（対応報告書 / 意思決定資料の2モード） |
| decruft | 不要記述（メタ環境依存・履歴/変更ナラティブ等）の検出・削除。`--session` で実装直後の後処理 |
| impact-investigation | CVE・指摘・バグ報告起点の影響範囲調査レポート生成（調査と修正を分離。`--client` で非エンジニア向けの平易な日本語に） |
| session-to-prompt | セッションの決定事項から宛先別の自己完結実装プロンプトを生成 |
| skill-refine | 既存スキルの査読→承認→洗練を行うメタスキル（既定は汎用スキル基準。`--myself` で実行エージェント専用基準、`--project` でプロジェクト専用基準に切り替え） |
| smart-commit | 未コミット変更を論理単位の atomic コミットへ自動分割・登録（規約検出・単位ごと軽量検証つき） |

## スキル間の依存

client-docs / smart-commit は clarify-ja に、impact-investigation（`--client` 時のみ）は clarify-ja と client-docs に依存する。[claude-skills](https://github.com/tmstack-io/claude-skills)（別リポジトリ）の deep-pr-review も本リポジトリの clarify-ja に依存する。各スキルは実行前に依存先を「自スキルの隣 → 実行エージェント自身のスキルディレクトリ（プロジェクト側 → グローバル側）」の順で探し、見つからなければ復旧手順を案内して中止する。部分インストールする場合は依存先も併せて導入すること。
