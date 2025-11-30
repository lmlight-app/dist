#!/bin/bash
# LM Light Setup for Linux
set -e

SUDO=""
[ "$EUID" -ne 0 ] && SUDO="sudo"

echo "Setting up LM Light environment..."

$SUDO apt update -qq

# Install dependencies
command -v node &>/dev/null || { curl -fsSL https://deb.nodesource.com/setup_20.x | $SUDO bash - && $SUDO apt install -y nodejs; }
command -v psql &>/dev/null || $SUDO apt install -y postgresql postgresql-contrib
command -v ollama &>/dev/null || curl -fsSL https://ollama.com/install.sh | sh

# Start services
pg_isready -q 2>/dev/null || { $SUDO systemctl start postgresql; $SUDO systemctl enable postgresql; }
pgrep -x "ollama" >/dev/null || ollama serve >/dev/null 2>&1 &

# Setup database
sleep 2
$SUDO -u postgres psql -c "CREATE USER lmlight WITH PASSWORD 'lmlight';" 2>/dev/null || true
$SUDO -u postgres psql -c "CREATE DATABASE lmlight OWNER lmlight;" 2>/dev/null || true

# Download model
ollama pull gemma3:4b 2>/dev/null || true

echo "Done. Run install-linux.sh next."
