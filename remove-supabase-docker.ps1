<#
PowerShell helper to remove the supabase-docker helper folder from the
working copy and stage the removal for commit. Run this from the repo root.

This script does NOT push or commit for you.
#>

param(
    [switch]$Confirm = $true
)

$path = Join-Path $PSScriptRoot 'supabase-docker'
if (-Not (Test-Path $path)) {
    Write-Host "Directory not found: $path" -ForegroundColor Yellow
    exit 0
}

if ($Confirm) {
    $ans = Read-Host "Remove directory '$path' and stage deletion in git? (y/N)"
    if ($ans -ne 'y') {
        Write-Host "Aborted by user." -ForegroundColor Yellow
        exit 0
    }
}

Write-Host "Removing directory: $path" -ForegroundColor Cyan
# remove from git tracking and working tree
try {
    & git rm -r --ignore-unmatch --quiet "supabase-docker"
} catch {
    Write-Host "git rm failed or supabase-docker not tracked" -ForegroundColor Yellow
}

# Fallback: forcibly remove the dir if it still exists
try {
    Remove-Item -Recurse -Force -ErrorAction Stop $path
    Write-Host "Directory deleted from working tree." -ForegroundColor Green
} catch {
    Write-Host "Failed to remove directory: $_" -ForegroundColor Red
}

Write-Host "Remember to commit the removal: git commit -m 'chore: remove supabase-docker helper'" -ForegroundColor Cyan
