# agent-skills 汎用化リファイン＋リポジトリ分割設計書の作成

<!-- 生成: 2026-07-11 / 元: agent-skills のセッション / 実行手段: 新規セッション直実装 -->

## 目的とゴール

agent-skills リポジトリの自作スキル群を「Claude Code（CC）での利便性・確実性を一切落とさず、codex 等の他エージェントでも動く汎用スキル」へリファインする。あわせて CC 専用スキル 3 本を別リポジトリへ移すための分割設計書を作成する（物理的な移動・リポジトリ作成は人間が後で手動実施する。このタスクでは行わない）。

完了条件:

- 汎用 8 スキル（clarify-ja / client-docs / codex-review-loop / decruft / impact-investigation / smart-commit / session-to-prompt / skill-refine）の SKILL.md が本書「変換規約」に適合している
- `grep -rn '~/.claude/skills/' */SKILL.md` の残存箇所がすべて「参照解決順における既知スキルディレクトリの列挙」または「復旧手順の案内文中の例示」のいずれかである（`~/.claude/skills/` を**唯一の**解決手段とする参照が残っていない）
- deep-pr-review / smart-commit / client-docs に clarify-ja の前置き存在チェック（Step 0）が入っている
- `disable-model-invocation: true` を持つ汎用スキル（clarify-ja / codex-review-loop / smart-commit）の本文冒頭に「明示起動の確認」ゲートがある
- README.md に codex 向け展開手順（symlink ループ＋ `npx skills add` 案内）と収録スキル表の帰属列（汎用 / CC 専用・移転予定）がある
- CLAUDE.md のスキル設計規約が「npx skills の per-skill コピー配布」前提に更新されている
- 分割設計書 `docs/split-plan.md` が存在し、人間がそれだけを読んで分割作業を完遂できる
- 全スキルに対する /skill-refine 査読が完了し、指摘ゼロまたは指摘への対処が済んでいる

## 背景・経緯

このリポジトリは自作 Claude Code スキル 11 本の正本で、`~/.claude/skills/` の同名エントリはここへのシンボリックリンク。従来は CC 専用の想定だったが、codex でも使いたくなった。ただし基本のベース運用は CC であり、**CC 側の動作保証が最上位制約**。将来は `npx skills`（vercel-labs/skills）のようなパッケージマネージャでの配布を前提とする。

`npx skills` の実仕様をソースコード（src/skills.ts / src/types.ts / src/source-parser.ts）まで調査済みで、以下は確認済みの事実として扱ってよい（再調査不要）:

1. GitHub がレジストリ。`npx skills add owner/repo` でインストール。Codex（グローバル `~/.codex/skills/`、プロジェクト `.agents/skills/`）、CC（`~/.claude/skills/`）を含む 70 以上のエージェントに対応。
2. 発見規則: リポジトリ直下は深さ 1 で走査され、**現行のフラット配置 `<名前>/SKILL.md` はそのまま発見される**（配置変更は不要）。`skills/` コンテナのみ深さ 2（カタログ配置）まで走査。直下カテゴリ `generic/<名前>/` は「何も見つからない場合の再帰フォールバック」でしか発見されない脆い配置。
3. 部分インストール: `--skill <名前>` / `owner/repo@skill-name` / サブパス `owner/repo/path`。
4. frontmatter に対応エージェントを宣言するフィールドは無い（`metadata.internal` による非表示のみ）。「CC 専用」をツールに強制させる唯一の頑健な手段はリポジトリ境界。
5. スキル間依存の仕組みは無い。インストールは**スキルディレクトリ単体のコピー**であり、同梱リポジトリの他ファイルは配布されない。

## 決定事項と理由

- **決定**: 汎用 8 本は agent-skills に残し、CC 専用 3 本（deep-pr-review / maestro / memory-dream）は新リポジトリ（名称案: claude-skills）へ移す。/ **理由**: npx skills にエージェント別メタデータが無い以上（事実 4）、codex 利用者に CC 専用スキルを見せない唯一の頑健な手段がリポジトリ境界。
- **決定**: agent-skills は現行フラット配置を維持する。/ **理由**: 事実 2 のとおり直下 `<名前>/SKILL.md` は発見互換。移動コストゼロ。
- **決定**: deep-pr-review は汎用化しない。/ **理由**: N 体の独立レビュー＋architect メタ検証という「独立コンテキストの多角性」が品質の源泉であり、自己実行化は CC 側の確実性を落とす。
- **決定**: decruft は自己実行を正とし、サブエージェント並列は「大規模走査時の加速オプション」に格下げする。impact-investigation は既に条件付き利用なので文言調整のみ。/ **理由**: これらのサブエージェントは並列化・コンテキスト保護の手段であり品質の源泉ではない。
- **決定**: session-to-prompt / skill-refine は汎用側に残す。/ **理由**: session-to-prompt の本質（セッション→自己完結プロンプト）は環境非依存で、宛先メニューを環境適応にすれば足りる。skill-refine を CC 側に置くと「汎用スキルを査読する道具が CC 専用リポジトリにある」ねじれが生じる。
- **決定**: スキル間依存（clarify-ja 参照）は「前置き（Step 0）存在チェック → 無ければ復旧手順つきで**何も作業せずに中止**」。/ **理由**: 欠落時に黙って品質が変わる縮退より、予測可能な中止が「確実性を落とさない」制約に合う。依存は clarify-ja 1 本だけで復旧コストは 10 秒。
- **決定**: 参照パスの解決順は「自スキルの隣（`../clarify-ja/SKILL.md`）→ 実行環境の既知スキルディレクトリ（`~/.claude/skills/` / `~/.codex/skills/` / `.agents/skills/` / プロジェクトの `.claude/skills/`）」。/ **理由**: npx コピー配布・symlink 運用・リポジトリ直読みのすべてで解決できる。
- **決定**: 検証ゲートは /skill-refine による全本査読（執筆とレビューのレーン分離）。/ **理由**: 汎用化で失われた CC 向け指示精度を第三者パスで検出する。
- **決定**: 物理分割（新リポジトリ作成・ディレクトリ移動・symlink 張り替え）は人間が手動実施。このタスクは設計書の作成まで。

### 変換規約（全スキル書き換えの正本。このとおりに適用する）

1. **ツール名は能力主体＋CC 名の例示**。例: 「AskUserQuestion で確認する」→「ユーザーに選択式で確認する（Claude Code では AskUserQuestion。同等ツールが無い環境では散文で質問し回答を待つ）」。WebSearch / WebFetch も同型（「Web 検索できる環境では検索で確認し、できなければ情報不足と明記する」）。CC 名を残すのは CC 側の指示精度を保つため。
2. **サブエージェントは加速オプション**。本文は自己実行の手順として書き、「並列サブエージェントが使える環境（Claude Code の Agent ツール等）では〜してよい」を付記する。
3. **frontmatter は現状維持**。`disable-model-invocation` / `argument-hint` は他エージェントでは無視されるだけで害はなく、削ると CC 側の挙動が壊れる。
4. **`gh` 等の外部 CLI は現行規約のまま**（存在チェック＋フォールバック付き。元から環境非依存）。
5. **明示起動の確認ゲート**: `disable-model-invocation: true` の汎用スキルは、本文冒頭に「ユーザーがこのスキルを名指しで起動した場合のみ実行する。文脈からの自動適用で読み込まれた場合は、実行せずユーザーに起動意思を確認する」を置く。/ 理由: codex はこのフィールドを解釈せず、特に smart-commit（起動＝コミット実行許可）が勝手に発火すると実害が出る。
6. **フォールバック文言は各 SKILL.md が自前で持つ**(per-skill コピー配布のため、リポジトリ同梱の共有文書には依存できない)。

### 却下した代替案（再提案・再検討は不要）

- **1 リポジトリ内でのディレクトリ区画（`skills/generic|claude/`）やメタデータ区別**: `npx skills add` の既定 UX で CC 専用スキルが codex 利用者の対話ピッカーに混ざる。サブパス指定という知識を利用者に要求する。→ リポジトリ分割で解決。
- **deep-pr-review の自己実行化（汎用化）**: 独立レビューの多角性を失い CC 品質が下がる。→ CC 専用として維持。
- **clarify-ja 欠落時の縮退続行（簡易規則で続行＋代替である旨明記）**: マシンごとに出力品質が黙って変わる。→ 前置きチェック＋中止で解決。
- **全スキル一律の「能力ベース環境適応」記述**: 一律の綺麗さより「各スキルの品質源泉を特定して守る」を優先（decruft と deep-pr-review でサブエージェントの意味が違う）。
- **skill-refine のパスからの帰属自動判定**: symlink 構成で誤判定するため、モードは引数で明示する（既存 `--project` と同じ前提）。

## スコープ外

- 新リポジトリの git init・GitHub リモート作成・3 スキルのディレクトリ移動・symlink 張り替え（すべて人間が設計書に従い手動実施）
- maestro / memory-dream の内容変更(CC 専用のまま。移転は物理分割時)
- 各スキルの機能追加・仕様変更(今回は移植性リファインのみ。既存の手順・判定基準・出力形式は変えない)
- コミットの実行（指示があるまでコミットしない。コミット案の提示のみ）

## 実装方針・手順

1. **リポジトリの CLAUDE.md と全 SKILL.md を読む** → 検証: 11 本の構造と本書の記述が一致することを確認（乖離があれば作業前にユーザーへ報告）。
2. **汎用 8 本を変換規約 1〜6 で書き換える**（1 本ずつ。各スキルの個別作業項目は「対象ファイル」参照）→ 検証: 各スキルについて `grep -n '~/.claude\|AskUserQuestion\|WebSearch\|WebFetch\|サブエージェント\|Agent ツール' <skill>/SKILL.md` を実行し、残存箇所がすべて「CC 名の例示（規約 1）」「加速オプション（規約 2）」「復旧手順の例示」のいずれかであることを目視確認。
3. **deep-pr-review に依存ゲートのみ適用**（clarify-ja の Step 0 前置きチェック＋隣接優先パス解決。他は変更しない）→ 検証: 変更 diff がフェーズ 0 追記とフェーズ 5 のパス表現変更に限られること。
4. **README.md 更新**（codex 向け symlink ループ＋ npx 案内、帰属列追加）→ 検証: README の手順を新環境で実行した場合に成立するか机上トレース。
5. **CLAUDE.md のスキル設計規約更新**（他スキル参照規則を「隣接優先解決＋前置き中止ゲート＋フォールバック文言の自前持ち」へ書き換え、変換規約を追記）→ 検証: 既存規約と矛盾する記述が残っていないこと。
6. **分割設計書 `docs/split-plan.md` を作成** → 検証: 下記「分割設計書に含める内容」を全て満たすこと。
7. **/skill-refine で全 11 本を査読**（汎用 8 本は汎用基準、CC 専用 3 本は現行基準。査読は書き換えと別レーンで実施）→ 検証: 指摘ゼロ、または指摘に対処済み。

### 分割設計書に含める内容

- 新リポジトリ（名称案 claude-skills。最終名は人間が決定）の作成手順: git init、移動対象 3 ディレクトリ、git 履歴を保持する移動方法（git filter-repo 等）と保持しない単純移動の両案
- 移動後の agent-skills 側の後始末: README 表から 3 行削除、symlink 張り替えコマンド
- claude-skills 側の README 全文案（収録 3 本、CC 専用である旨、agent-skills の clarify-ja への依存と復旧手順、展開手順）
- npx skills 配布を有効化する条件（GitHub リモート作成後に `npx skills add <owner>/<repo>` が機能する旨）
- 完了確認チェックリスト（両リポジトリでスキルが CC から起動できること等）

## 対象ファイル

すべて `/Users/owner/Development/repos/agent-skills/` 配下。行番号は書き換え前の目安。

| ファイル | 個別作業項目 |
|---|---|
| `clarify-ja/SKILL.md` | 規約 5 の明示起動ゲート追加。`gh` は既にフォールバック付き（34-40 行）なので変更不要。ツール名の総点検のみ |
| `client-docs/SKILL.md` | 13 行 AskUserQuestion → 規約 1。22・24 行の clarify-ja 参照 → Step 0 前置きチェック＋隣接優先解決へ |
| `codex-review-loop/SKILL.md` | 14・56 行 AskUserQuestion → 規約 1。規約 5 ゲート追加。codex CLI 呼び出しは外部 CLI なので現状維持 |
| `decruft/SKILL.md` | フェーズ 3（80 行〜）を自己実行既定＋サブエージェント加速オプションに再構成。BEGIN/END 逐語転記節（107・184 行）は加速オプション経路用に維持 |
| `impact-investigation/SKILL.md` | 15 行 WebSearch/WebFetch・19 行 AskUserQuestion → 規約 1。23 行のサブエージェント → 規約 2 の文言へ |
| `smart-commit/SKILL.md` | 185-191 行の clarify-ja 参照 → Step 0 前置きチェック＋隣接優先解決。86 行の `~/.claude/CLAUDE.md` → 「実行環境のユーザーグローバル設定（Claude Code: `~/.claude/CLAUDE.md`、Codex: `~/.codex/AGENTS.md` 等）」。規約 5 ゲート追加 |
| `session-to-prompt/SKILL.md` | Step 2 の宛先メニューを環境適応に（Workflow / Claude Code Goal は CC でのみ提示。codex 実行時は新規セッション / codex / Claude Code 宛のみ）。AskUserQuestion → 規約 1（散文フォールバック時も 2 問構成は維持） |
| `skill-refine/SKILL.md` | 査読基準に「汎用スキル基準」を追加: 環境非依存性チェック（CC 固有ツール名の裸使用・参照解決用の絶対パス・依存の前置きゲート欠落を指摘対象に）。モードは引数 `--cc`（CC 専用スキル向け＝現行基準）で明示、既定は汎用基準 |
| `deep-pr-review/SKILL.md` | 依存ゲートのみ（手順 3 参照）。240-257 行の clarify-ja 適用記述のパス表現を隣接優先に |
| `README.md` | 展開手順に `~/.codex/skills/` への symlink ループ追加、`npx skills add` 案内追加、収録表に帰属列 |
| `CLAUDE.md` | スキル設計規約の更新（手順 5 参照） |
| `docs/split-plan.md` | 新規作成（分割設計書） |

## 規律

- **fail fast**: 実行を安全に継続できない場合は曖昧に進めず、明示的なエラーで即停止する。明示的な指示なく後方互換・互換レイヤー・暗黙のフォールバックを実装しない。例外・エラーを握り潰さない。
- **検証ゲート**: 本書「実装方針・手順」の各検証と /skill-refine 全本査読を全て通してから完了とする。
- **完了報告**: 何を・なぜ・影響範囲・実施した検証・未対応/要確認事項を日本語で報告する。
- **コミット方針**: 指示があるまでコミットしない。コミットメッセージは日本語、Co-Authored-By 等の署名行は含めない。
- **プロジェクト固有の罠**: `~/.claude/skills/` の同名エントリは本リポジトリへの symlink であり、どちらを編集しても同じ実体に反映される（二重編集・別実体と誤認しない）。スキルの説明・本文はすべて日本語で書く。既存スキルの手順・判定基準を汎用化のついでに「改善」しない（移植性以外の変更は査読で差し戻し対象）。

## 制約・規約

- リポジトリの CLAUDE.md「スキル設計規約」に全スキルが従う（自己完結・起動方式・出力の安定性・安全ゲート・git への態度・単一正本・肯定形・環境非依存）。本タスクはこの規約自体の更新も含むため、更新後の規約と書き換え後のスキルが自己整合していること。
- 単一正本の原則: 変換規約のフォールバック文言は各スキルで自然な日本語に書き下ろしてよいが、**判定基準・手順の実体**を複数スキル間で重複させない（clarify-ja の規則は参照で使う。転記しない）。

## 検証方法

- `grep -rn '~/.claude/skills/' */SKILL.md` の残存箇所を全件目視し、各箇所が「参照解決順における既知スキルディレクトリの列挙」「復旧手順の案内文中の例示」のいずれかに該当することを確認（`~/.claude/skills/` を唯一の解決手段とする参照はゼロ件）
- clarify-ja / codex-review-loop / smart-commit の 3 本（frontmatter に `disable-model-invocation: true` を持つ汎用スキル）の本文冒頭に明示起動ゲートがあること（deep-pr-review / maestro は CC 専用のため対象外。skill-refine は本文で査読基準としてこのフィールドに言及するだけで frontmatter には持たないため対象外）
- /skill-refine による全 11 本の査読が指摘ゼロで完了（またはすべて対処済み）
- （任意）`npx skills` の発見互換確認: 一時ディレクトリに `cd` してから `npx skills add /Users/owner/Development/repos/agent-skills` を実行し、対話ピッカーに 11 本が列挙されることを確認して**インストールせず中断**する。ホームディレクトリ配下（`~/.claude/skills/` 等）へ実際にインストールしない（symlink 運用を上書きするため）

## 未決事項

- 新リポジトリの最終名（案: claude-skills）と GitHub リモートの owner / 公開範囲 → 設計書には名称案のまま記載し、人間が作成時に決める
- 移動時の git 履歴保持の要否 → 設計書に両案を併記して人間に委ねる

## 起動方法

新規セッション（cwd: `/Users/owner/Development/repos/agent-skills`）で次を指示する:

```
このファイルを読んで実装してください: docs/prompt/20260711-skill-generalization-and-repo-split-prompt.md
```
