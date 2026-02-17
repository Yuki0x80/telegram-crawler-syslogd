# Push changes
Explain: 変更をまとめて Conventional Commits で commit → 安全に push する

---
## 実行フロー
1. `git status --porcelain` を確認
   * 変更が無ければ終了
2. 変更内容を解析し **1行の Conventional Commits メッセージ** を生成
   形式:
   ```
   type(scope): summary
   ```
   Breaking Change の場合:
   ```
   type(scope)!: summary
   ```
3. 生成した内容を表示
   * 対象ファイル一覧
   * 要約メッセージ
   * ユーザー確認（--auto の場合スキップ）

4. 変更をステージ
   ```
   git add -A
   ```
5. コミット
   ```
   git commit -m "<generated message>"
   ```
6. ブランチ判定
   * 現在が `main` または `master` の場合:
     ```
     git checkout -b feature/<summary>-<timestamp>
     ```
7. push
   ```
   git push --set-upstream origin HEAD
   ```
---
## メッセージ生成ルール
### Type Rules
* docs: コメント/ドキュメントのみ
* test: テストのみ
* chore: 設定/CI/依存関係
* refactor: 挙動不変
* fix: 不具合修正
* feat: 新機能
* 迷ったら fix を優先

### Scope Rules
* ルートディレクトリ名を scope
* 複数ディレクトリの場合 core
* test / docs は除外

### Breaking Change
公開API互換性破壊がある場合 `!` を付与

### Summary Rules
* 日本語
* 命令形
* 句点なし
* ファイル名を書かない
* 100文字以内（推奨72文字）

## 制約
* 出力は1行のみ
* 絵文字禁止
* main/master へ直接 push しない
