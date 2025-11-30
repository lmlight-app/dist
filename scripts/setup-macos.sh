#!/bin/bash
# LM Light Setup for macOS
set -e

command -v brew &>/dev/null || { echo "Homebrew required"; exit 1; }

echo "Setting up LM Light environment..."

# Install dependencies
command -v node &>/dev/null || brew install node
command -v psql &>/dev/null || brew install postgresql@16
command -v ollama &>/dev/null || brew install ollama

# Start services
pg_isready -q 2>/dev/null || brew services start postgresql@16
pgrep -x "ollama" >/dev/null || ollama serve >/dev/null 2>&1 &

# Setup database
sleep 2
psql -d postgres -c "CREATE USER lmlight WITH PASSWORD 'lmlight';" 2>/dev/null || true
psql -d postgres -c "CREATE DATABASE lmlight OWNER lmlight;" 2>/dev/null || true

# Download model
ollama pull gemma3:4b 2>/dev/null || true

echo "Done. Run install-macos.sh next."
