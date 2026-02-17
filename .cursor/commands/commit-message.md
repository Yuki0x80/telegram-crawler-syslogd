Explain: ステージされた変更を解析し、Conventional Commits 形式の1行コミットメッセージを生成する。

Steps:
1. `git status --porcelain` を使って変更ファイルを列挙する
2. Type Rules と Path Heuristics に従って変更タイプを判定する
3. Breaking Change を検出する
4. Scope Rules に従って scope を推定する
5. 日本語の summary を生成する（100文字以内、推奨72文字以内）
6. 次の形式で出力
   type(scope): summary
7. git commit -m "<生成したメッセージ>" を実行

Type Rules:
- コメントやドキュメントのみの変更 → docs
- テストのみの変更 → test
- 依存関係 / 設定 / ビルド / CI / ツール変更 → chore
- 挙動を変えないリファクタ → refactor
- 不具合修正 → fix
- 新しい挙動や機能 → feat
- feat と fix で迷う場合は fix を優先

Path Heuristics:
- *.md → docs
- test/, __tests__/ → test
- package.json, pyproject.toml, requirements*, lockfiles → chore
- .github/, CI → chore
- rename のみ → refactor

Breaking Change:
公開 API / CLI / スキーマの互換性を壊す変更がある場合、
type の直後に "!" を付ける

Scope Rules:
- ルート直下ディレクトリ名を scope とする
- 複数ディレクトリの場合は core を使用
- test/docs ディレクトリは除外
- 拡張子を含めない

Ignore:
- dist/, build/, coverage/, .cache/, 生成ファイル

Summary Rules:
- 命令形で書く
- 句点を付けない
- ファイル名を書かない
- 日本語で記述
- 100文字以内（推奨72文字）

Priority:
feat > fix > refactor > perf > test > docs > chore

Rules:
- 出力は1行のみ: type(scope): summary
- Breaking Change の場合: type(scope)!: summary
- できるだけ単一の簡潔なコミットを提案
- 絵文字は使わない
