# Create PR and push（プルリク作成＆プッシュ）

Explain:
このコマンドは、作業中の変更を要約し、Conventional Commits 形式のコミットメッセージを生成してから、
新規ブランチを作成（必要時）、コミット、リモートへ push、そして GitHub に PR（デフォルトは Draft）を作成します。
（実行には Cursor の Agent と Shell 実行許可、および GitHub CLI（gh）の認証が必要です）

Inputs:
- pr_mode: "draft" または "ready"（デフォルト: "draft"）
- reviewers: カンマ区切りの GitHub ユーザー名（例: "alice,bob"）（任意）
- labels: カンマ区切りのラベル（例: "ready-for-review,backend"）（任意）
- base: ベースブランチ名（デフォルト: "main"）

Steps:
1. `git status --porcelain` で差分を確認。変更が無ければ "No changes" を出力して終了。
2. 現在のブランチを取得（`git rev-parse --abbrev-ref HEAD`）。
   - 現在ブランチが `main` または `master` の場合は、新しいブランチ名を生成：
     - 形式: `feature/<scope>-YYYYMMDDHHMM`（scope は変更ファイルの先頭パスから推定）
     - `git checkout -b <newbranch>`
   - それ以外のブランチであればそのまま続行（ただし main 直押しは禁止ルールに従う）。
3. `commit-message` コマンド（プロジェクトにある `.cursor/commands/commit-message.md` のロジック）を呼び、Conventional Commits フォーマットのメッセージを生成する。
4. `git add -A`
5. `git commit -m "<生成されたコミットメッセージ>"`
6. `git push -u origin <branch>`
7. PR 本文を生成するために一時ファイル `pr_body.md` を作成。本文には以下を含める：
   - 要約（3〜5文）
   - テスト手順
   - 関連Issue（自動検出があれば）
   - チェックリスト（例: テスト追加, Lint通過）
8. `gh pr create` を使って PR を作成
   - デフォルトは Draft: `gh pr create --base <base> --head <branch> --title "<タイトル>" --body-file pr_body.md --draft`
   - `pr_mode=ready` の場合は Draft ではなく Ready で作成
9. レビュワーとラベルの追加（入力があれば `gh pr edit --add-reviewer` / `--add-label` を実行）
10. 作成した PR の URL を出力して終了

Rules（安全ルール: 必ず守る）:
- main / master への直接 push を禁止する（main 上なら必ず新規ブランチを作る）
- force push を行わない
- 50 ファイル以上の変更がある場合は自動 push を中断して要約を表示し、ユーザーの確認を求める
- `credentials`, `secret`, `key`, `password` を含むファイルが差分に含まれている場合は自動処理を中断して詳細を表示する
- 自動 PR はデフォルトで Draft で作成する（明示的に ready を指定した場合のみ Ready）
- 外部機密情報（env, .env, ci/secrets 等）は PR 本文に書き出さない

Output:
- 実行ログ（差分要約、生成されたコミットメッセージ等）を表示
- 最終的に作成した PR の URL を返す

Usage example:
/Create PR and push pr_mode=draft reviewers=alice,bob labels=ready-for-review

Notes:
- 実行前に `gh auth status` を満たしていること（`gh auth login` または `GITHUB_TOKEN` の設定）。
- Agent に shell 実行権限を与えた後に実行してください。許可前は何も行いません。
- コマンドの一部（例: commit message の生成）は対話形式でユーザー確認を挟むよう実装できます。安全優先なら「要確認モード」をデフォルトにしてください。
