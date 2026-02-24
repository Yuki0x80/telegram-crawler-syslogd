# systemd 設定

`telegram-crawler` と syslog 送信を定期実行するための systemd ユニットファイルです。

## ファイル構成

| ファイル | 説明 |
|---------|------|
| `telegram-crawler.service` | 1回の実行を行うサービス（oneshot） |
| `telegram-crawler.timer` | 10分間隔でサービスを起動するタイマー |

## 実行フロー

```
telegram-crawler.timer（10分ごと）
    ↓
telegram-crawler.service 起動
    ↓
telegram-crawler-wrapper.sh 実行
    ├── 1. telegram-crawler で JSONL を生成
    └── 2. jsonl_to_syslog.py で syslog に送信
```

## インストール

`install.sh` 実行時に自動で `/etc/systemd/system/` にコピーされます。

```bash
sudo ./install.sh
```

手動でインストールする場合：

```bash
sudo cp telegram-crawler.service telegram-crawler.timer /etc/systemd/system/
# インストール先を変更する場合: INSTALL_DIR=/custom/path
INSTALL_DIR="${INSTALL_DIR:-/opt/telegram-crawler}"
sudo sed -i "s|/opt/telegram-crawler|$INSTALL_DIR|g" /etc/systemd/system/telegram-crawler.service
sudo systemctl daemon-reload
```

## 有効化・無効化

```bash
# 有効化（タイマーを起動）
sudo systemctl enable --now telegram-crawler.timer

# 無効化
sudo systemctl disable --now telegram-crawler.timer

# 状態確認
sudo systemctl status telegram-crawler.timer
```

## 手動実行

```bash
# 1回だけ実行
sudo systemctl start telegram-crawler.service

# ログを追跡
sudo journalctl -u telegram-crawler.service -f
```

## タイマー設定

- **実行間隔**: 10分ごと（毎時 0, 10, 20, 30, 40, 50 分）
- **OnCalendar**: `*:0/10`（分が 0, 10, 20, 30, 40, 50 のとき）
- **Persistent**: `true`（起動時に取りこぼし分を実行）

間隔を変更する場合は `telegram-crawler.timer` の `OnCalendar` を編集してください。

## サービス設定の要点

- **Type=oneshot**: 1回実行して終了
- **User/Group**: `telegram-crawler`（専用ユーザーで実行）
- **WorkingDirectory**: `/opt/telegram-crawler`
- **EnvironmentFile**: `/opt/telegram-crawler/.env`（`-` で存在しない場合もエラーにしない）
- **ExecStart**: ラッパースクリプト（telegram-crawler → syslog 送信の順で実行）

## トラブルシューティング

### タイマーが動かない

```bash
sudo systemctl list-timers | grep telegram
sudo systemctl status telegram-crawler.timer
```

### 実行ログの確認

```bash
sudo journalctl -u telegram-crawler.service -n 50
sudo journalctl -u telegram-crawler.service -f
```

### 失敗時の確認

```bash
# 直近の失敗
sudo journalctl -u telegram-crawler.service -p err -n 20

# .env の存在確認
ls -la /opt/telegram-crawler/.env
```
