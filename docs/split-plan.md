# 分割設計書: CC 専用スキルの新リポジトリへの移転

agent-skills から Claude Code（CC）専用スキル 4 本を専用リポジトリへ移すための作業手順書。**この文書だけを読んで人間が手動で分割作業を完遂できる**ことを目的とする。

> **実施状況（2026-07-11）**: Step 1（案B・履歴非保持）〜 Step 3 まで実施済み。新リポジトリは `/Users/owner/Development/repos/claude-skills`（`git init` 済み・未コミット）。残作業は初回コミット・GitHub リモート作成・push と完了確認チェックリストの消化。

- **移動対象**: `codex-review-loop/` `deep-pr-review/` `maestro/` `memory-dream/` の 4 ディレクトリ（codex-review-loop は当初計画の 3 本に追加で CC 専用と判断されたもの。汎用化リファインを巻き戻した改訂前の内容で移動する）
- **新リポジトリ名称案**: `claude-skills`（最終名は作成時に決定。以下は名称案で記載し、確定名で読み替える）
- **分割の理由**: `npx skills`（vercel-labs/skills）の frontmatter には対応エージェントを宣言するフィールドが無く、codex 等の利用者に CC 専用スキルを見せない唯一の頑健な手段がリポジトリ境界であるため。

## 前提の確認（作業開始前）

- [ ] agent-skills の作業ツリーがクリーン（`git status --short` が空。未コミットの変更があれば先にコミットする）
- [ ] `~/.claude/skills/` の該当エントリが agent-skills へのシンボリックリンクであることを確認: `ls -l ~/.claude/skills/codex-review-loop ~/.claude/skills/deep-pr-review ~/.claude/skills/maestro ~/.claude/skills/memory-dream`

## Step 1: 新リポジトリの作成

git 履歴の扱いで 2 案ある。どちらでも以降の手順は共通。

### 案 A: 履歴を保持する移動（git filter-repo）

移動対象 3 スキルのコミット履歴を新リポジトリへ持ち込む。`git filter-repo` が必要（`brew install git-filter-repo`）。

```sh
# 1. agent-skills を新リポジトリ用に丸ごと clone（filter-repo は fresh clone でないと拒否する）
git clone git@github.com:tmstack-io/agent-skills.git ~/Development/repos/claude-skills
cd ~/Development/repos/claude-skills

# 2. 4 ディレクトリに関する履歴だけを残す（origin 設定は filter-repo が自動で外す）
git filter-repo --path codex-review-loop --path deep-pr-review --path maestro --path memory-dream
```

### 案 B: 履歴を保持しない単純移動

履歴は agent-skills 側に残る（新リポジトリは初期コミットから開始）。手軽さ優先ならこちら。

```sh
mkdir ~/Development/repos/claude-skills
cd ~/Development/repos/claude-skills
git init -b main
cp -R ~/Development/repos/agent-skills/codex-review-loop .
cp -R ~/Development/repos/agent-skills/deep-pr-review .
cp -R ~/Development/repos/agent-skills/maestro .
cp -R ~/Development/repos/agent-skills/memory-dream .
```

### 共通: README・CLAUDE.md の整備と初回コミット

1. 下記「claude-skills 側 README 全文案」を `README.md` として保存する。
2. `CLAUDE.md` を作成する。内容は agent-skills の CLAUDE.md を底本に、次を変更する:
   - 冒頭を「Claude Code 専用スキルの正本。汎用化はしない（サブエージェント等の CC 機能が品質の源泉）」に差し替え
   - 「他スキル参照の解決順と前置きゲート」「ツール名は能力主体＋CC 名の例示」「サブエージェントは加速オプション」「明示起動の確認ゲート」の各汎用化規約を削除（CC 専用のため不要。ただし deep-pr-review が持つ clarify-ja への前置きゲートは、リポジトリ跨ぎ依存の明示として維持する）
   - skill-refine の査読は「Claude Code 上で `--myself`」と明記
3. コミットして GitHub リモートを作成・push する:

```sh
git add -A && git commit -m "claude-skills 初版: agent-skills から CC 専用スキル 4 本を移転"
gh repo create tmstack-io/claude-skills --private --source . --push   # 公開範囲は作成時に決定
```

## Step 2: agent-skills 側の後始末

```sh
cd ~/Development/repos/agent-skills
git rm -r codex-review-loop deep-pr-review maestro memory-dream
```

1. `README.md` を更新する:
   - 収録スキル表から deep-pr-review / maestro / memory-dream の 3 行を削除
   - 帰属列は全行「汎用」になるため列ごと削除してよい（残す場合は説明文から「CC 専用（移転予定）」の段落を削除）
   - 「スキル間の依存」節の deep-pr-review への言及を「claude-skills（別リポジトリ）の deep-pr-review も clarify-ja に依存する」へ変更
   - 冒頭または収録表の直後に claude-skills へのリンクを 1 行追加
2. `CLAUDE.md` を更新する: 「サブエージェントは加速オプション」の deep-pr-review 例示と、「自己完結」の現行例から deep-pr-review を外す
3. コミットする（メッセージ例: 「CC 専用スキル 3 本を claude-skills へ移転」）

## Step 3: シンボリックリンクの張り替え

CC から見えるスキルの実体を新リポジトリへ切り替える:

```sh
for s in codex-review-loop deep-pr-review maestro memory-dream; do
  rm ~/.claude/skills/"$s"
  ln -s ~/Development/repos/claude-skills/"$s" ~/.claude/skills/"$s"
done
ls -l ~/.claude/skills/ | grep claude-skills   # 4 本が新リポジトリを指すことを確認
```

`~/.codex/skills/` には元々 CC 専用スキルをリンクしていないため作業不要（codex-review-loop をリンク済みの場合のみ `rm ~/.codex/skills/codex-review-loop` で外す）。

## npx skills 配布を有効化する条件

`npx skills add` は GitHub をレジストリとするため、**GitHub リモートを作成して push した時点で**次が機能する（追加の登録作業は不要）:

```sh
npx skills add tmstack-io/claude-skills                        # 対話ピッカー（4 本が列挙される）
npx skills add tmstack-io/claude-skills --skill deep-pr-review # 単体指定
```

- リポジトリ直下のフラット配置（`<名前>/SKILL.md`）は深さ 1 の走査でそのまま発見される。配置変更は不要。
- private リポジトリの場合、インストールする側に GitHub の認証（読み取り権限）が必要。
- deep-pr-review を単体インストールする利用者には clarify-ja（agent-skills 側）の併せ導入が必要。README の依存注記がその案内を担う。

## claude-skills 側 README 全文案

````markdown
# claude-skills

自作 Claude Code **専用**スキルの正本リポジトリ。`~/.claude/skills/` からは各スキルディレクトリへのシンボリックリンクで参照する。

ここに置くスキルは、サブエージェントの並列実行・独立コンテキストの多角性・codex との相互チェックなど、Claude Code での運用構造そのものが品質の源泉であり、意図的に他エージェント向けの汎用化をしない。汎用スキル（clarify-ja ほか）は [agent-skills](https://github.com/tmstack-io/agent-skills) を参照。

## 使い方（新しいマシンでの展開）

```sh
git clone git@github.com:tmstack-io/claude-skills.git <任意のパス>
cd <任意のパス>
for s in "$PWD"/*/; do
  ln -s "${s%/}" ~/.claude/skills/"$(basename "$s")"
done
```

`npx skills add tmstack-io/claude-skills` でもインストールできる（シンボリックリンク運用との併用は同名エントリが衝突するため、マシンごとにどちらか一方に統一する）。

## 収録スキル

| スキル | 概要 |
|---|---|
| codex-review-loop | codex レビュー→修正→再レビューを GREEN までループする品質ゲート |
| deep-pr-review | GitHub PR の高精度レビュー（多エージェント＋codex＋architect メタ検証を統合レビュー1本に集約） |
| maestro | 高性能モデルを非実装の指揮者に固定し、実装・調査をサブエージェントへ委譲するセッションモード（`--deep` / `--fast` で検収深度を上書き） |
| memory-dream | Claude Code の全プロジェクト auto-memory を再編・統合する consolidation 手順 |

## 依存: agent-skills の clarify-ja

deep-pr-review は最終出力の明快化に [agent-skills](https://github.com/tmstack-io/agent-skills) の clarify-ja を使う。clarify-ja が見つからない場合、deep-pr-review はレビューを開始せずに中止して復旧手順を案内する。復旧:

```sh
npx skills add tmstack-io/agent-skills --skill clarify-ja
# または agent-skills を clone して ~/.claude/skills/clarify-ja にシンボリックリンク
```

## 編集時の前提

- スキルの査読には、Claude Code 上で agent-skills の `/skill-refine` を `--myself` を付けて使う。
- スキルを追加・改名・削除したら本 README の収録スキル表を更新する。
````

## 完了確認チェックリスト

- [ ] claude-skills に 4 スキル＋README＋CLAUDE.md があり、GitHub リモートへ push 済み
- [ ] agent-skills から 4 ディレクトリが消え、README（収録表・依存注記）と CLAUDE.md（例示）が更新済み
- [ ] `~/.claude/skills/` の 4 エントリが claude-skills を指し、残り 7 エントリが agent-skills を指す
- [ ] CC の新セッションで `/codex-review-loop`・`/deep-pr-review`・`/maestro`・`/memory-dream` が起動できる（memory-dream は「記憶の整理」でモデル起動も可）
- [ ] CC の新セッションで agent-skills 側のスキル（例: `/clarify-ja`）が従来どおり起動できる
- [ ] 一時ディレクトリで `npx skills add <ローカルパスまたは owner/repo>` を両リポジトリに対して実行し、ピッカーに claude-skills = 4 本 / agent-skills = 7 本が列挙される（確認のみ。インストールせず中断）
- [ ] deep-pr-review を実行し、フェーズ0 の clarify-ja 存在チェックが通る（隣接には無く、`~/.claude/skills/clarify-ja` で解決される）

## 未決事項（作成時に人間が決める）

- 新リポジトリの最終名（案: claude-skills）と GitHub の owner / 公開範囲
- git 履歴保持の要否（案 A / 案 B）
