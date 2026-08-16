# 委譲先の指定値を CLI名=モデル@エフォートの単一書式に統一する

Status: accepted

委譲先ハーネス・モデルの指定形式がスキルごとに分かれていた — roundtable は席名キーの `--model <席>=<モデル>`、deep-pr-review は CLI名キーの `--model <CLI名>=<モデル>`、iterate-review は裸の `--model <モデル>`、concertino は奏者ラベルキーの `--harness` / `--model` / `--effort` の3フラグ。同じ「委譲先を1つ指定する」操作に4つの書式があり、ユーザーはスキルごとに形式を思い出す必要があった。また reasoning effort は concertino だけが独自フラグで受け、しかも「codex 固有」と規定していたが、tui-harness の transports 層では claude も effort 指定手段を持っており、規定と実装が食い違っていた。

**値の書式を `<CLI名>[=<モデル>[@<エフォート>]]` に統一し、正本を tui-harness の「委譲先指定値の書式」に置く。** フラグ名は統一せず、各スキルのロール・席の語彙に合わせる — 1席・レビュアー1体のスキル（sidebar / iterate-review / deep-pr-review）は `--cli`、席名を持つ roundtable は `--second` / `--third`（CLI が議長系統で固定の host だけはモデル単独形の `--host`）、ロールを持つ concertino / solista はロールフラグ自体が値を取る。複数の委譲先はフラグの繰り返しで表し、1出現が1席・1体・1奏者に対応する（キー付き値による間接指定を全廃する）。

判断の要点:

- **統一するのは値の形、フラグ名はロール語彙** — 統一の実利は「同じ形で足せる」ことにあり、フラグ名まで `--seat` 等に揃えると、席概念を持たないスキル（deep-pr-review のレビュアー等）へ語彙を輸入する副作用の方が大きい。
- **effort はフラグでなくモデル値に畳む** — `@<エフォート>` を書式に含めることで、専用フラグを増やさずに全対象スキルで effort 指定が可能になる。値は CLI ネイティブの語彙のまま `catalog.sh validate` で検証し（codex は `codex debug models`、claude は `models/claude-efforts.txt` の静的一覧が正本）、設定手段の無い CLI への `@` 付き指定は黙って読み捨てず再指定を求める。これにより concertino の「effort は codex 固有」の食い違いも解消される（claude 奏者にも effort が指定できる）。
- **旧フラグは痕跡なく撤去** — `--seats` / `--reviewer <CLI名>` / 各形の `--model` / `--harness` / `--effort` はエイリアス・互換記述を残さず削除した（公開配布物だが利用実績の互換を守る段階にないため、クリーンな破壊的変更を選ぶ）。

検討した代替案: (a) 汎用フラグ `--seat` へのフラグ名込みの統一 — 却下。上記のとおり席語彙の輸入コストが実利を上回る。(b) effort の全 CLI 共通語彙（low/medium/high）と変換表 — 却下。同じ語が CLI ごとに別強度を意味する嘘を生み、カタログに CLI を足すたび表の保守が要る。(c) 席数だけの `--seats` の存続（sidebar） — 却下。「CLI もモデルもお任せで複数席」という稀なユースケースのために、出現数＝席数の単純な規則へ複合的な埋め合わせ規則を足すことになる。

帰結: 対象6スキル（sidebar / deep-pr-review / iterate-review / roundtable / concertino / solista）の引数仕様が非互換に変わる。書式の正本が tui-harness に増えたため、対象スキルは書式の説明を自前で持たず参照する。catalog.sh の validate は `@` を全 CLI 共通の書式要素として解釈する（対応: codex / claude、非対応 CLI は明示エラー）。maestro は委譲先指定フラグを持たないため対象外。
