# roundtable を claude-skills から移管し議長非依存の円卓会議として収録する

Status: accepted

ADR 0004 は tui-harness 移管時に「利用スキル（roundtable / concertino / solista / deep-pr-review）はすべて claude-skills に残留」とした。本決定はこのうち roundtable の残留判断を変更し、実行エージェント（議長）を問わない汎用スキルへ改めたうえで本リポジトリへ移管する。

理由: roundtable の Claude Code 固有依存を精査すると (a) `claude` 固定席（Agent サブエージェント＋SendMessage 継続＋セッションモデル継承）、(b) 編成確定の AskUserQuestion、(c) `disable-model-invocation` 前提の起動方式、の3点に限られ、(b)(c) は本リポジトリの既存規約（散文提示・明示起動の確認ゲート）で機械的に中立化できる。(a) は固定席を「議長系統の席 `host`」へ再定義し、サブエージェント起用と継続対話がある環境（CC: Agent＋SendMessage）ではサブエージェント、無い環境では議長と同じモデル・reasoning effort の同系統ハーネスをペイン起用する能力主語化で解決した（tui-harness の pull 安全網の能力主語化と同型）。roundtable の多角性の源泉は TUI ペインの異系統ハーネスであり CC の並列 Agent ではないため、claude-skills の収録基準「CC の運用構造そのものが品質の源泉」に実態が合わないことも移管を支持する。

検証: 2026-08-15 のスモーク2本で合議一巡（編成宣言・3席の回答回収・収束判定・verdict・全ペインクローズ）を確認。CC 議長（host=Agent サブエージェント経路。SendMessage 継続と再送依頼上限2回の回復を含む5ラウンド完走）と、codex 議長（host=codex ネイティブのサブエージェント経路。`.agents/skills/` でのスキル解決・grok / cursor-agent 2席の委譲回収を含むラウンド1収束）。host の同系統ペイン代替経路（サブエージェント機能が無い議長）は未実測のまま収録する（実測した2議長がいずれもサブエージェントを持っていたため）。

## Considered Options

- **claude-skills に残す（ADR 0004 の判断維持）** — 却下。codex 等を議長にする実需に対し、CC 専用リポジトリへの収録が配布経路（`npx skills` / `.agents/skills/` / `~/.codex/skills/`）を塞ぐ。
- **固定席を廃止し3席ともカタログ席にする** — 却下。実装は最も単純だが、CC で使うときの現行価値（ペイン2枚で済む・セッションモデルの継承・SendMessage 継続の軽さ）を失う。
- **サブエージェント機能を必須にする（無い環境では中止）** — 却下。fail fast ではあるが他ハーネス議長で使えず、移管の目的を達しない。
- **host 席の能力主語化（サブエージェント → 同系統ペインの二段）で移管（採用）**。議長が自身の実効モデル・effort を特定できない場合は当該 CLI の既定モデルで代用し、代用した旨と理由を編成の宣言に明記する（黙って縮退しない）。

## Consequences

- 席名 `claude` は `host` へ改名（エイリアスを残さない破壊的変更。過去の議事録のファイル名は当時のまま残る）。
- 異系統性ガードは「3席（host を含む）の実効モデルが相互にすべて異なる」の全ペア判定に一般化。
- 合議の語彙（賢者・議長・収束判定）は本リポジトリの CONTEXT.md が持ち、claude-skills 側からは削除。
- git 履歴は移植しない（roundtable の過去の変更履歴は claude-skills 側に残る。ADR 0004 と同じ扱い）。
