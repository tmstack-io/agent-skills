# slack-research セットアップ

`.slack-research-env` が無いプロジェクトで slack-research を使えるようにする手順。スキル本体（SKILL.md）の Step 0 で中止したときに、この手順を案内する。

1. https://api.slack.com/apps で「Create New App → From a manifest」を選び、対象ワークスペースに次の manifest でアプリを作成する:

   ```yaml
   display_information:
     name: slack-research
     description: Read-only workspace research for coding agents
   oauth_config:
     scopes:
       user:
         - search:read
         - channels:read
         - channels:history
         - groups:read
         - groups:history
         - im:read
         - im:history
         - mpim:read
         - mpim:history
         - users:read
   ```

2. 「Install App to Workspace」で自分のアカウントに認可し、表示された **User OAuth Token（`xoxp-` で始まる）** をコピーする（Bot Token `xoxb-` ではない。検索 API が使えるのは User Token のみ）。
3. プロジェクト直下に `.slack-research-env` を作成する:

   ```sh
   # 必須
   SLACK_TOKEN=xoxp-...
   # 任意: 既定の調査範囲を絞る（未指定なら全チャンネル・DM 横断）
   SLACK_CHANNELS=#general,#proj-x,@yamada
   ```

4. git リポジトリなら `.gitignore` に `.slack-research-env` を追加する。
5. ワークスペースが複数あるときは、プロジェクトごとにそのワークスペースで手順1〜3を繰り返す（1プロジェクト＝1ワークスペース）。

クライアントのワークスペースでアプリ作成が管理者承認制の場合は、承認を依頼するか、管理者にこの manifest を渡して作成してもらう。
