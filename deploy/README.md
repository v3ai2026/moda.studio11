部署到 Ubuntu 伺服器 — 快速指南

前提條件
- 目標伺服器: Ubuntu 20.04 / 22.04（其他 Debian 系列也可，指令略有差異）。
- 有一個可以 SSH 的帳號，並且該帳號有 sudo 權限。
- 伺服器可以存取網際網路以安裝套件與抓取映像檔（或你已先上傳完整專案）。

流程概覽
1. 在伺服器上執行 `deploy/deploy-ubuntu.sh`（或手動逐步執行腳本內的命令）。
2. 腳本會安裝 Docker 與 Compose、Clone 或解壓專案、啟動 `docker compose up -d --build`，MySQL 會在啟動時自動匯入 `magicai.sql`（檔案需在 repo 根目錄）。
3. 若需使用 HTTPS，請在 Nginx 前端設定反向代理並用 Certbot 取得憑證。

快速命令範例（在伺服器上）
```bash
# 將整個專案上傳到 /opt/magicai，或在伺服器上 git clone
sudo bash /opt/magicai/deploy/deploy-ubuntu.sh /opt/magicai
```

注意事項
- 若你想使用外部資料庫（RDS / managed MySQL），修改 `docker-compose.yml` 中的 `db` 服務或把 `db` 改為外部連線設定。
- 若伺服器資源有限，請根據記憶體/CPU 調整 PHP-FPM 與 MySQL 設定或使用雲端資料庫。
- `deploy-ubuntu.sh` 預設會把 MySQL root 密碼設為 `password`，部署完請立即變更。

如要我直接幫你在遠端伺服器執行部署，請提供伺服器的作業系統、IP、以及是否允許我使用你的授權金鑰（或你可自行執行腳本）。

CI / GitHub Actions 自動部署
--------------------------------
建議在 GitHub 上使用以下 Secrets（Repository -> Settings -> Secrets）以啟用自動部署：

- `DEPLOY_HOST`：目標伺服器 IP 或 hostname
- `DEPLOY_PORT`：SSH 埠（預設 `22`）
- `DEPLOY_USER`：SSH 使用者（需有寫入 `DEPLOY_PATH` 的權限以及可 sudo）
- `DEPLOY_PATH`：部署目錄（例如 `/opt/magicai`）
- `DEPLOY_SSH_KEY`：對應 `DEPLOY_USER` 的私密金鑰（PEM 格式）

我們已包含一個範例工作流程：`.github/workflows/auto-deploy.yml`。該流程會在推送到 `main` 時：

1. 使用 `rsync` 將倉庫內容同步到遠端 `DEPLOY_PATH`（會排除 `.git`、`node_modules`、`vendor`），
2. 透過 SSH 在遠端執行 `deploy/deploy-ubuntu.sh` 以安裝/啟動 Docker 並啟動容器。

伺服器預備事項：
- 在伺服器上為 `DEPLOY_USER` 加入公鑰並允許 SSH 登入。
- 建議在 `/etc/sudoers.d/` 內為部署使用者允許以無密碼方式執行 `docker` 或特定指令（或確保 workflow 可使用 `sudo`）。
- 確保 `rsync`、`docker`、`docker compose` 在伺服器可用（`deploy-ubuntu.sh` 可自動安裝 Docker）。

若要使用容器註冊表（例如 Docker Hub 或 GHCR）而非 rsync，請告訴我，我可以改寫工作流程為：構建映像並 push 到 registry，然後遠端伺服器 pull 並重啟容器。

