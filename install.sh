#!/bin/bash
# telegram-crawler-syslogd インストールスクリプト

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== telegram-crawler-syslogd インストール ==="
echo ""

# 設定
INSTALL_DIR="${INSTALL_DIR:-/opt/telegram-crawler}"
SERVICE_USER="${SERVICE_USER:-telegram-crawler}"
STATE_DIR="/var/lib/jsonl-over-syslog"

# 1. 必要なディレクトリを作成
echo "1. ディレクトリを作成..."
# インストールディレクトリ（jsonl_to_syslog.pyとラッパースクリプトを配置）
sudo mkdir -p "$INSTALL_DIR"
# deployディレクトリ（ラッパースクリプトを配置）
sudo mkdir -p "$INSTALL_DIR/deploy"
# 状態ファイル保存ディレクトリ（前回処理日時を記録）
sudo mkdir -p "$STATE_DIR"

# 2. jsonl_to_syslog.pyをGitHubから取得
echo "2. jsonl_to_syslog.pyをGitHubから取得..."
JSONL_OVER_SYSLOG_URL="https://raw.githubusercontent.com/Yuki0x80/jsonl-over-syslog/main/jsonl_to_syslog.py"
TMP_FILE=$(mktemp)

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
else
    echo "✗ curlまたはwgetが必要です"
    exit 1
fi

if [ ! -s "$TMP_FILE" ]; then
    echo "✗ jsonl_to_syslog.pyのダウンロードに失敗しました（空のファイル）"
    rm -f "$TMP_FILE"
    exit 1
fi

# Python構文の簡易検証（shebang、docstring、importのいずれかが含まれること）
if ! head -5 "$TMP_FILE" | grep -qE '^#!/usr/bin/env python|^"""|^import '; then
    echo "✗ ダウンロードされたファイルが有効なPythonスクリプトでない可能性があります"
    rm -f "$TMP_FILE"
    exit 1
fi

sudo cp "$TMP_FILE" "$INSTALL_DIR/jsonl_to_syslog.py"
sudo chmod +x "$INSTALL_DIR/jsonl_to_syslog.py"
rm -f "$TMP_FILE"
echo "   jsonl_to_syslog.pyを取得しました"

# ラッパースクリプトをコピー
if [ -f "$SCRIPT_DIR/telegram-crawler-wrapper.sh" ]; then
    sudo cp "$SCRIPT_DIR/telegram-crawler-wrapper.sh" "$INSTALL_DIR/deploy/"
    sudo chmod +x "$INSTALL_DIR/deploy/telegram-crawler-wrapper.sh"
    echo "   ラッパースクリプトをコピーしました"
fi

# 3. systemdサービス用の専用ユーザーを作成（存在しない場合）
# このユーザーはsystemdサービスでtelegram-crawlerを実行するために使用されます
# -r: システムユーザーとして作成（ログイン不可）
# -s /bin/false: ログインシェルを無効化
if ! id "$SERVICE_USER" &>/dev/null; then
    echo "3. systemdサービス用ユーザーを作成: $SERVICE_USER"
    sudo useradd -r -s /bin/false "$SERVICE_USER" || true
else
    echo "3. ユーザーは既に存在します: $SERVICE_USER"
fi

# 4. 権限を設定
echo "4. 権限を設定..."
sudo chown -R "$SERVICE_USER:$SERVICE_USER" "$INSTALL_DIR"
sudo chown -R "$SERVICE_USER:$SERVICE_USER" "$STATE_DIR"

# 5. telegram-crawlerサービスファイルをインストール（ラッパースクリプト使用）
if [ -f "$SCRIPT_DIR/systemd/telegram-crawler.service" ]; then
    echo "5. telegram-crawlerサービスファイルをインストール..."
    sudo cp "$SCRIPT_DIR/systemd/telegram-crawler.service" /etc/systemd/system/
    sudo cp "$SCRIPT_DIR/systemd/telegram-crawler.timer" /etc/systemd/system/
    
    # サービスファイル内のパスを更新（WorkingDirectory、EnvironmentFile、ExecStart、Environment）
    sudo sed -i "s|/opt/telegram-crawler|$INSTALL_DIR|g" /etc/systemd/system/telegram-crawler.service
    
    sudo systemctl daemon-reload
    echo "   telegram-crawlerサービスファイルをインストールしました"
else
    echo "5. telegram-crawlerサービスファイルが見つかりません（スキップ）"
fi

# 6. 出力ディレクトリを作成（デフォルト、または.envファイルから読み込む）
DEFAULT_OUTPUT_DIR="$INSTALL_DIR/output"
# .envファイルが存在する場合、TELEGRAM_CRAWLER_OUTPUT_DIRを読み込む
if [ -f "$INSTALL_DIR/.env" ]; then
    # .envファイルからTELEGRAM_CRAWLER_OUTPUT_DIRを読み込む
    ENV_OUTPUT_DIR=$(grep -E "^TELEGRAM_CRAWLER_OUTPUT_DIR=" "$INSTALL_DIR/.env" | head -1 | sed 's/^[^=]*=//' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    if [ -n "$ENV_OUTPUT_DIR" ]; then
        DEFAULT_OUTPUT_DIR="$ENV_OUTPUT_DIR"
    fi
fi

if [ ! -d "$DEFAULT_OUTPUT_DIR" ]; then
    echo "6. 出力ディレクトリを作成: $DEFAULT_OUTPUT_DIR"
    sudo mkdir -p "$DEFAULT_OUTPUT_DIR"
    sudo chown "$SERVICE_USER:$SERVICE_USER" "$DEFAULT_OUTPUT_DIR"
else
    echo "6. 出力ディレクトリは既に存在します: $DEFAULT_OUTPUT_DIR"
    sudo chown "$SERVICE_USER:$SERVICE_USER" "$DEFAULT_OUTPUT_DIR" 2>/dev/null || true
fi

# 7. example.envをインストールディレクトリにコピー
if [ -f "$SCRIPT_DIR/example.env" ]; then
    sudo cp "$SCRIPT_DIR/example.env" "$INSTALL_DIR/example.env"
    sudo chown "$SERVICE_USER:$SERVICE_USER" "$INSTALL_DIR/example.env"
    echo "7. example.envをコピーしました"
fi

# 8. .envファイルの確認
if [ ! -f "$INSTALL_DIR/.env" ]; then
    echo "8. .envファイルを作成してください:"
    echo "   sudo cp $INSTALL_DIR/example.env $INSTALL_DIR/.env"
    echo "   sudo nano $INSTALL_DIR/.env"
else
    echo "8. .envファイルは既に存在します"
fi

echo ""
echo "✓ インストール完了！"
echo ""
echo "次のステップ:"
echo "1. .envファイルを作成: sudo cp $INSTALL_DIR/example.env $INSTALL_DIR/.env"
echo "2. .envを編集: sudo nano $INSTALL_DIR/.env"
echo "3. telegram-crawlerサービスを有効化: sudo systemctl enable --now telegram-crawler.timer"
echo "4. 状態を確認: sudo systemctl status telegram-crawler.timer"
