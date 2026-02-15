# Push changes

Explain: ステージング・コミット・push を自動実行する

Steps:

1. git status を確認
2. 変更内容を要約
3. Conventional Commits のメッセージを生成
4. git add -A
5. git commit -m "<generated message>"
6. git push

Rules:

* 変更がない場合は何もしない
* push 前に要約を表示する
* main へ直接 push しない（ブランチがある場合）
