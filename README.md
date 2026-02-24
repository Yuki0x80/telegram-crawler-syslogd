# telegram-crawler-syslogd

`telegram-crawler`と`jsonl-over-syslog`を統合し、Telegramメッセージを収集してsyslog経由でログ集約サーバに送信するシステムです。

## 概要

1. `telegram-crawler`がTelegramメッセージを収集し、JSONLファイルとして出力
2. `jsonl_to_syslog.py`が出力されたJSONLファイルを自動検出し、syslog経由でログ集約サーバに送信
3. systemdで定期実行（10分ごと）

## 前提条件

- Ubuntu（Python 3.6以上）
- `telegram-crawler`がインストール済み（`/opt/telegram-crawler`に配置）
- syslogサーバ（rsyslogなど）が設定済み

**注意**: `INSTALL_DIR=/custom/path sudo ./install.sh` でインストール先を変更した場合、そのパスに`telegram-crawler`を配置してください。

## インストール手順

### 1. リポジトリをクローン

```bash
git clone https://github.com/Yuki0x80/telegram-crawler-syslogd.git
cd telegram-crawler-syslogd
```

### 2. インストールスクリプトを実行

```bash
sudo ./install.sh
```

インストールスクリプトは以下を自動実行します：
- `jsonl_to_syslog.py`をGitHubから取得して`/opt/telegram-crawler`に配置
- ラッパースクリプトとsystemdサービスファイルをインストール
- systemdサービス用ユーザー（`telegram-crawler`）を作成
- 必要なディレクトリを作成

**注意**: インターネット接続が必要です（GitHubから`jsonl_to_syslog.py`をダウンロード）

### 3. .envファイルを作成（必須）

```bash
sudo cp /opt/telegram-crawler/example.env /opt/telegram-crawler/.env
sudo nano /opt/telegram-crawler/.env
```

インストールスクリプトは`example.env`をインストールディレクトリにコピーします。上記で`.env`にコピーして編集してください。

最低限の設定（編集が必要な項目）：

```bash
# ディレクトリ設定（telegram-crawlerのconfig.iniと一致させる）
TELEGRAM_CRAWLER_OUTPUT_DIR=/opt/telegram-crawler/output
JSONL_SEND_DIR=/opt/telegram-crawler/output

# Syslog設定（必須）
SYSLOG_HOST=your-syslog-server.example.com
SYSLOG_PORT=6514
SYSLOG_PROTOCOL=tls
SYSLOG_CA_CERT=/etc/ssl/certs/ca.crt
SYSLOG_APP_NAME=telegram-crawler
```

### 4. systemdサービスを有効化

```bash
sudo systemctl enable --now telegram-crawler.timer
```

### 5. 動作確認

```bash
sudo systemctl status telegram-crawler.timer
sudo journalctl -u telegram-crawler.service -f
```

## 設定値（環境変数）

### ディレクトリ設定

| 変数名 | 説明 | デフォルト値 | 必須 |
|--------|------|--------------|------|
| `TELEGRAM_CRAWLER_OUTPUT_DIR` | telegram-crawlerの出力ディレクトリ | `/opt/telegram-crawler/output` | 必須 |
| `JSONL_SEND_DIR` | jsonl_to_syslog.pyで送信するディレクトリ | `TELEGRAM_CRAWLER_OUTPUT_DIR`の値 | 必須 |
| `JSONL_SEND_STATE_FILE` | 状態ファイルのパス | `/var/lib/jsonl-over-syslog/.last_run` | 任意 |

**重要**: `TELEGRAM_CRAWLER_OUTPUT_DIR`は`telegram-crawler`の`config.ini`で指定した出力ディレクトリと一致させること

### Syslog設定

| 変数名 | 説明 | デフォルト値 | 必須 |
|--------|------|--------------|------|
| `SYSLOG_HOST` | syslogサーバのホスト名 | `localhost` | 必須 |
| `SYSLOG_PORT` | syslogサーバのポート番号 | `5140` (TCP/UDP), `6514` (TLS) | 必須 |
| `SYSLOG_PROTOCOL` | プロトコル (`udp`, `tcp`, `tls`) | `tcp` | 必須 |
| `SYSLOG_CA_CERT` | CA証明書のパス（TLS用） | - | TLS使用時は必須 |
| `SYSLOG_APP_NAME` | アプリケーション名 | `jsonl-over-syslog` | 任意 |
| `SYSLOG_FACILITY` | syslog facility (0-23) | `16` (local0) | 任意 |
| `SYSLOG_SEVERITY` | syslog severity (0-7) | `6` (informational) | 任意 |
| `SYSLOG_DELAY` | 各行送信間の遅延（秒） | `0.0` | 任意 |
| `SYSLOG_CLIENT_CERT` | クライアント証明書のパス（TLS用） | - | 通常不要 |
| `SYSLOG_CLIENT_KEY` | クライアント秘密鍵のパス（TLS用） | - | 通常不要 |
| `SYSLOG_NO_VERIFY` | 証明書検証を無効化 | `false` | 非推奨 |

## 実行順序

1. **インストール**: `sudo ./install.sh`
2. **設定**: `example.env`を`.env`にコピーして編集（`sudo cp /opt/telegram-crawler/example.env /opt/telegram-crawler/.env` → `sudo nano /opt/telegram-crawler/.env`）
3. **有効化**: `sudo systemctl enable --now telegram-crawler.timer`
4. **確認**: `sudo systemctl status telegram-crawler.timer`

## 実行前に必ず実行すること

1. **telegram-crawlerのインストール**: `/opt/telegram-crawler`に`telegram-crawler`をインストール済みであること
2. **telegram-crawlerの設定**: `config.ini`で出力ディレクトリを設定（`.env`の`TELEGRAM_CRAWLER_OUTPUT_DIR`と一致させる）
3. **.envファイルの作成**: `example.env`を`.env`にコピーして編集（`SYSLOG_HOST`等を設定）
4. **syslogサーバの設定**: syslogサーバ側の設定（`syslog-config/README.md`を参照）

## syslogサーバ側の設定

syslogサーバ（rsyslog）側の設定は`syslog-config/README.md`を参照してください。

主な手順：
1. `syslog-config/rsyslog.conf.example`を`/etc/rsyslog.d/99-telegram-crawler.conf`にコピー
2. TLS証明書を配置（TLSを使用する場合）
3. ログディレクトリを作成
4. rsyslogを再起動

## トラブルシューティング

### ログが送信されない

```bash
# サービスのログを確認
sudo journalctl -u telegram-crawler.service -f

# 接続をテスト
nc -zv your-syslog-server.example.com 6514

# 証明書を確認（TLS使用時）
ls -la /etc/ssl/certs/ca.crt
```

### ファイルが処理されない

```bash
# 状態ファイルを確認
cat /var/lib/jsonl-over-syslog/.last_run

# 状態ファイルをリセット（全ファイルを再処理）
sudo rm /var/lib/jsonl-over-syslog/.last_run

# ディレクトリの権限を確認
ls -la /opt/telegram-crawler/output/
```

### その他

- 詳細は`syslog-config/README.md`のトラブルシューティングセクションを参照
- systemdサービスのログ: `sudo journalctl -u telegram-crawler.service`
- rsyslogサーバ側のログ: `sudo journalctl -u rsyslog -f`

## ライセンス

MIT License

Copyright (c) 2026 Yuki Saito

## 関連リポジトリ

- [telegram-crawler](https://github.com/Yuki0x80/telegram-crawler): Telegramメッセージ収集ツール
- [jsonl-over-syslog](https://github.com/Yuki0x80/jsonl-over-syslog): JSONL→syslog変換ツール
