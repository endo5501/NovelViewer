# Verifies scripts/build_app.bat hands the build the commit it was made from
# (mirror of build_app_test.sh).
#
# Runs the real script with stub `fvm` and `git` batch files first on PATH, so
# no Flutter build happens. The fvm stub records the command line it was given.
#
# Run: powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/test/build_app_test.ps1

$ErrorActionPreference = 'Stop'
$ScriptDir = Split-Path -Parent $PSScriptRoot
$BuildApp = Join-Path $ScriptDir 'build_app.bat'

$script:pass = 0
$script:fail = 0
function Check([string]$desc, [bool]$ok) {
  if ($ok) { $script:pass++; Write-Host "ok   - $desc" }
  else { $script:fail++; Write-Host "FAIL - $desc" }
}

$work = Join-Path ([System.IO.Path]::GetTempPath()) ("buildapptest_" + [System.Guid]::NewGuid().ToString('N'))
$bin = Join-Path $work 'bin'
New-Item -ItemType Directory -Path $bin | Out-Null
$argsFile = Join-Path $work 'args'
$errFile = Join-Path $work 'err'

# %* rather than a for loop over the arguments: cmd splits a for list on `=`,
# which would break --dart-define=BUILD_COMMIT=... into pieces.
[System.IO.File]::WriteAllText((Join-Path $bin 'fvm.bat'), "@echo off`r`necho %*> `"%FVM_ARGS%`"`r`n")

# Runs build_app.bat with a git stub whose body is $gitBody, and returns the
# exit code.
function Invoke-BuildApp([string]$gitBody, [string[]]$arguments) {
  [System.IO.File]::WriteAllText((Join-Path $bin 'git.bat'), "@echo off`r`n$gitBody`r`n")
  Remove-Item $argsFile, $errFile -ErrorAction SilentlyContinue
  $savedPath = $env:PATH
  $env:PATH = "$bin;$savedPath"
  $env:FVM_ARGS = $argsFile
  try {
    $cmdLine = '/c ""' + $BuildApp + '" ' + ($arguments -join ' ') + '"'
    $out = [System.IO.Path]::GetTempFileName()
    $p = Start-Process -FilePath 'cmd.exe' -ArgumentList $cmdLine `
      -Wait -PassThru -NoNewWindow `
      -RedirectStandardOutput $out -RedirectStandardError $errFile
    Remove-Item $out -ErrorAction SilentlyContinue
    return $p.ExitCode
  } finally {
    $env:PATH = $savedPath
    Remove-Item Env:FVM_ARGS -ErrorAction SilentlyContinue
  }
}

function Get-Recorded {
  if (Test-Path $argsFile) { return (Get-Content $argsFile -Raw) }
  return $null
}

try {
  # --- a commit is passed to the build ---------------------------------------
  $code = Invoke-BuildApp 'echo a1b2c3d' @('windows', '--release')
  $recorded = Get-Recorded
  Check 'builds when git names the commit' ($code -eq 0)
  Check 'runs flutter build for the named platform' ($recorded -match '^flutter build windows\b')
  Check 'forwards the remaining flutter arguments' ($recorded -match '(^|\s)--release(\s|$)')
  Check 'passes the commit as BUILD_COMMIT' ($recorded -match '--dart-define=BUILD_COMMIT=a1b2c3d(\s|$)')

  # --- no commit to name -----------------------------------------------------
  $code = Invoke-BuildApp 'exit /b 128' @('windows')
  $recorded = Get-Recorded
  Check 'still builds when git cannot name a commit' (($code -eq 0) -and ($null -ne $recorded))
  Check 'passes no identifier it does not have' (-not ($recorded -match 'BUILD_COMMIT'))
  $err = if (Test-Path $errFile) { Get-Content $errFile -Raw } else { '' }
  Check 'warns that the build will report no commit' ($err -match '(?i)commit unknown')

  # --- the exit code of the build is the exit code of the script -------------
  [System.IO.File]::WriteAllText((Join-Path $bin 'fvm.bat'), "@echo off`r`nexit /b 3`r`n")
  $code = Invoke-BuildApp 'echo a1b2c3d' @('windows')
  Check 'fails when the build fails' ($code -ne 0)
  [System.IO.File]::WriteAllText((Join-Path $bin 'fvm.bat'), "@echo off`r`necho %*> `"%FVM_ARGS%`"`r`n")

  # --- usage -----------------------------------------------------------------
  $code = Invoke-BuildApp 'echo a1b2c3d' @()
  Check 'refuses to run without a platform' (($code -ne 0) -and ($null -eq (Get-Recorded)))
} finally {
  Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ""
Write-Host "$($script:pass) passed, $($script:fail) failed"
if ($script:fail -gt 0) { exit 1 }
