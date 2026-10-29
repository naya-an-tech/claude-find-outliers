# claude-find-outliers - Windows installer (PowerShell 5.1+ / 7+)
#
# Installs for the current user, without the plugin:
#   - skill: ~/.claude/skills/find-outliers/SKILL.md  -> /find-outliers in Claude Code
#   - MCP:   apify (https://mcp.apify.com), notion (https://mcp.notion.com/mcp), user scope
#
# Usage:
#   irm https://raw.githubusercontent.com/naya-an-tech/claude-find-outliers/main/install.ps1 | iex
#   & ([scriptblock]::Create((irm https://raw.githubusercontent.com/naya-an-tech/claude-find-outliers/main/install.ps1))) -NoNotion
#
# ASCII-only on purpose: PowerShell 5.1 reads BOM-less files with the ANSI code page.

param([switch]$NoNotion)

$RepoRaw  = 'https://raw.githubusercontent.com/naya-an-tech/claude-find-outliers/main'
$SkillRel = 'plugins/viral-outliers/skills/find-outliers/SKILL.md'
$SkillDir = Join-Path $HOME '.claude\skills\find-outliers'

function Ok($m)   { Write-Host "  [OK] $m" -ForegroundColor Green }
function Warn($m) { Write-Host "  [!] $m" -ForegroundColor Yellow }
function Fail($m) { Write-Host "  [X] $m" -ForegroundColor Red }

$localBin = Join-Path $HOME '.local\bin'
if ((Test-Path $localBin) -and (($env:Path -split ';') -notcontains $localBin)) { $env:Path = "$localBin;$env:Path" }
if (-not (Get-Command claude -ErrorAction SilentlyContinue)) {
    Fail "Claude Code CLI (claude) not found -> irm https://claude.ai/install.ps1 | iex"
    return
}

Write-Host "claude-find-outliers installer"

# 1) Skill: use the local copy when run from a clone, otherwise download.
New-Item -ItemType Directory -Force $SkillDir | Out-Null
$target = Join-Path $SkillDir 'SKILL.md'
$localSkill = $null
if ($PSScriptRoot) { $localSkill = Join-Path $PSScriptRoot $SkillRel }
try {
    if ($localSkill -and (Test-Path $localSkill)) {
        Copy-Item $localSkill $target -Force
    } else {
        Invoke-WebRequest -UseBasicParsing "$RepoRaw/$SkillRel" -OutFile $target
    }
    Ok "skill installed: $target"
} catch {
    Fail "skill download failed: $_"
    return
}

# 2) MCP servers: keep an existing server with the same name untouched.
function Add-Mcp($name, $url) {
    claude mcp get $name *> $null
    if ($LASTEXITCODE -eq 0) { Warn "MCP '$name' already registered, left as is"; return }
    claude mcp add --scope user --transport http $name $url *> $null
    if ($LASTEXITCODE -eq 0) { Ok "MCP '$name' registered: $url" } else { Fail "MCP '$name' registration failed" }
}
Add-Mcp 'apify' 'https://mcp.apify.com'
if (-not $NoNotion) { Add-Mcp 'notion' 'https://mcp.notion.com/mcp' }

Write-Host ""
Write-Host "Next steps"
Write-Host "  1. Restart Claude Code."
Write-Host "  2. Run /mcp, select apify and notion, and Authenticate in the browser."
Write-Host "  3. /find-outliers <niche>"
