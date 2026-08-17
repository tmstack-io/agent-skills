# agent-skills

自作コーディングエージェント用の**汎用**スキルの正本リポジトリ。基本のベース運用は Claude Code（`~/.claude/skills/` からは各スキルディレクトリへのシンボリックリンクで参照する）で、codex 等の他ハーネスでも動く。Claude Code 専用スキル（memory-dream）は [claude-skills](https://github.com/tmstack-io/claude-skills) を参照。

## 使い方（新しいマシンでの展開）

### Claude Code（シンボリックリンク運用）

```sh
git clone git@github.com:tmstack-io/agent-skills.git <任意のパス>
cd <任意のパス>
for s in "$PWD"/*/; do
  [ -f "${s}SKILL.md" ] && ln -s "${s%/}" ~/.claude/skills/"$(basename "$s")"
done
```

### Claude Code 以外のハーネス（codex / grok 等・シンボリックリンク運用）

Claude Code 以外のハーネスは、ハーネス横断の標準配置 `~/.agents/skills/` を参照する。ここに張れば codex / grok 等が共通で読める:

```sh
cd <クローン先のパス>
for s in "$PWD"/*/; do
  [ -f "${s}SKILL.md" ] && ln -s "${s%/}" ~/.agents/skills/"$(basename "$s")"
done
```

### npx skills（パッケージマネージャ配布）

[vercel-labs/skills](https://github.com/vercel-labs/skills) の `npx skills` でもインストールできる（GitHub がレジストリ。Claude Code / Codex を含む多数のハーネスに対応）:

```sh
npx skills add tmstack-io/agent-skills                    # 対話ピッカーで選択
npx skills add tmstack-io/agent-skills --skill plainify   # 単体指定
```

注意: `npx skills add` は**スキルディレクトリ単体のコピー**を配置する。シンボリックリンク運用と併用すると同名エントリが衝突するため、マシンごとにどちらか一方の運用に統一する。

## 収録スキル

| スキル | 概要 |
|---|---|
| concertino | 指定ロール（implement / review / explore）を複数ハーネス奏者の編成（合計4まで）に配役するセッションモード（TUI マルチプレクサ環境専用。固定既定なし・奏者は指揮者と異系統のモデルが必須） |
| decruft | 不要記述（メタ環境依存・履歴/変更ナラティブ等）の検出・削除。引数なしでセッション生成物の後処理 |
| deep-pr-review | GitHub PR の高精度レビュー（多エージェント＋ハーネス、モデルの順で選ぶ異系統モデルの外部独立レビュー＋architect メタ検証を統合レビュー1本に集約。固定既定なし・TUI マルチプレクサ環境専用・投稿は pr-comment） |
| impact-investigation | CVE・指摘・バグ報告起点の影響範囲調査レポート生成（調査と修正を分離。`--for <読者>` で指定読者向けの平易なレポートに） |
| iterate-review | レビュー→修正→再レビューを GREEN までループする品質ゲート（レビュアーは配役 → ハーネス、モデルの順で選ぶ固定既定なしのペイン → サブエージェント縮退の順で解決） |
| maestro | 実行エージェント本体を非実装の指揮者に固定し、実装・調査を奏者（サブエージェント、無い環境では指揮者と同系統ハーネスのペイン）へ委譲するセッションモード（`--deep` / `--fast` で検収深度を上書き） |
| plainify | AI 生成の難解な文章を平易化する事後リライト（言語非依存の普遍規則＋言語別規則。言語別規則は現在日本語を収録。既定は意味厳守、`--for <読者>` で指定読者への読者適応。GitHub PR / issue も入力可） |
| pr-comment | 同一セッションの deep-pr-review 統合レビューから、ユーザーが選んだ指摘だけを GitHub PR のレビューコメントとして投稿（publish-polish → plainify の2段で公開整形・行アンカー／会話コメント） |
| pr-recheck | 投稿済みの指摘コメントが PR の新しい head で解消されているかを検証（修正検証）し、選別を経て判定つきの返信を投稿（解消は resolve 併実施。セッションを跨いで動作） |
| pr-respond | 自分が著者の PR に付いたレビュー指摘（人間・bot）を対処判定（妥当 / 不当 / 要判断）し、二段の承認を経て妥当分をレビュー指摘ごとに修正・コミット・push、妥当分には修正コミット、不当分には理由の返信を投稿する著者側スキル（要判断は報告のみ。resolve はしない。セッションを跨いで動作） |
| publish-polish | 公開予定のドキュメント・コードコメントを初見の読者に成立する公開品質へ書き換え（漏えい疑いは警告のみ。`--style` で文体・体裁・構成の磨き込みも提案） |
| roundtable | 与えられた合議の主題を異系統の3 LLM（議長系統の host 固定席＋未指定時にハーネス、各モデルの2段階で選ぶ2席）で合議し、最終回答に統合する円卓会議（TUI マルチプレクサ環境専用。議事録を `.roundtable/` に永続保存） |
| session-to-prompt | セッションの決定事項から宛先別の自己完結実装プロンプトを生成 |
| sidebar | 実行中と別系統のモデルへセッションの文脈を添えて問いを投げ、以後の壁打ちをそのペインでユーザーに引き渡す別席相談（TUI マルチプレクサ環境専用。片道委譲・1席・工程非依存。前回のペインが生きていれば差分だけを添えて追問できる） |
| skill-feedback | 同一セッションで実際に使ったスキルの実行の証跡（逸脱・補完・介入・空振り）から問題点を洗い出し、汎化テストを通った修正だけを承認後に SKILL.md へ適用（skill-refine の静的査読と別系統のセッション駆動改善。汎化の地平は対象の適用範囲で切替 — `--myself` でハーネス軸、`--project` でプロジェクト軸を免除） |
| skill-refine | 既存スキルの査読→承認→洗練を行うメタスキル（点検は独立3体の多重点検で過半数指摘のみ正規受理。craft 基準は writing-great-skills（`mattpocock/skills`）を正本として適用。既定は汎用スキル基準。`--myself` で実行ハーネス専用基準、`--project` でプロジェクト専用基準に切り替え） |
| slack-research | プロジェクトに紐づく Slack ワークスペースの読み取り専用調査（`.slack-research-env` の User Token で curl から Web API を直接呼ぶ。MCP 不要・複数ワークスペースはプロジェクト毎のトークンで切り替え） |
| smart-commit | 未コミット変更を論理単位の atomic コミットへ自動分割・登録（規約検出・単位ごと軽量検証つき） |
| solista | 編成1の concertino — 単独奏者へ指定ロールを配役するセッションモード（固定既定なし・指揮者と異系統のモデルが必須） |
| tui-harness | TUI マルチプレクサのペインで他 LLM ハーネス（codex / cursor-agent / agy / claude / grok）を起動・委譲・回収する基盤（`mux.sh` / `catalog.sh` / モデル系統の照合 / ハーネス別 transports。現行バックエンド herdr） |

## スキル間の依存

smart-commit と impact-investigation（`--for` 時のみ）は plainify に依存する。roundtable / concertino / deep-pr-review / sidebar は tui-harness に依存し（必須）、maestro はペイン経路（サブエージェント機構が無い実行ハーネス）でのみ tui-harness に依存する。deep-pr-review は plainify にも依存する（必須）。iterate-review はレビュアー解決のハーネスペイン経路（既定）で tui-harness に依存する（TUI 環境が無い場合はサブエージェントへ縮退）。skill-refine はサブエージェント機構が無い環境の点検ペイン経路でのみ tui-harness に依存する（TUI 環境も無ければ自己実行へ縮退）。solista は concertino に、pr-comment / pr-recheck / pr-respond は publish-polish と plainify に依存し（pr-recheck / pr-respond は pr-comment 同梱の公開整形契約も参照する）、roundtable の実装プロンプト書き出し（求められた場合のみ）は session-to-prompt に依存する。各スキルは実行前に依存先を「自スキルの隣 → 実行ハーネス自身のスキルディレクトリ（プロジェクト側 → グローバル側）」の順で探し、見つからなければ復旧手順を案内して中止する。部分インストールする場合は依存先も併せて導入すること。
