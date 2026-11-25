# Verifies scripts/fetch_onnxruntime_windows.ps1 lays the NuGet ONNX Runtime
# package out as the onnxruntime.zip piper-plus's CMake would otherwise
# download from GitHub Releases, and that build_piper_windows.bat stops when
# that step fails.
#
# Runs against a fake nupkg and a fake piper-plus tree, so nothing is
# downloaded and the real third_party/piper-plus/build is not touched.
#
# Run: powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/test/fetch_onnxruntime_windows_test.ps1

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$ScriptDir = Split-Path -Parent $PSScriptRoot
$Fetch = Join-Path $ScriptDir 'fetch_onnxruntime_windows.ps1'
$BuildPiper = Join-Path $ScriptDir 'build_piper_windows.bat'

$script:pass = 0
$script:fail = 0
function Check([string]$desc, [bool]$ok) {
  if ($ok) { $script:pass++; Write-Host "ok   - $desc" }
  else { $script:fail++; Write-Host "FAIL - $desc" }
}

$work = Join-Path ([System.IO.Path]::GetTempPath()) ("fetchorttest_" + [System.Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $work | Out-Null

# A nupkg with the Microsoft.ML.OnnxRuntime layout. Each DLL's content names
# its architecture so the test can tell which one landed.
function New-FakeNupkg([string]$path) {
  $entries = [ordered]@{
    'Microsoft.ML.OnnxRuntime.nuspec'                  = '<package/>'
    'LICENSE'                                          = 'fake ORT license'
    'ThirdPartyNotices.txt'                            = 'fake notices'
    'build/native/include/onnxruntime_cxx_api.h'       = '// cxx api'
    'build/native/include/onnxruntime_c_api.h'         = '// c api'
    'runtimes/win-x64/native/onnxruntime.dll'          = 'dll win-x64'
    'runtimes/win-x64/native/onnxruntime.lib'          = 'lib win-x64'
    'runtimes/win-x64/native/onnxruntime_providers_shared.dll' = 'providers win-x64'
    'runtimes/win-x86/native/onnxruntime.dll'          = 'dll win-x86'
    'runtimes/win-x86/native/onnxruntime.lib'          = 'lib win-x86'
    'runtimes/win-arm64/native/onnxruntime.dll'        = 'dll win-arm64'
    'runtimes/linux-x64/native/libonnxruntime.so'      = 'so linux-x64'
  }
  $zip = [System.IO.Compression.ZipFile]::Open($path, 'Create')
  try {
    foreach ($name in $entries.Keys) {
      $w = New-Object System.IO.StreamWriter($zip.CreateEntry($name).Open())
      try { $w.Write($entries[$name]) } finally { $w.Dispose() }
    }
  } finally { $zip.Dispose() }
}

# A piper-plus tree holding only the cmake file the version is read from.
function New-FakePiper([string]$dir, [string]$versionLine) {
  $cmakeDir = Join-Path $dir 'cmake'
  New-Item -ItemType Directory -Path $cmakeDir -Force | Out-Null
  $body = "if(WIN32)`n  $versionLine`n  set(ONNX_ARCH `"x64`")`nendif()`n"
  [System.IO.File]::WriteAllText((Join-Path $cmakeDir 'find_onnxruntime_windows.cmake'), $body)
}

function New-HashFile([string]$path, [hashtable]$table) {
  [System.IO.File]::WriteAllText($path, ($table | ConvertTo-Json))
}

# Runs the fetch script and returns its exit code. Output goes to files so a
# failing run's stderr does not stop this script.
function Invoke-Fetch([string]$piperDir, [string]$source, [string]$hashFile) {
  $argList = '-NoProfile -ExecutionPolicy Bypass -File "' + $Fetch + '"' +
    ' -PiperDir "' + $piperDir + '"' +
    ' -PackageSource "' + $source + '"' +
    ' -HashFile "' + $hashFile + '"'
  $out = Join-Path $work 'fetch.out'
  $err = Join-Path $work 'fetch.err'
  $p = Start-Process -FilePath 'powershell.exe' -ArgumentList $argList `
    -Wait -PassThru -NoNewWindow `
    -RedirectStandardOutput $out -RedirectStandardError $err
  return $p.ExitCode
}

# Reads the produced onnxruntime.zip into a name -> content map.
function Read-Zip([string]$path) {
  $map = @{}
  $zip = [System.IO.Compression.ZipFile]::OpenRead($path)
  try {
    foreach ($e in $zip.Entries) {
      if ($e.FullName.EndsWith('/')) { continue }
      $r = New-Object System.IO.StreamReader($e.Open())
      try { $map[$e.FullName.Replace('\', '/')] = $r.ReadToEnd() } finally { $r.Dispose() }
    }
  } finally { $zip.Dispose() }
  return $map
}

function Get-Sha256([string]$path) {
  return (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLower()
}

try {
  $nupkg = Join-Path $work 'fake.nupkg'
  New-FakeNupkg $nupkg
  $hash = Get-Sha256 $nupkg

  # --- the package becomes the layout CMake extracts ------------------------
  $piper = Join-Path $work 'piper-a'
  New-FakePiper $piper 'set(ONNXRUNTIME_VERSION "9.8.7")'
  $hashFile = Join-Path $work 'hashes-a.json'
  New-HashFile $hashFile @{ '9.8.7' = $hash }
  $code = Invoke-Fetch $piper $nupkg $hashFile
  $zipPath = Join-Path $piper 'build\onnxruntime\onnxruntime.zip'
  Check 'succeeds with a package whose hash is registered' ($code -eq 0)
  Check 'writes build/onnxruntime/onnxruntime.zip' (Test-Path -LiteralPath $zipPath)
  $entries = if (Test-Path -LiteralPath $zipPath) { Read-Zip $zipPath } else { @{} }
  $root = 'onnxruntime-win-x64-9.8.7'
  Check 'puts the headers under include/' ($entries["$root/include/onnxruntime_cxx_api.h"] -eq '// cxx api')
  Check 'puts the x64 import library under lib/' ($entries["$root/lib/onnxruntime.lib"] -eq 'lib win-x64')
  Check 'puts the x64 DLL under lib/' ($entries["$root/lib/onnxruntime.dll"] -eq 'dll win-x64')
  Check 'keeps the x64 providers DLL beside it' ($entries["$root/lib/onnxruntime_providers_shared.dll"] -eq 'providers win-x64')
  Check 'puts the package LICENSE at the root' ($entries["$root/LICENSE"] -eq 'fake ORT license')
  $other = @($entries.Values | Where-Object { $_ -match 'win-x86|win-arm64|linux' })
  Check 'carries no other architecture into the zip' (($entries.Count -gt 0) -and ($other.Count -eq 0))
  $buildTree = Join-Path $piper 'build'
  $stray = @(Get-ChildItem -LiteralPath $buildTree -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -ne $zipPath })
  Check 'leaves nothing else under the build tree' ((Test-Path -LiteralPath $zipPath) -and ($stray.Count -eq 0))

  # --- the version comes from piper-plus's cmake ----------------------------
  $piper = Join-Path $work 'piper-b'
  New-FakePiper $piper 'set(ONNXRUNTIME_VERSION "1.2.3")'
  $hashFile = Join-Path $work 'hashes-b.json'
  New-HashFile $hashFile @{ '1.2.3' = $hash }
  $code = Invoke-Fetch $piper $nupkg $hashFile
  $zipPath = Join-Path $piper 'build\onnxruntime\onnxruntime.zip'
  $entries = if (Test-Path -LiteralPath $zipPath) { Read-Zip $zipPath } else { @{} }
  Check 'names the directory after the version piper-plus asks for' (
    ($code -eq 0) -and ($entries['onnxruntime-win-x64-1.2.3/lib/onnxruntime.dll'] -eq 'dll win-x64'))

  # --- a package that does not match its hash is refused --------------------
  $piper = Join-Path $work 'piper-c'
  New-FakePiper $piper 'set(ONNXRUNTIME_VERSION "9.8.7")'
  $hashFile = Join-Path $work 'hashes-c.json'
  New-HashFile $hashFile @{ '9.8.7' = ('0' * 64) }
  $code = Invoke-Fetch $piper $nupkg $hashFile
  Check 'fails when the package hash does not match' ($code -ne 0)
  Check 'writes no zip when the hash does not match' (-not (Test-Path -LiteralPath (Join-Path $piper 'build\onnxruntime\onnxruntime.zip')))

  # --- a version with no registered hash is refused -------------------------
  $piper = Join-Path $work 'piper-d'
  New-FakePiper $piper 'set(ONNXRUNTIME_VERSION "4.5.6")'
  $hashFile = Join-Path $work 'hashes-d.json'
  New-HashFile $hashFile @{ '9.8.7' = $hash }
  $code = Invoke-Fetch $piper $nupkg $hashFile
  $err = [string](Get-Content (Join-Path $work 'fetch.err') -Raw -ErrorAction SilentlyContinue)
  Check 'fails for a version with no registered hash' ($code -ne 0)
  Check 'names the version that needs a hash' ($err -match '4\.5\.6')
  Check 'writes no zip for an unregistered version' (-not (Test-Path -LiteralPath (Join-Path $piper 'build\onnxruntime\onnxruntime.zip')))

  # --- a cmake file without a version is refused ----------------------------
  $piper = Join-Path $work 'piper-e'
  New-FakePiper $piper '# no version here'
  $hashFile = Join-Path $work 'hashes-e.json'
  New-HashFile $hashFile @{ '9.8.7' = $hash }
  $code = Invoke-Fetch $piper $nupkg $hashFile
  Check 'fails when piper-plus names no version' ($code -ne 0)
  Check 'writes no zip when piper-plus names no version' (-not (Test-Path -LiteralPath (Join-Path $piper 'build\onnxruntime\onnxruntime.zip')))

  # --- an existing zip is used as is ----------------------------------------
  $piper = Join-Path $work 'piper-f'
  New-FakePiper $piper 'set(ONNXRUNTIME_VERSION "9.8.7")'
  $existing = Join-Path $piper 'build\onnxruntime\onnxruntime.zip'
  New-Item -ItemType Directory -Path (Split-Path -Parent $existing) -Force | Out-Null
  [System.IO.File]::WriteAllText($existing, 'already here')
  $hashFile = Join-Path $work 'hashes-f.json'
  New-HashFile $hashFile @{ '9.8.7' = $hash }
  $code = Invoke-Fetch $piper (Join-Path $work 'missing.nupkg') $hashFile
  Check 'skips fetching when the zip already exists' ($code -eq 0)
  Check 'leaves the existing zip untouched' ([System.IO.File]::ReadAllText($existing) -eq 'already here')

  # --- build_piper_windows.bat stops when the fetch fails -------------------
  # Stubs first on PATH: `powershell` fails as the fetch would, `cmake`
  # records that it ran.
  $bin = Join-Path $work 'bin'
  New-Item -ItemType Directory -Path $bin | Out-Null
  $cmakeLog = Join-Path $work 'cmake.log'
  [System.IO.File]::WriteAllText((Join-Path $bin 'powershell.bat'), "@echo off`r`nexit /b 1`r`n")
  [System.IO.File]::WriteAllText((Join-Path $bin 'cmake.bat'), "@echo off`r`necho %*>> `"$cmakeLog`"`r`n")
  $savedPath = $env:PATH
  $env:PATH = "$bin;$savedPath"
  try {
    $p = Start-Process -FilePath 'cmd.exe' -ArgumentList ('/c ""' + $BuildPiper + '""') `
      -Wait -PassThru -NoNewWindow `
      -RedirectStandardOutput (Join-Path $work 'bat.out') -RedirectStandardError (Join-Path $work 'bat.err')
    $batCode = $p.ExitCode
  } finally {
    $env:PATH = $savedPath
  }
  Check 'build_piper_windows.bat fails when the fetch fails' ($batCode -ne 0)
  Check 'build_piper_windows.bat runs no cmake after a failed fetch' (-not (Test-Path -LiteralPath $cmakeLog))
} finally {
  Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ""
Write-Host "$($script:pass) passed, $($script:fail) failed"
if ($script:fail -gt 0) { exit 1 }
