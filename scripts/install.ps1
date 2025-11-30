# LM Light Installer for Windows
# Usage: iwr -useb https://your-domain.com/install.ps1 | iex
#    or: .\install.ps1 -License "C:\path\to\license.lic"

param(
    [string]$License = "",
    [string]$InstallDir = "$env:LOCALAPPDATA\LMLight",
    [string]$BaseUrl = "https://github.com/yasuyukimai/lmlight/releases/latest/download"
)

$ErrorActionPreference = "Stop"
$MissingDeps = @()

# ============================================================
# Helper Functions
# ============================================================
function Write-Info { Write-Host "[INFO] $args" -ForegroundColor Blue }
function Write-Success { Write-Host "[OK] $args" -ForegroundColor Green }
function Write-Warn { Write-Host "[WARN] $args" -ForegroundColor Yellow }
function Write-Err { Write-Host "[ERROR] $args" -ForegroundColor Red; exit 1 }

function Get-Arch {
    if ([Environment]::Is64BitOperatingSystem) {
        return "amd64"
    }
    return "x86"
}

function Test-Sha256 {
    param($File, $Expected)
    $actual = (Get-FileHash -Path $File -Algorithm SHA256).Hash.ToLower()
    if ($actual -ne $Expected.ToLower()) {
        Write-Err "SHA256 mismatch for $File`nExpected: $Expected`nActual: $actual"
    }
    Write-Success "SHA256 verified: $File"
}

function Check-NodeJS {
    if (Get-Command node -ErrorAction SilentlyContinue) {
        $version = (node -v) -replace 'v', '' -split '\.' | Select-Object -First 1
        if ([int]$version -ge 18) {
            Write-Success "Node.js v$(node -v) found"
            return $true
        }
    }

    Write-Warn "Node.js 18+ not found"
    Write-Warn "Please install Node.js manually. See: $InstallDir\INSTALL.md"
    $script:MissingDeps += "nodejs"
    return $false
}

function Check-Ollama {
    if (Get-Command ollama -ErrorAction SilentlyContinue) {
        Write-Success "Ollama found"
        return $true
    }

    Write-Warn "Ollama not found"
    Write-Warn "Please install Ollama manually. See: $InstallDir\INSTALL.md"
    $script:MissingDeps += "ollama"
    return $false
}

function Check-PostgreSQL {
    if (Get-Command psql -ErrorAction SilentlyContinue) {
        Write-Success "PostgreSQL found"
        return $true
    }

    Write-Warn "PostgreSQL not found"
    Write-Warn "Please install PostgreSQL manually. See: $InstallDir\INSTALL.md"
    $script:MissingDeps += "postgresql"
    return $false
}

function Setup-Database {
    Write-Info "Setting up database..."

    $dbName = "lmlight"
    $dbUser = "lmlight"
    $dbPass = "lmlight"

    # Try to create database (requires psql in PATH)
    if (Get-Command psql -ErrorAction SilentlyContinue) {
        try {
            & psql -U postgres -c "CREATE USER $dbUser WITH PASSWORD '$dbPass';" 2>$null
            & psql -U postgres -c "CREATE DATABASE $dbName OWNER $dbUser;" 2>$null
            Write-Success "Database configured: $dbName"
        } catch {
            Write-Warn "Could not auto-configure database. Please create manually:"
            Write-Warn "  CREATE USER $dbUser WITH PASSWORD '$dbPass';"
            Write-Warn "  CREATE DATABASE $dbName OWNER $dbUser;"
        }
    }

    # Create .env file
    @"
DATABASE_URL=postgresql://${dbUser}:${dbPass}@localhost:5432/${dbName}
"@ | Out-File -FilePath "$InstallDir\.env" -Encoding UTF8

    Write-Success "Environment file created"
}

# ============================================================
# Main Installation
# ============================================================
Write-Host ""
Write-Host "============================================================"
Write-Host "  LM Light Installer for Windows"
Write-Host "============================================================"
Write-Host ""

$arch = Get-Arch
Write-Info "Architecture: $arch"
Write-Info "Install directory: $InstallDir"

# Create directories
New-Item -ItemType Directory -Force -Path "$InstallDir\bin" | Out-Null
New-Item -ItemType Directory -Force -Path "$InstallDir\frontend" | Out-Null
New-Item -ItemType Directory -Force -Path "$InstallDir\data" | Out-Null

# ============================================================
# Download Backend
# ============================================================
Write-Info "Downloading backend..."

$backendFile = "lmlight-api-windows-x64.exe"
$backendPath = "$InstallDir\bin\lmlight-api.exe"

Invoke-WebRequest -Uri "$BaseUrl/$backendFile" -OutFile $backendPath
Invoke-WebRequest -Uri "$BaseUrl/$backendFile.sha256" -OutFile "$env:TEMP\backend.sha256"

$expectedSha = (Get-Content "$env:TEMP\backend.sha256").Split(' ')[0]
Test-Sha256 -File $backendPath -Expected $expectedSha

# ============================================================
# Download Frontend
# ============================================================
Write-Info "Downloading frontend..."

$frontendArchive = "$env:TEMP\lmlight-web.tar.gz"
Invoke-WebRequest -Uri "$BaseUrl/lmlight-web.tar.gz" -OutFile $frontendArchive
Invoke-WebRequest -Uri "$BaseUrl/lmlight-web.tar.gz.sha256" -OutFile "$env:TEMP\frontend.sha256"

$expectedSha = (Get-Content "$env:TEMP\frontend.sha256").Split(' ')[0]
Test-Sha256 -File $frontendArchive -Expected $expectedSha

# Extract (requires tar, available in Windows 10+)
Write-Info "Extracting frontend..."
tar -xzf $frontendArchive -C "$InstallDir\frontend"

# ============================================================
# Download Documentation
# ============================================================
Write-Info "Downloading documentation..."
Invoke-WebRequest -Uri "$BaseUrl/INSTALL.md" -OutFile "$InstallDir\INSTALL.md"

# ============================================================
# Check Dependencies
# ============================================================
Write-Info "Checking dependencies..."

Check-NodeJS
Check-Ollama
Check-PostgreSQL

# Only setup database if PostgreSQL is available
if (Get-Command psql -ErrorAction SilentlyContinue) {
    Setup-Database
}

# ============================================================
# License File
# ============================================================
if ($License -and (Test-Path $License)) {
    Write-Info "Installing license file..."
    Copy-Item $License "$InstallDir\bin\license.lic"
    Write-Success "License installed"
} else {
    Write-Warn "No license file provided"
    Write-Warn "Place your license.lic in $InstallDir\bin\"
}

# ============================================================
# Create Launcher Scripts
# ============================================================
Write-Info "Creating launcher scripts..."

# Backend launcher
@"
@echo off
cd /d "%~dp0bin"
lmlight-api.exe
"@ | Out-File -FilePath "$InstallDir\start-api.bat" -Encoding ASCII

# Frontend launcher
@"
@echo off
cd /d "%~dp0frontend"
set PORT=3000
node server.js
"@ | Out-File -FilePath "$InstallDir\start-web.bat" -Encoding ASCII

# Combined launcher
@"
@echo off
echo Starting LM Light...

start "LM Light API" cmd /c "%~dp0start-api.bat"
timeout /t 3 /nobreak > nul
start "LM Light Web" cmd /c "%~dp0start-web.bat"

echo.
echo LM Light is running!
echo   API: http://localhost:8000
echo   Web: http://localhost:3000
echo.
pause
"@ | Out-File -FilePath "$InstallDir\start.bat" -Encoding ASCII

# ============================================================
# Create Desktop Shortcut
# ============================================================
Write-Info "Creating desktop shortcut..."

$WshShell = New-Object -ComObject WScript.Shell
$Shortcut = $WshShell.CreateShortcut("$env:USERPROFILE\Desktop\LM Light.lnk")
$Shortcut.TargetPath = "$InstallDir\start.bat"
$Shortcut.WorkingDirectory = $InstallDir
$Shortcut.Description = "LM Light - Local LLM Application"
$Shortcut.Save()

# ============================================================
# Cleanup
# ============================================================
Remove-Item "$env:TEMP\lmlight-web.tar.gz" -ErrorAction SilentlyContinue
Remove-Item "$env:TEMP\backend.sha256" -ErrorAction SilentlyContinue
Remove-Item "$env:TEMP\frontend.sha256" -ErrorAction SilentlyContinue

# ============================================================
# Done
# ============================================================
Write-Host ""
Write-Host "============================================================"
Write-Success "LM Light installed successfully!"
Write-Host "============================================================"
Write-Host ""
Write-Host "  Install location: $InstallDir"
Write-Host ""

# Show missing dependencies warning
if ($MissingDeps.Count -gt 0) {
    Write-Host ""
    Write-Warn "Missing dependencies detected:"
    foreach ($dep in $MissingDeps) {
        Write-Host "    - $dep"
    }
    Write-Host ""
    Write-Host "  Please install the missing dependencies before starting."
    Write-Host "  See: $InstallDir\INSTALL.md"
    Write-Host ""
}

Write-Host "  To start:"
Write-Host "    Double-click 'LM Light' on your Desktop"
Write-Host "    Or run: $InstallDir\start.bat"
Write-Host ""
if (-not $License) {
    Write-Host "  Don't forget to add your license:"
    Write-Host "    Copy license.lic to $InstallDir\bin\"
    Write-Host ""
}
