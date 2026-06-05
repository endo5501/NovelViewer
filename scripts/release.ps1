# Cut a release: bump pubspec.yaml, commit, tag, and push.
#
# Usage: scripts/release.ps1 <X.Y.Z>
#
# Runs every pre-flight check BEFORE touching anything, so a failed check
# leaves the repository exactly as it was. This is the primary guard against
# tagging a release without the matching pubspec.yaml version bump (the CI
# step scripts/verify_release_version.sh is the backstop).
#
# Mirrors scripts/release.sh; keep the two in sync (checks, messages, exit codes).
param([Parameter(Mandatory = $false, Position = 0)][string]$Version)

$ErrorActionPreference = 'Stop'

function Die([string]$msg) { [Console]::Error.WriteLine("error: $msg"); exit 1 }

# --- Parse arguments ----------------------------------------------------------
if ([string]::IsNullOrWhiteSpace($Version)) {
  [Console]::Error.WriteLine('Usage: scripts/release.ps1 <X.Y.Z>')
  exit 1
}

# --- Pre-flight validation (no mutations below this block) --------------------
# 1. Version must be plain SemVer major.minor.patch (no v prefix, no metadata).
if ($Version -notmatch '^[0-9]+\.[0-9]+\.[0-9]+$') {
  Die "version must be in X.Y.Z format (got: '$Version')"
}
$tag = "v$Version"

# 2. Read current version/build from pubspec.yaml.
if (-not (Test-Path 'pubspec.yaml')) { Die 'pubspec.yaml not found (run from the repository root)' }
$versionLine = Get-Content 'pubspec.yaml' | Where-Object { $_ -match '^version:\s*' } | Select-Object -First 1
if (-not $versionLine) { Die "no 'version:' line found in pubspec.yaml" }
$current = ($versionLine -replace '^version:\s*', '').Trim()
$currentName = $current.Split('+')[0]
if ($current -match '\+') { $currentBuild = [int]($current.Split('+')[1]) } else { $currentBuild = 0 }

# 3. Working tree must be clean.
if (git status --porcelain) { Die 'working tree is not clean; commit or stash changes first' }

# 4. Must be on main.
$branch = (git rev-parse --abbrev-ref HEAD).Trim()
if ($branch -ne 'main') { Die "must be on 'main' branch (current: '$branch')" }

# 5. Tag must not already exist locally or on origin.
git rev-parse -q --verify "refs/tags/$tag" *> $null
if ($LASTEXITCODE -eq 0) { Die "tag '$tag' already exists locally" }
git remote get-url origin *> $null
if ($LASTEXITCODE -eq 0) {
  $remoteTag = git ls-remote --tags origin "refs/tags/$tag" 2>$null
  if ($remoteTag) { Die "tag '$tag' already exists on origin" }
}

# 6. New version must be strictly greater than the current one.
function Test-VersionGreater([string]$a, [string]$b) {
  $pa = $a.Split('.'); $pb = $b.Split('.')
  for ($i = 0; $i -lt 3; $i++) {
    $x = [int]$pa[$i]; $y = [int]$pb[$i]
    if ($x -gt $y) { return $true }
    if ($x -lt $y) { return $false }
  }
  return $false   # equal -> not greater
}
if (-not (Test-VersionGreater $Version $currentName)) {
  Die "version $Version is not greater than current $currentName"
}

# --- Apply the release --------------------------------------------------------
$newBuild = $currentBuild + 1
$newFull = "$Version+$newBuild"

# Rewrite only the version line, preserving existing line endings and no BOM.
$path = (Resolve-Path 'pubspec.yaml').Path
$text = [System.IO.File]::ReadAllText($path)
$text = [regex]::Replace($text, '(?m)^version:.*', "version: $newFull")
[System.IO.File]::WriteAllText($path, $text, (New-Object System.Text.UTF8Encoding $false))

Write-Host "Bumping pubspec.yaml: $current -> $newFull"
git add pubspec.yaml
git commit -q -m "chore: bump version to $Version"
if ($LASTEXITCODE -ne 0) { Die 'git commit failed' }
git tag $tag
if ($LASTEXITCODE -ne 0) { Die 'git tag failed' }

Write-Host "Pushing main and $tag to origin..."
git push origin main
if ($LASTEXITCODE -ne 0) { Die 'git push origin main failed' }
git push origin $tag
if ($LASTEXITCODE -ne 0) { Die "git push origin $tag failed" }

Write-Host "Released $tag (pubspec.yaml version $newFull)."
