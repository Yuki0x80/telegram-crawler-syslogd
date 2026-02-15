# コミットメッセージ生成

Explain: 変更内容を解析してConventional Commitsフォーマットのコミットメッセージを1行で生成する。

Steps:
1. git status --porcelain を使って差分ファイルを列挙する
2. 変更の種類を判定 (feat, fix, refactor, docs, chore, test)
3. scope をファイルパスから推定する (例: auth, api, ui)
4. summary を英語で 100 文字以内に作る
Rules:
- Output only the commit message in format: type(scope): summary
- If multiple logical changes, prefer to suggest a single concise commit
- 絵文字は使わない



