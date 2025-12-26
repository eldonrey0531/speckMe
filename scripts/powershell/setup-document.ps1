#requires -Version 7.0

<#
.SYNOPSIS
    Setup script for /speckit.document intake generator
.DESCRIPTION
    Prepares context for the document intake command
.PARAMETER Json
    Output in JSON format
#>

param(
    [switch]$Json
)

$ErrorActionPreference = "Stop"

# Get script directory
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Source common functions if available
$CommonPath = Join-Path $ScriptDir 'common.ps1'
if (Test-Path $CommonPath) {
    . $CommonPath
}

# Determine repo root
try {
    $RepoRoot = (git rev-parse --show-toplevel 2>$null)
    $CurrentBranch = (git rev-parse --abbrev-ref HEAD 2>$null)
    $HasGit = $true
} catch {
    $RepoRoot = Get-Location
    $CurrentBranch = "main"
    $HasGit = $false
}

# Check for existing constitution
$ConstitutionFile = Join-Path $RepoRoot '.specify/memory/constitution.md'
$HasConstitution = Test-Path $ConstitutionFile

# Determine next feature ID
$SpecsDir = Join-Path $RepoRoot 'specs'
$NextId = "001"
$ExistingFeatures = @()

if (Test-Path $SpecsDir) {
    $FeatureDirs = Get-ChildItem -Path $SpecsDir -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match '^\d{3}-' } |
        Sort-Object Name -Descending
    
    if ($FeatureDirs.Count -gt 0) {
        $Highest = [int]($FeatureDirs[0].Name.Substring(0, 3))
        $NextId = "{0:D3}" -f ($Highest + 1)
        $ExistingFeatures = $FeatureDirs | ForEach-Object { $_.Name }
    }
}

# Intake directory
$IntakeBase = Join-Path $RepoRoot '.specify/intake'
if (-not (Test-Path $IntakeBase)) {
    New-Item -ItemType Directory -Path $IntakeBase -Force | Out-Null
}

# Timestamp
$Timestamp = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')

# Build output
$context = [ordered]@{
    repo_root = $RepoRoot
    intake_base = $IntakeBase
    suggested_feature_id = $NextId
    has_git = $HasGit
    current_branch = $CurrentBranch
    has_constitution = $HasConstitution
    constitution_path = $ConstitutionFile
    specs_dir = $SpecsDir
    existing_features = $ExistingFeatures
    timestamp = $Timestamp
}

if ($Json) {
    $context | ConvertTo-Json -Depth 10
} else {
    Write-Host "REPO_ROOT: $RepoRoot"
    Write-Host "INTAKE_BASE: $IntakeBase"
    Write-Host "SUGGESTED_FEATURE_ID: $NextId"
    Write-Host "HAS_GIT: $HasGit"
    Write-Host "HAS_CONSTITUTION: $HasConstitution"
}

# Status to stderr
Write-Host ""
Write-Host "✓ Intake generator ready" -ForegroundColor Green
Write-Host "  Next feature ID: $NextId" -ForegroundColor Cyan
$constitutionStatus = if ($HasConstitution) { "exists" } else { "not found" }
Write-Host "  Constitution: $constitutionStatus" -ForegroundColor Cyan
Write-Host ""
