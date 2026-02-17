# Architecture Rules

このプロジェクトはレイヤードアーキテクチャを採用する。
AIは責務の境界を越えて実装してはならない。

依存方向は常に上 → 下 のみ。
逆方向の依存は禁止。

UI → Application → Domain → Infrastructure

---

## UI Layer
(Vue / HTTP Handler)

責務:
- 入出力の変換
- リクエスト検証
- レスポンス整形

禁止:
- DBアクセス
- ビジネスロジック
- SQL
- 外部API直接呼び出し

UI は Application 層のみ呼び出す

---

## Application Layer
(Service / Usecase)

責務:
- ビジネスフロー制御
- トランザクション管理
- 複数ドメインの調停

禁止:
- SQL記述
- ORM直接操作
- HTTPレスポンス生成

Application は Domain を呼び出す
Repository interface のみ使用可

---

## Domain Layer
(Entity / ValueObject / Business Rule)

責務:
- ビジネスルール
- 状態遷移
- 不変条件の保証

禁止:
- DB
- HTTP
- 環境変数
- 外部ライブラリ依存

純粋ロジックのみ記述する

---

## Infrastructure Layer
(DB / External API / Repository実装)

責務:
- 永続化
- 外部サービス通信

禁止:
- ビジネスルール
- バリデーション
- 状態遷移

interface の実装のみ行う

---

## 重要ルール

AIは次を守ること:

1. 既存レイヤを跨ぐ実装をしない
2. 下位層から上位層を参照しない
3. ロジックは可能な限り Domain に置く
4. UI はデータ変換のみ行う
5. 外部I/O は Infrastructure に隔離する

---

## 違反例

NG: handler → repository 直接呼び出し
NG: component → fetch 直接呼び出し
NG: domain → DBアクセス
NG: repository → validation
