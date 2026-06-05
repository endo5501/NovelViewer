# Integration tests for scripts/release.ps1 (mirror of release_test.sh).
#
# Each test builds a throwaway git repo with a bare "origin" remote so pushes
# stay local. Validation-failure cases assert the repo is left untouched; the
# happy path asserts the bump, commit, tag, and push all happened.
#
# Run: powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/test/release_test.ps1

$ErrorActionPreference = 'Stop'
$ScriptDir = Split-Path -Parent $PSScriptRoot
$Release = Join-Path $ScriptDir 'release.ps1'

$script:pass = 0
$script:fail = 0
function Check([string]$desc, [bool]$ok) {
  if ($ok) { $script:pass++; Write-Host "ok   - $desc" }
  else { $script:fail++; Write-Host "FAIL - $desc" }
}

function New-TestRepo([string]$dir, [string]$version) {
  git init -q $dir
  git -C $dir config user.email t@t
  git -C $dir config user.name t
  git -C $dir config commit.gpgsign false
  git -C $dir checkout -q -b main 2>$null
  [System.IO.File]::WriteAllText((Join-Path $dir 'pubspec.yaml'), "name: novel_viewer`nversion: $version`n")
  git -C $dir add pubspec.yaml
  git -C $dir commit -q -m init
  git init -q --bare "$dir.remote"
  git -C $dir remote add origin "$dir.remote"
  git -C $dir push -q origin main
}

function Get-PubspecVersion([string]$dir) {
  $line = Get-Content (Join-Path $dir 'pubspec.yaml') | Where-Object { $_ -match '^version:' } | Select-Object -First 1
  return ($line -replace '^version:\s*', '').Trim()
}
function Get-CommitCount([string]$dir) { return [int](git -C $dir rev-list --count HEAD) }
function Test-Tag([string]$dir, [string]$tag) {
  git -C $dir rev-parse -q --verify "refs/tags/$tag" *> $null
  return ($LASTEXITCODE -eq 0)
}

# Invoke release.ps1 in a child process with $repo as the working directory so
# its `exit` does not terminate this test and pubspec.yaml is read from $repo.
function Invoke-Release([string]$repo, [string[]]$arguments) {
  $out = [System.IO.Path]::GetTempFileName()
  $err = [System.IO.Path]::GetTempFileName()
  $argList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $Release) + $arguments
  $p = Start-Process -FilePath 'powershell.exe' -ArgumentList $argList `
    -WorkingDirectory $repo -Wait -PassThru -NoNewWindow `
    -RedirectStandardOutput $out -RedirectStandardError $err
  Remove-Item $out, $err -ErrorAction SilentlyContinue
  return $p.ExitCode
}

$work = Join-Path ([System.IO.Path]::GetTempPath()) ("reltest_" + [System.Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $work | Out-Null
try {
  function Assert-UntouchedFailure([string]$name, [string]$repo, [string]$want, [string[]]$arguments) {
    $before = Get-CommitCount $repo
    $rc = Invoke-Release $repo $arguments
    Check "$name : exits non-zero" ($rc -ne 0)
    Check "$name : pubspec unchanged" ((Get-PubspecVersion $repo) -eq $want)
    Check "$name : no new commit" ((Get-CommitCount $repo) -eq $before)
  }

  $r = Join-Path $work 'fmt'; New-TestRepo $r '1.1.0+3'
  Assert-UntouchedFailure 'invalid format (1.2)' $r '1.1.0+3' @('1.2')
  Assert-UntouchedFailure 'invalid format (v-prefix)' $r '1.1.0+3' @('v1.2.0')
  Assert-UntouchedFailure 'invalid format (suffix)' $r '1.1.0+3' @('1.2.0-beta')
  Assert-UntouchedFailure 'no argument' $r '1.1.0+3' @()

  $r = Join-Path $work 'dirty'; New-TestRepo $r '1.1.0+3'
  (Get-Content (Join-Path $r 'pubspec.yaml')) -replace '^name: .*', 'name: dirtied' |
    Set-Content (Join-Path $r 'pubspec.yaml')
  Assert-UntouchedFailure 'dirty working tree' $r '1.1.0+3' @('1.2.0')

  $r = Join-Path $work 'branch'; New-TestRepo $r '1.1.0+3'; git -C $r checkout -q -b feature
  Assert-UntouchedFailure 'not on main' $r '1.1.0+3' @('1.2.0')

  $r = Join-Path $work 'tagdup'; New-TestRepo $r '1.1.0+3'; git -C $r tag v1.2.0
  Assert-UntouchedFailure 'tag already exists' $r '1.1.0+3' @('1.2.0')

  $r = Join-Path $work 'regress'; New-TestRepo $r '1.2.0+3'
  Assert-UntouchedFailure 'version regression' $r '1.2.0+3' @('1.1.0')
  Assert-UntouchedFailure 'version equal (not greater)' $r '1.2.0+3' @('1.2.0')

  # Happy path
  $r = Join-Path $work 'ok'; New-TestRepo $r '1.1.0+3'
  $rc = Invoke-Release $r @('1.2.0')
  Check 'happy: exits zero' ($rc -eq 0)
  Check 'happy: build number incremented to 1.2.0+4' ((Get-PubspecVersion $r) -eq '1.2.0+4')
  Check 'happy: tag v1.2.0 created' (Test-Tag $r 'v1.2.0')
  Check 'happy: commit message mentions version' ((git -C $r log -1 --pretty=%s) -match '1\.2\.0')
  git -C "$r.remote" rev-parse -q --verify refs/tags/v1.2.0 *> $null
  Check 'happy: tag pushed to origin' ($LASTEXITCODE -eq 0)
  Check 'happy: working tree clean after release' ([string]::IsNullOrEmpty((git -C $r status --porcelain)))
}
finally {
  Remove-Item -Recurse -Force $work -ErrorAction SilentlyContinue
  Get-ChildItem ([System.IO.Path]::GetTempPath()) -Filter 'reltest_*' -ErrorAction SilentlyContinue | Out-Null
}

Write-Host ""
Write-Host "$script:pass passed, $script:fail failed"
if ($script:fail -ne 0) { exit 1 } else { exit 0 }
