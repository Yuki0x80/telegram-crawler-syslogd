# コードレビュー: コミット「設定追加」

## 1. 変更ファイルの概要

| ファイル | 変更内容 |
|---------|---------|
| `.gitignore` | `jsonl_to_syslog.py` を除外に追加 |
| `README.md` | インストール手順・設定ガイドを大幅拡充 |
| `example.env` | 環境変数の設定例を新規追加 |
| `install.sh` | インストールスクリプトを新規追加（122行） |
| `syslog-config/README.md` | rsyslog設定ガイドを新規追加（268行） |
| `syslog-config/rsyslog.conf.example` | rsyslog設定例を新規追加（84行） |
| `systemd/telegram-crawler.service` | systemdユニットを新規追加 |
| `systemd/telegram-crawler.timer` | 10分間隔タイマーを新規追加 |
| `telegram-crawler-wrapper.sh` | ラッパースクリプトを新規追加（108行） |

---

## 2. 指摘事項（バグ・エラーハンドリング）

### 重要度: 高

#### 2.1 install.sh: GitHub 404時にHTMLをPythonとしてインストールする可能性

**問題**: `curl -sSL` で404やエラーページを取得した場合、中身があるため `[ ! -s "$TMP_FILE" ]` を通過し、エラーHTMLが `jsonl_to_syslog.py` としてインストールされる。

```bash
# 現在の実装（39-43行目）
if [ ! -s "$TMP_FILE" ]; then
    echo "✗ jsonl_to_syslog.pyのダウンロードに失敗しました"
    ...
fi
```

**修正案**:

```bash
# HTTPステータスコードを検証
if command -v curl >/dev/null 2>&1; then
    HTTP_CODE=$(curl -sSL -o "$TMP_FILE" -w "%{http_code}" "$JSONL_OVER_SYSLOG_URL")
    if [ "$HTTP_CODE" != "200" ]; then
        echo "✗ jsonl_to_syslog.pyのダウンロードに失敗しました（HTTP $HTTP_CODE）"
        rm -f "$TMP_FILE"
        exit 1
    fi
elif command -v wget >/dev/null 2>&1; then
    if ! wget -qO "$TMP_FILE" "$JSONL_OVER_SYSLOG_URL" 2>/dev/null; then
        echo "✗ jsonl_to_syslog.pyのダウンロードに失敗しました"
        rm -f "$TMP_FILE"
        exit 1
    fi
fi

if [ ! -s "$TMP_FILE" ]; then
    echo "✗ jsonl_to_syslog.pyのダウンロードに失敗しました（空のファイル）"
    rm -f "$TMP_FILE"
    exit 1
fi

# Python構文の簡易検証（先頭が shebang または docstring/import）
if ! head -5 "$TMP_FILE" | grep -qE '^(#!/usr/bin/env python|"""|\''"""\''|import )'; then
    echo "✗ ダウンロードされたファイルが有効なPythonスクリプトでない可能性があります"
    rm -f "$TMP_FILE"
    exit 1
fi
```

#### 2.2 telegram-crawler-wrapper.sh: jsonl_to_syslog.py の終了コードを確実に取得

**問題**: `if [ $? -eq 0 ]` の直前に別コマンドを挟むと、意図しない判定になる。現状は問題ないが、将来の変更で壊れやすい。

**修正案**:

```bash
# 94-100行目
python3 "$JSONL_TO_SYSLOG" --dir "$JSONL_SEND_DIR" --state-file "$JSONL_SEND_STATE_FILE"
SEND_EXIT_CODE=$?
if [ $SEND_EXIT_CODE -eq 0 ]; then
    echo "✓ 送信完了"
else
    echo "✗ 送信に失敗しました（終了コード: $SEND_EXIT_CODE）"
    exit 1
fi
```

### 重要度: 中

#### 2.3 telegram-crawler-wrapper.sh: JSONL_SEND_DIR がインストール外時の権限

**問題**: `.env` で `JSONL_SEND_DIR` を `/var/log/xxx` などにすると、`telegram-crawler` ユーザーに書き込み権限がない可能性があり、`mkdir -p` や送信処理で失敗する。

**修正案**:

```bash
# 78-85行目の前に追加
if [ ! -d "$JSONL_SEND_DIR" ]; then
    if ! mkdir -p "$JSONL_SEND_DIR" 2>/dev/null; then
        echo "✗ 送信対象ディレクトリの作成に失敗しました: $JSONL_SEND_DIR"
        echo "   実行ユーザーに書き込み権限があるか確認してください"
        exit 1
    fi
fi

if [ ! -w "$JSONL_SEND_DIR" ]; then
    echo "✗ 送信対象ディレクトリに書き込み権限がありません: $JSONL_SEND_DIR"
    exit 1
fi
```

#### 2.4 install.sh: .env の TELEGRAM_CRAWLER_OUTPUT_DIR 解析

**問題**: `grep -E "^TELEGRAM_CRAWLER_OUTPUT_DIR="` で、値に `=` が含まれると `cut -d'=' -f2` では不十分（通常は問題にならない）。

**修正案**:

```bash
# 94行目
ENV_OUTPUT_DIR=$(grep -E "^TELEGRAM_CRAWLER_OUTPUT_DIR=" "$INSTALL_DIR/.env" | head -1 | sed 's/^[^=]*=//' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
```

#### 2.5 rsyslog.conf.example: タイポ

**問題**: 49行目 `# srv/logssrvsrv/logs` は誤記で、コメント例としても不正確。

**修正案**:

```diff
-        # srv/logssrvsrv/logs
+        # action(
```

### 重要度: 低

#### 2.6 example.env: 末尾改行

**問題**: POSIX的にはテキストファイルは改行で終わるべき。

**修正案**: ファイル末尾に改行を1行追加する。

#### 2.7 telegram-crawler-wrapper.sh: .env の KEY に特殊文字

**問題**: `[ -z "${!key}" ]` で、KEY に空白や特殊文字があると予期しない動作になる。一般的な `.env` ではまれ。

**修正案**: KEY の妥当性チェックを追加するか、ドキュメントで「KEY に空白・特殊文字を使わない」と明記する。

---

## 3. エッジケース・テストの提案

### 3.1 考慮すべきエッジケース

| ケース | 現状 | 提案 |
|--------|------|------|
| ネットワーク不通でインストール | ダウンロード失敗時に終了 | ✓ 扱い妥当（HTTP検証を推奨） |
| .env 未作成で systemd 実行 | EnvironmentFile=- でエラーにしない | ✓ 妥当 |
| STATE_DIR の書き込み失敗 | 権限なしで失敗 | install で chown 済み | 明示的なエラーメッセージ追加を推奨 |
| syslog サーバ接続不可 | jsonl_to_syslog 側で例外 | 再接続・リトライは別PRで検討 |

### 3.2 テストの提案

1. **install.sh**
   - `INSTALL_DIR` / `SERVICE_USER` を変更したインストール
   - `.env` 有無両方で出力ディレクトリが正しく作成されるか
   - ダウンロード失敗時（存在しないURL等）に適切に終了するか

2. **telegram-crawler-wrapper.sh**
   - `.env` なしで実行した場合のエラー
   - `JSONL_SEND_DIR` が存在しないディレクトリの場合の挙動
   - `telegram_crawler.py` がない場合のエラーメッセージ

3. **統合**
   - systemd 起動〜ログ送信までの一連の流れ
   - TLS オフ時（TCPのみ）の動作

---

## 4. まとめ

- インストール、ラッパー、systemd、rsyslog の構成は整理されており、運用しやすい。
- 修正を強く推奨するのは「2.1 ダウンロード時のHTTP/内容検証」と「2.2 終了コードの取得」。
- 中程度のものは段階的に対応し、テストとドキュメント整備を進めるとよい。
