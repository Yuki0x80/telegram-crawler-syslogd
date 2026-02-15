#!/bin/bash
# telegram-crawler実行後に自動的にjsonl_to_syslog.pyを実行するラッパースクリプト
#
# このスクリプトは以下の処理を行います：
# 1. telegram-crawlerを実行してJSONLファイルを生成
# 2. 前回実行以降に作成されたJSONLファイルをsyslog経由で送信
#
# 設定は.envファイルから読み込まれます（systemdサービス経由で実行される場合）

set -e

# 基本設定（環境変数またはデフォルト値）
# systemdサービス経由で実行される場合、WorkingDirectoryが設定されている
# PWD（現在の作業ディレクトリ）を使用するか、環境変数から取得
TELEGRAM_CRAWLER_DIR="${TELEGRAM_CRAWLER_DIR:-${PWD:-/opt/telegram-crawler}}"
TELEGRAM_CRAWLER_SCRIPT="${TELEGRAM_CRAWLER_SCRIPT:-telegram_crawler.py}"
JSONL_TO_SYSLOG="${JSONL_TO_SYSLOG:-$TELEGRAM_CRAWLER_DIR/jsonl_to_syslog.py}"

# .envファイルから環境変数を読み込む（存在する場合）
# systemdサービス経由で実行される場合、EnvironmentFileで既に読み込まれている可能性がある
# ここでは念のため再度読み込む（既存の環境変数は上書きしない）
ENV_FILE="${ENV_FILE:-$TELEGRAM_CRAWLER_DIR/.env}"
if [ -f "$ENV_FILE" ]; then
    # .envファイルから環境変数を読み込む（コメント行と空行を除外）
    # 既存の環境変数は上書きしない（systemdのEnvironmentFileで設定済みの値を優先）
    while IFS= read -r line || [ -n "$line" ]; do
        # コメント行と空行をスキップ
        line=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        [[ "$line" =~ ^#.*$ ]] && continue
        [[ -z "$line" ]] && continue
        [[ ! "$line" =~ = ]] && continue
        
        # KEY=VALUE形式を解析
        key="${line%%=*}"
        value="${line#*=}"
        key=$(echo "$key" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        value=$(echo "$value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        
        # 既に環境変数が設定されている場合はスキップ
        [ -z "${!key}" ] && export "$key"="$value"
    done < "$ENV_FILE"
fi

# ディレクトリ設定（.envファイルから読み込まれる、またはデフォルト値）
TELEGRAM_CRAWLER_OUTPUT_DIR="${TELEGRAM_CRAWLER_OUTPUT_DIR:-$TELEGRAM_CRAWLER_DIR/output}"
JSONL_SEND_DIR="${JSONL_SEND_DIR:-$TELEGRAM_CRAWLER_OUTPUT_DIR}"
JSONL_SEND_STATE_FILE="${JSONL_SEND_STATE_FILE:-/var/lib/jsonl-over-syslog/.last_run}"

echo "=== telegram-crawler実行 ==="
echo ""

# telegram-crawlerを実行
cd "$TELEGRAM_CRAWLER_DIR"
if [ -f "$TELEGRAM_CRAWLER_SCRIPT" ]; then
    echo "1. telegram-crawlerを実行中..."
    echo "   出力ディレクトリ: $TELEGRAM_CRAWLER_OUTPUT_DIR"
    
    # telegram-crawlerに出力ディレクトリを指定（config.iniまたは引数で設定されている場合）
    # ここでは環境変数から読み込んだディレクトリを確認のみ
    python3 "$TELEGRAM_CRAWLER_SCRIPT" "$@"
    CRAWLER_EXIT_CODE=$?
    
    if [ $CRAWLER_EXIT_CODE -ne 0 ]; then
        echo "✗ telegram-crawlerの実行に失敗しました（終了コード: $CRAWLER_EXIT_CODE）"
        exit $CRAWLER_EXIT_CODE
    fi
    
    echo "✓ telegram-crawlerの実行が完了しました"
    echo ""
else
    echo "✗ telegram-crawlerスクリプトが見つかりません: $TELEGRAM_CRAWLER_SCRIPT"
    exit 1
fi

# 処理完了後、前回実行以降に作成されたファイルを自動的に処理
echo "2. 前回実行以降に作成されたJSONLファイルをsyslog経由で送信..."
if [ -f "$JSONL_TO_SYSLOG" ]; then
    # ディレクトリの存在確認と作成
    if [ ! -d "$JSONL_SEND_DIR" ]; then
        echo "   送信対象ディレクトリが存在しないため作成します: $JSONL_SEND_DIR"
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
    
    # 前回実行以降に作成されたファイルを自動的に処理
    # --dirオプションにより、前回実行以降に作成されたファイルのみが送信される
    echo "   送信対象ディレクトリ: $JSONL_SEND_DIR"
    echo "   状態ファイル: $JSONL_SEND_STATE_FILE"
    
    # .envファイルの設定を使用してjsonl_to_syslog.pyを実行
    # jsonl_to_syslog.pyは自動的に.envファイルを読み込むため、
    # ここでは--dirと--state-fileのみを明示的に指定
    python3 "$JSONL_TO_SYSLOG" --dir "$JSONL_SEND_DIR" --state-file "$JSONL_SEND_STATE_FILE"
    SEND_EXIT_CODE=$?
    if [ $SEND_EXIT_CODE -eq 0 ]; then
        echo "✓ 送信完了"
    else
        echo "✗ 送信に失敗しました（終了コード: $SEND_EXIT_CODE）"
        exit 1
    fi
else
    echo "✗ jsonl_to_syslog.pyが見つかりません: $JSONL_TO_SYSLOG"
    exit 1
fi

echo ""
echo "✓ すべての処理が完了しました"
