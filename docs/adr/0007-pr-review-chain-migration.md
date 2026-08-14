# deep-pr-review / pr-comment / pr-recheck を claude-skills から移管し多角性スキルの CC 専用振り分けを廃止する

Status: accepted

PR レビュー連鎖の3スキル（deep-pr-review: 生成 / pr-comment: 投稿 / pr-recheck: 修正検証）を claude-skills から本リポジトリへ移管する。あわせて、スキル設計規約の「独立コンテキストの多角性そのものが品質の源泉であるスキルは CC 専用として claude-skills に置く」という振り分けを廃止した。

理由: 多角化は tui-harness によりどのハーネスでも実現できるようになり、codex 等の主要ハーネスがネイティブサブエージェントを持つことも実測済み（ADR 0005 / 0006 のスモーク）で、「多角性＝CC 専用」の前提が実態と合わなくなった。振り分け基準は「実行エージェント固有の機能・データ構造に依存するもののみ当該エージェント専用リポジトリに置く」（例: claude-skills の memory-dream — CC の auto-memory 構造に依存）へ更新した。deep-pr-review は移管前からサブエージェント不可環境のフォールバック規定（メイン側がレビューとメタ検証を別パスで代替し、代替を明記する）を備えており、新基準の要件（能力の存在確認＋縮退の誠実さ）を満たす。pr-comment / pr-recheck は gh ベースで元よりハーネス中立に近く、改訂は機械的（明示起動ゲート・散文提示ブロックの正準化・復旧手順の配布元変更・解決順への Codex ディレクトリ追記・能力主語化）に留まる。

検証: 2026-08-15 に使い捨てのプライベート検証リポジトリ＋人工欠陥3件入り PR でフルチェーンを実測 — deep-pr-review（CC 指揮者。観点6体＋codex ペイン＋architect(opus)。仕込み3欠陥を全観点横断で検出し、architect が新規2件を追加）→ pr-comment（行アンカー2件の実投稿・二重投稿防止・publish-polish 部分適用）→ 修正 push → pr-recheck（解消1件の確認返信＋thread resolve・未解消/報告なし1件の候補外処理・worktree 後始末）。加えて codex 指揮者の deep-pr-review 1本。未実測: pr-comment の会話コメントフォールバック経路（全指摘が差分内に行アンカーできたため）。スモーク中、CC のバックグラウンドサブエージェントが最終報告を送らず終了する事象が散発し（報告は SendMessage の明示指示が必要）、deep-pr-review のフォールバック規定（メイン側代替＋注記）で吸収できることを確認した。

## Considered Options

- **claude-skills に残す** — 却下。振り分けの根拠（多角性=CC 専用）が実態と合わず、codex 等の指揮者から PR レビュー連鎖を使えない。
- **deep-pr-review のみ移管し投稿・検証は残す** — 却下。3スキルは連鎖して初めて完結する設計で、リポジトリを分けると跨ぎ参照が増えるだけ。
- **3スキル移管＋規約の振り分け基準を「エージェント固有依存の有無」へ更新（採用）**。

## Consequences

- claude-skills の収録は iterate-review / memory-dream の2スキルになる（収録基準は CLAUDE.md で「CC 固有の機能・データ構造に依存するもののみ」に更新済み）。
- 語彙（指摘ID・選別・修正検証・解消）は本リポジトリの CONTEXT.md へ移し、claude-skills 側からは削除（残留スキルに利用者がいないため。ADR 0004 の両リポジトリ保持と異なる扱い）。
- verbatim-inputs.md / partial-application-contract.md の同梱ファイルもスキルディレクトリごと移動し、再取得案内は `tmstack-io/agent-skills` 由来へ変更。
- git 履歴は移植しない（過去の変更履歴は claude-skills 側に残る）。
