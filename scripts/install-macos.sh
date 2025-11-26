#!/bin/bash
# LM Light Installer for macOS
# Usage: curl -fsSL https://raw.githubusercontent.com/lmlight-app/lmlight/main/scripts/install-macos.sh | bash

set -e

BASE_URL="${LMLIGHT_BASE_URL:-https://github.com/lmlight-app/lmlight/releases/latest/download}"
INSTALL_DIR="${LMLIGHT_INSTALL_DIR:-$HOME/.local/lmlight}"
ARCH="$(uname -m)"

# Normalize arch
case "$ARCH" in
    x86_64|amd64) ARCH="amd64" ;;
    aarch64|arm64) ARCH="arm64" ;;
esac

# Database config
DB_USER="lmlight"
DB_PASSWORD="lmlight"
DB_NAME="lmlight"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

echo ""
echo -e "${BLUE}╔═══════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║          LM Light Installer for macOS                 ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════╝${NC}"
echo ""

info "Architecture: $ARCH"
info "Install directory: $INSTALL_DIR"

# Check Homebrew
if ! command -v brew &>/dev/null; then
    error "Homebrew not found. Install from: https://brew.sh"
fi
success "Homebrew found"

# Create directories
mkdir -p "$INSTALL_DIR"/{bin,frontend,data,logs,scripts}

# ============================================================
# Step 1: Download binaries
# ============================================================
info "Step 1/6: Downloading binaries..."

info "Downloading backend..."
BACKEND_FILE="lmlight-api-macos-$ARCH"
curl -fSL "$BASE_URL/$BACKEND_FILE" -o "$INSTALL_DIR/bin/lmlight-api"
chmod +x "$INSTALL_DIR/bin/lmlight-api"
success "Backend downloaded"

info "Downloading frontend..."
curl -fSL "$BASE_URL/lmlight-web.tar.gz" -o "/tmp/lmlight-web.tar.gz"
tar -xzf "/tmp/lmlight-web.tar.gz" -C "$INSTALL_DIR/frontend"
rm /tmp/lmlight-web.tar.gz
success "Frontend downloaded"

# ============================================================
# Step 2: Install system dependencies
# ============================================================
info "Step 2/6: Installing system dependencies..."

# Node.js
if ! command -v node &>/dev/null; then
    info "Installing Node.js..."
    brew install node
fi
success "Node.js: $(node -v)"

# ============================================================
# Step 3: Install PostgreSQL
# ============================================================
info "Step 3/6: Setting up PostgreSQL..."

if ! command -v psql &>/dev/null; then
    info "Installing PostgreSQL 16..."
    brew install postgresql@16
fi

# Install pgvector
if ! brew list pgvector &>/dev/null; then
    info "Installing pgvector..."
    brew install pgvector
fi

# Start PostgreSQL
if ! brew services list | grep postgresql | grep -q started; then
    info "Starting PostgreSQL..."
    brew services start postgresql@16
    sleep 3
fi
success "PostgreSQL running"

# Create database and user
info "Creating database..."
createuser -s "$DB_USER" 2>/dev/null || true
psql -d postgres -c "ALTER USER $DB_USER WITH PASSWORD '$DB_PASSWORD';" 2>/dev/null || true
createdb -O "$DB_USER" "$DB_NAME" 2>/dev/null || true
psql -d "$DB_NAME" -c "CREATE EXTENSION IF NOT EXISTS vector;" 2>/dev/null || true
success "Database created: $DB_NAME"

# Run migrations
info "Running database migrations..."
psql -d "$DB_NAME" << 'SQLEOF'
-- Enums
DO $$ BEGIN
    CREATE TYPE "UserRole" AS ENUM ('ADMIN', 'USER');
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
    CREATE TYPE "UserStatus" AS ENUM ('ACTIVE', 'INACTIVE');
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
    CREATE TYPE "MessageRole" AS ENUM ('USER', 'ASSISTANT', 'SYSTEM');
EXCEPTION WHEN duplicate_object THEN null; END $$;

-- Tables
CREATE TABLE IF NOT EXISTS "User" (
    "id" TEXT NOT NULL,
    "name" TEXT,
    "email" TEXT NOT NULL,
    "emailVerified" TIMESTAMP(3),
    "image" TEXT,
    "hashedPassword" TEXT,
    "role" "UserRole" NOT NULL DEFAULT 'USER',
    "status" "UserStatus" NOT NULL DEFAULT 'ACTIVE',
    "lastLoginAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "User_pkey" PRIMARY KEY ("id")
);

CREATE TABLE IF NOT EXISTS "Account" (
    "userId" TEXT NOT NULL,
    "type" TEXT NOT NULL,
    "provider" TEXT NOT NULL,
    "providerAccountId" TEXT NOT NULL,
    "refresh_token" TEXT,
    "access_token" TEXT,
    "expires_at" INTEGER,
    "token_type" TEXT,
    "scope" TEXT,
    "id_token" TEXT,
    "session_state" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "Account_pkey" PRIMARY KEY ("provider","providerAccountId")
);

CREATE TABLE IF NOT EXISTS "Session" (
    "sessionToken" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "expires" TIMESTAMP(3) NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS "VerificationToken" (
    "identifier" TEXT NOT NULL,
    "token" TEXT NOT NULL,
    "expires" TIMESTAMP(3) NOT NULL,
    CONSTRAINT "VerificationToken_pkey" PRIMARY KEY ("identifier","token")
);

CREATE TABLE IF NOT EXISTS "Authenticator" (
    "credentialID" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "providerAccountId" TEXT NOT NULL,
    "credentialPublicKey" TEXT NOT NULL,
    "counter" INTEGER NOT NULL,
    "credentialDeviceType" TEXT NOT NULL,
    "credentialBackedUp" BOOLEAN NOT NULL,
    "transports" TEXT,
    CONSTRAINT "Authenticator_pkey" PRIMARY KEY ("userId","credentialID")
);

CREATE TABLE IF NOT EXISTS "Bot" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "description" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "Bot_pkey" PRIMARY KEY ("id")
);

CREATE TABLE IF NOT EXISTS "Chat" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "model" TEXT NOT NULL,
    "sessionId" TEXT NOT NULL,
    "botId" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "Chat_pkey" PRIMARY KEY ("id")
);

CREATE TABLE IF NOT EXISTS "Message" (
    "id" TEXT NOT NULL,
    "chatId" TEXT NOT NULL,
    "role" "MessageRole" NOT NULL,
    "content" TEXT NOT NULL,
    "metadata" JSONB,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "Message_pkey" PRIMARY KEY ("id")
);

-- Indexes
CREATE UNIQUE INDEX IF NOT EXISTS "User_email_key" ON "User"("email");
CREATE UNIQUE INDEX IF NOT EXISTS "Session_sessionToken_key" ON "Session"("sessionToken");
CREATE UNIQUE INDEX IF NOT EXISTS "Authenticator_credentialID_key" ON "Authenticator"("credentialID");
CREATE INDEX IF NOT EXISTS "Bot_userId_idx" ON "Bot"("userId");
CREATE INDEX IF NOT EXISTS "Chat_sessionId_idx" ON "Chat"("sessionId");
CREATE INDEX IF NOT EXISTS "Chat_userId_model_idx" ON "Chat"("userId", "model");
CREATE INDEX IF NOT EXISTS "Chat_userId_idx" ON "Chat"("userId");
CREATE INDEX IF NOT EXISTS "Chat_botId_idx" ON "Chat"("botId");
CREATE INDEX IF NOT EXISTS "Message_chatId_createdAt_idx" ON "Message"("chatId", "createdAt");

-- Foreign Keys (ignore if exists)
DO $$ BEGIN
    ALTER TABLE "Account" ADD CONSTRAINT "Account_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
    ALTER TABLE "Session" ADD CONSTRAINT "Session_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
    ALTER TABLE "Authenticator" ADD CONSTRAINT "Authenticator_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
    ALTER TABLE "Bot" ADD CONSTRAINT "Bot_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
    ALTER TABLE "Chat" ADD CONSTRAINT "Chat_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
    ALTER TABLE "Chat" ADD CONSTRAINT "Chat_botId_fkey" FOREIGN KEY ("botId") REFERENCES "Bot"("id") ON DELETE CASCADE ON UPDATE CASCADE;
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
    ALTER TABLE "Message" ADD CONSTRAINT "Message_chatId_fkey" FOREIGN KEY ("chatId") REFERENCES "Chat"("id") ON DELETE CASCADE ON UPDATE CASCADE;
EXCEPTION WHEN duplicate_object THEN null; END $$;

-- Seed admin user (password: admin123)
INSERT INTO "User" ("id", "email", "name", "hashedPassword", "role", "status", "updatedAt")
VALUES (
    'admin-user-id',
    'admin@localhost.local',
    'Admin',
    '$2b$10$rQZ8K1.Q8Zy8K1.Q8Zy8KuYz8K1.Q8Zy8K1.Q8Zy8K1.Q8Zy8K1.Q',
    'ADMIN',
    'ACTIVE',
    CURRENT_TIMESTAMP
) ON CONFLICT ("id") DO NOTHING;

-- Grant permissions
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO lmlight;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO lmlight;
SQLEOF
success "Database migrations complete"

# ============================================================
# Step 4: Install Ollama
# ============================================================
info "Step 4/6: Installing Ollama..."

if ! command -v ollama &>/dev/null; then
    info "Installing Ollama..."
    brew install ollama
fi
success "Ollama installed"

# Start Ollama if not running
if ! pgrep -x "ollama" > /dev/null; then
    info "Starting Ollama..."
    ollama serve > /tmp/ollama.log 2>&1 &
    sleep 3
fi

# ============================================================
# Step 5: Download LLM models
# ============================================================
info "Step 5/6: Downloading LLM models..."

MODELS=("gemma3:4b" "nomic-embed-text")
for model in "${MODELS[@]}"; do
    if ollama list 2>/dev/null | grep -q "$model"; then
        success "$model already installed"
    else
        info "Downloading $model..."
        ollama pull "$model"
        success "$model downloaded"
    fi
done

# ============================================================
# Step 6: Create config and scripts
# ============================================================
info "Step 6/6: Creating configuration..."

# Create .env file
cat > "$INSTALL_DIR/.env" << ENVEOF
# Database
DATABASE_URL=postgresql://$DB_USER:$DB_PASSWORD@localhost:5432/$DB_NAME

# Ollama
OLLAMA_BASE_URL=http://localhost:11434

# Auth
NEXTAUTH_SECRET=$(openssl rand -base64 32)
NEXTAUTH_URL=http://localhost:3000
NEXT_PUBLIC_API_URL=http://localhost:8000
ENVEOF

# Create start script
cat > "$INSTALL_DIR/scripts/start.sh" << 'EOF'
#!/bin/bash
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Load .env
if [ -f "$PROJECT_ROOT/.env" ]; then
    export $(cat "$PROJECT_ROOT/.env" | grep -v '^#' | xargs)
fi

echo -e "${BLUE}Starting LM Light...${NC}"

# Check PostgreSQL (macOS brew services)
if ! brew services list | grep postgresql | grep -q started; then
    echo "Starting PostgreSQL..."
    brew services start postgresql@16
    sleep 2
fi

# Check Ollama
if ! pgrep -x "ollama" > /dev/null; then
    echo "Starting Ollama..."
    ollama serve > /tmp/ollama.log 2>&1 &
    sleep 3
fi

# Kill existing processes
lsof -ti:8000 | xargs kill -9 2>/dev/null || true
lsof -ti:3000 | xargs kill -9 2>/dev/null || true
sleep 1

# Start API
echo "Starting API..."
cd "$PROJECT_ROOT"
nohup "$PROJECT_ROOT/bin/lmlight-api" > "$PROJECT_ROOT/logs/api.log" 2>&1 &
echo $! > "$PROJECT_ROOT/logs/api.pid"
sleep 3

# Start Web
echo "Starting Web..."
cd "$PROJECT_ROOT/frontend"
nohup node server.js > "$PROJECT_ROOT/logs/web.log" 2>&1 &
echo $! > "$PROJECT_ROOT/logs/web.pid"
sleep 3

echo ""
echo -e "${GREEN}LM Light is running!${NC}"
echo ""
echo "  Web UI: http://localhost:3000"
echo "  API:    http://localhost:8000"
echo ""
echo "  Login:  admin@localhost.local / admin123"
echo ""
echo "  Logs:   tail -f $PROJECT_ROOT/logs/api.log"
echo "  Stop:   $PROJECT_ROOT/scripts/stop.sh"
echo ""
EOF
chmod +x "$INSTALL_DIR/scripts/start.sh"

# Create stop script
cat > "$INSTALL_DIR/scripts/stop.sh" << 'EOF'
#!/bin/bash
GREEN='\033[0;32m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "Stopping LM Light..."

# Stop by PID
[ -f "$PROJECT_ROOT/logs/web.pid" ] && kill $(cat "$PROJECT_ROOT/logs/web.pid") 2>/dev/null
[ -f "$PROJECT_ROOT/logs/api.pid" ] && kill $(cat "$PROJECT_ROOT/logs/api.pid") 2>/dev/null

rm -f "$PROJECT_ROOT/logs/"*.pid

# Force kill by port
lsof -ti:3000 | xargs kill -9 2>/dev/null || true
lsof -ti:8000 | xargs kill -9 2>/dev/null || true

echo -e "${GREEN}LM Light stopped${NC}"
EOF
chmod +x "$INSTALL_DIR/scripts/stop.sh"

# Create convenience symlink
ln -sf "$INSTALL_DIR/scripts/start.sh" "$INSTALL_DIR/start.sh"
ln -sf "$INSTALL_DIR/scripts/stop.sh" "$INSTALL_DIR/stop.sh"

echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║           LM Light installed successfully!            ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}To start:${NC} $INSTALL_DIR/start.sh"
echo -e "${BLUE}To stop:${NC}  $INSTALL_DIR/stop.sh"
echo ""
echo -e "${BLUE}Web UI:${NC}   http://localhost:3000"
echo -e "${BLUE}Login:${NC}    admin@localhost.local / admin123"
echo ""
