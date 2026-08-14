# tui-harness を claude-skills から移管しマルチプレクサ拡張可能な TUI 起用基盤として収録する

Status: accepted

tui-harness（TUI マルチプレクサのペインで他 LLM ハーネスを起動・委譲・回収する基盤）は claude-skills リポジトリで roundtable / concertino の共通基盤として切り出された（claude-skills の ADR 0005）。しかし実態を精査すると、Claude Code 固有の依存は pull 安全網の `run_in_background` と「Claude 本体（指揮者）」という語彙の2点だけで、いずれも中立化できる薄さであり、実行エージェントに縛られる理由は無かった。codex 等の他エージェントを指揮者側にする実需があり、2026-08-15 のスモーク検証（codex を on-request + auto_review + workspace-write の実運用既定のまま指揮者として起用）で、`mux.sh` 全サブコマンドの承認要求ゼロでの実行・内側ハーネスへの委譲→done push→回収→クローズの一巡・前面同期 `agent-wait` の 240 秒ブロック完走の3点すべてが成立したため、本リポジトリへ移管する。

ここでの「汎用」は「実行エージェントを問わない」を指す。マルチプレクサについては、`mux.sh` がバックエンド差を吸収するラッパーであり、対話 TUI の実測検証を経て検証済みバックエンドを増分追加できる拡張構造を持つ（追加手順は mux.sh ヘッダの規定）。現時点の検証済みバックエンドは herdr のみで、未検証環境は `mux.sh detect` の fail fast により起用を開始しない。特定バックエンドの CLI への依存は、スキル設計規約の「外部 CLI 依存（存在チェックとフォールバック付き）」として適法に収まる。

利用スキル（roundtable / concertino / solista / deep-pr-review）はすべて claude-skills に残留し、リポジトリ跨ぎ参照（解決順: 自スキルの隣 → 実行エージェントのスキルディレクトリ、復旧手順: `npx skills add tmstack-io/agent-skills --skill tui-harness`）で tui-harness を解決する。pull 安全網は能力主語化し、バックグラウンド実行が無い環境では前面の同期 `agent-wait` で待つ（待ちの直列化はコストとして受容。240 秒ブロックの完走は codex 指揮者で実測済み）。transports の実測記録には以後、実測時の指揮者を明記する（明記なしの既存記録は Claude Code 指揮者での実測）。

## Considered Options

- **claude-skills に残す（現状維持）** — 却下。codex 指揮者の実需に対し、CC 専用リポジトリへの収録が配布経路（`npx skills` / `~/.codex/skills/`）を塞ぐ。claude-skills の収録基準「CC の運用構造そのものが品質の源泉」にも実態が合わない（CC 固有依存は中立化できる2点のみ）。
- **移管と同時に tmux / cmux バックエンドも追加する** — 却下。`agent-wait` のエージェント状態検知に相当する機能の代替設計を要する別規模の作業であり、移管判断に混ぜない。バックエンド追加は mux.sh の既存の増分手順（実測検証→分岐追加）でいつでも行える。
- **concertino / solista も同時移管** — 却下（今回のスコープ外）。concertino は iterate-review（claude-skills 残留・CC 専用）への依存があり跨ぎ参照の逆転を生む。codex 指揮者での実運用実績が積めた後に再判定する。
- **tui-harness のみ移管し、検証済みバックエンドの増分追加構造のまま収録（採用）**。

## Consequences

- 利用スキルが全部 claude-skills 側にあり基盤だけ本リポジトリにある跨ぎ構図になる（本 ADR がその理由の記録）。claude-skills の ADR 0005（基盤切り出し）は有効なまま、置き場だけが変わる。
- 語彙（ハーネス・指揮者・裁定スコープ・指揮者裁定）は両リポジトリの CONTEXT.md がそれぞれの文脈で持ち、正本は本リポジトリの tui-harness とする。
- git 履歴は移植しない（tui-harness の過去の変更履歴は claude-skills 側に残る）。
