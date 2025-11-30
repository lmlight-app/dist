# LM Light リリースワークフロー

## 概要

```
┌─────────────────────┐     ┌─────────────────────┐     ┌─────────────────────┐
│  yasuyukimai/lmlight │ --> │   GitHub Actions    │ --> │  lmlight-app/dist   │
│    (ソースコード)     │     │   (ビルド・リリース)  │     │   (配布用リポジトリ)  │
└─────────────────────┘     └─────────────────────┘     └─────────────────────┘
                                                                   │
                                                                   v
                                                        ┌─────────────────────┐
                                                        │   ユーザー (curl)    │
                                                        └─────────────────────┘
```

## リポジトリ構成

| リポジトリ | 用途 |
|-----------|------|
| `yasuyukimai/lmlight` | ソースコード (非公開) |
| `lmlight-app/dist` | 配布用 (公開) - スクリプト・バイナリ |

## リリース手順

### 1. ソースコードをpush
```bash
cd /path/to/lmlight
git add .
git commit -m "Update feature"
git push origin main
```

### 2. タグを作成してpush
```bash
git tag v2025.11.30
git push origin v2025.11.30
```

### 3. GitHub Actions が自動実行
- Linux (x64) バイナリをビルド
- macOS (arm64) バイナリをビルド
- Windows (x64) バイナリをビルド
- フロントエンドをビルド
- `lmlight-app/dist` にリリースを作成

### 4. 進捗確認
https://github.com/yasuyukimai/lmlight/actions

## GitHub Actions 設定

### シークレット
| 名前 | 説明 |
|------|------|
| `DIST_RELEASE_TOKEN` | `lmlight-app/dist` へのリリース用 PAT (Classic, `repo` scope) |

### ワークフロー
`.github/workflows/release.yml` がタグpush時に実行される。

## ユーザーのインストール方法

### macOS
```bash
curl -fsSL https://raw.githubusercontent.com/lmlight-app/dist/main/scripts/install-macos.sh | bash
```

### Linux
```bash
curl -fsSL https://raw.githubusercontent.com/lmlight-app/dist/main/scripts/install-linux.sh | bash
```

### Windows
```powershell
irm https://raw.githubusercontent.com/lmlight-app/dist/main/scripts/install-windows.ps1 | iex
```

### Docker
```bash
curl -fsSL https://raw.githubusercontent.com/lmlight-app/dist/main/scripts/install-docker.sh | bash
```

## インストールスクリプトの動作

### ダウンロードされるファイル
| ファイル | 取得元 |
|---------|--------|
| `lmlight-api-{os}-{arch}` | GitHub Releases |
| `lmlight-web.tar.gz` | GitHub Releases |

### 自動生成されるファイル
| ファイル | 説明 |
|---------|------|
| `.env` | 設定ファイル (テンプレート) - **初回のみ生成** |
| `start.sh` | 起動スクリプト |
| `stop.sh` | 停止スクリプト |

### ユーザーが用意するファイル
| ファイル | 説明 |
|---------|------|
| `license.lic` | ライセンスファイル - **手動配置が必要** |

## .env と license.lic の扱い

### .env (設定ファイル)
- **ダウンロードされない** - インストールスクリプトが生成
- 初回インストール時のみ作成 (既存ファイルは上書きしない)
- デフォルト値が設定されたテンプレート

```bash
# インストールスクリプト内の処理
[ ! -f "$INSTALL_DIR/.env" ] && cat > "$INSTALL_DIR/.env" << 'EOF'
# LM Light Configuration
DATABASE_URL=postgresql://lmlight:lmlight@localhost:5432/lmlight
OLLAMA_BASE_URL=http://localhost:11434
LICENSE_PATH=./license.lic
...
EOF
```

### license.lic (ライセンスファイル)
- **含まれていない** - ユーザーが手動で配置
- インストール完了後、ユーザーに配布されたライセンスファイルを配置する必要がある

```
~/.local/lmlight/
├── api
├── web/
├── .env           # 自動生成
├── license.lic    # ← ユーザーが配置
├── start.sh
└── stop.sh
```

## ローカルビルド (開発用)

```bash
cd /path/to/lmlight
bash scripts/release.sh macos   # macOS
bash scripts/release.sh linux   # Linux
bash scripts/release.sh windows # Windows
bash scripts/release.sh docker  # Docker
```

出力: `releases/` ディレクトリ

## ファイル構成

```
lmlight-app/dist/
├── README.md
├── scripts/
│   ├── install-macos.sh
│   ├── install-linux.sh
│   ├── install-windows.ps1
│   └── install-docker.sh
└── releases/        # GitHub Releases (自動)
    ├── lmlight-api-linux-x64
    ├── lmlight-api-macos-arm64
    ├── lmlight-api-windows-x64.exe
    └── lmlight-web.tar.gz
```
