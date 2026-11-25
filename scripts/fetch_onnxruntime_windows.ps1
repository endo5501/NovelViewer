# Prepares ONNX Runtime for the Windows piper-plus build from NuGet.
#
# piper-plus's cmake/find_onnxruntime_windows.cmake downloads
# onnxruntime-win-x64-<ver>.zip from GitHub Releases of microsoft/onnxruntime,
# which is no longer reachable. That cmake skips the download when
# build/onnxruntime/onnxruntime.zip already exists and extracts it instead, so
# this script builds that zip from the NuGet package Microsoft.ML.OnnxRuntime
# of the same version, with the same layout:
#
#   onnxruntime-win-x64-<ver>/include/*.h
#   onnxruntime-win-x64-<ver>/lib/onnxruntime.{dll,lib} (+ providers_shared)
#   onnxruntime-win-x64-<ver>/LICENSE, ThirdPartyNotices.txt
#
# For 1.20.0, onnxruntime.dll, onnxruntime.lib and LICENSE in the package are
# byte-identical to those in the GitHub zip.
#
# The version is read from piper-plus's cmake so it follows a submodule bump.
# The package must match the SHA256 registered for that version below; a
# version with no entry fails until its hash is added.
#
# Usage: powershell -NoProfile -ExecutionPolicy Bypass -File scripts\fetch_onnxruntime_windows.ps1
#   -PiperDir, -PackageSource and -HashFile exist for the test
#   (scripts/test/fetch_onnxruntime_windows_test.ps1).

param(
  [string]$PiperDir = (Join-Path (Split-Path -Parent $PSScriptRoot) 'third_party\piper-plus'),
  # URL or local path; {version} is replaced with the ONNX Runtime version.
  [string]$PackageSource = 'https://api.nuget.org/v3-flatcontainer/microsoft.ml.onnxruntime/{version}/microsoft.ml.onnxruntime.{version}.nupkg',
  # JSON object of version -> nupkg SHA256, in place of the table below.
  [string]$HashFile = ''
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

# SHA256 of microsoft.ml.onnxruntime.<version>.nupkg on nuget.org.
$KnownHashes = @{
  '1.20.0' = '36dbafacb1bc532e92d02371bd70582a61105872561fc9982314854d1c7ebf72'
}

function Stop-Fetch([string]$message) {
  [Console]::Error.WriteLine("ERROR: $message")
  exit 1
}

$zipPath = Join-Path $PiperDir 'build\onnxruntime\onnxruntime.zip'
if (Test-Path -LiteralPath $zipPath) {
  Write-Host "ONNX Runtime zip already present: $zipPath"
  exit 0
}

$cmakeFile = Join-Path $PiperDir 'cmake\find_onnxruntime_windows.cmake'
if (!(Test-Path -LiteralPath $cmakeFile)) { Stop-Fetch "not found: $cmakeFile" }
$match = [regex]::Match([System.IO.File]::ReadAllText($cmakeFile), 'set\(\s*ONNXRUNTIME_VERSION\s+"([^"]+)"\s*\)')
if (!$match.Success) { Stop-Fetch "no ONNXRUNTIME_VERSION in $cmakeFile" }
$version = $match.Groups[1].Value

$hashes = @{}
if ($HashFile) {
  $json = [System.IO.File]::ReadAllText($HashFile) | ConvertFrom-Json
  foreach ($p in $json.PSObject.Properties) { $hashes[$p.Name] = [string]$p.Value }
} else {
  $hashes = $KnownHashes
}
if (!$hashes.ContainsKey($version)) {
  Stop-Fetch ("no SHA256 registered for ONNX Runtime $version. Add the hash of " +
    "microsoft.ml.onnxruntime.$version.nupkg to `$KnownHashes in scripts\fetch_onnxruntime_windows.ps1")
}
$expected = $hashes[$version].ToLower()

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

# Everything is staged outside the piper-plus tree: the package also carries
# x86 / arm64 onnxruntime.dll, and build_piper_windows.bat picks the DLL with a
# recursive search under piper-plus\build.
$work = Join-Path ([System.IO.Path]::GetTempPath()) ('ort_fetch_' + [System.Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $work | Out-Null
try {
  $nupkg = Join-Path $work 'package.zip'
  $source = $PackageSource.Replace('{version}', $version)
  if ($source -match '^https?://') {
    Write-Host "Downloading ONNX Runtime $version from $source"
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri $source -OutFile $nupkg -UseBasicParsing
  } else {
    if (!(Test-Path -LiteralPath $source)) { Stop-Fetch "package not found: $source" }
    Copy-Item -LiteralPath $source -Destination $nupkg
  }

  $actual = (Get-FileHash -LiteralPath $nupkg -Algorithm SHA256).Hash.ToLower()
  if ($actual -ne $expected) {
    Stop-Fetch "SHA256 mismatch for ONNX Runtime $version package: expected $expected, got $actual"
  }

  $rootName = "onnxruntime-win-x64-$version"
  $stage = Join-Path $work 'stage'
  $root = Join-Path $stage $rootName
  $map = [ordered]@{
    'build/native/include/'    = 'include'
    'runtimes/win-x64/native/' = 'lib'
  }
  $zip = [System.IO.Compression.ZipFile]::OpenRead($nupkg)
  try {
    foreach ($entry in $zip.Entries) {
      $name = $entry.FullName.Replace('\', '/')
      if ($name.EndsWith('/')) { continue }
      $dest = $null
      if ($name -eq 'LICENSE' -or $name -eq 'ThirdPartyNotices.txt') {
        $dest = Join-Path $root $name
      } else {
        foreach ($prefix in $map.Keys) {
          if ($name.StartsWith($prefix)) {
            $rest = $name.Substring($prefix.Length)
            $dest = Join-Path (Join-Path $root $map[$prefix]) $rest.Replace('/', '\')
            break
          }
        }
      }
      if ($null -eq $dest) { continue }
      New-Item -ItemType Directory -Path (Split-Path -Parent $dest) -Force | Out-Null
      [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $dest, $true)
    }
  } finally {
    $zip.Dispose()
  }

  foreach ($required in @('include\onnxruntime_cxx_api.h', 'lib\onnxruntime.lib', 'lib\onnxruntime.dll', 'LICENSE')) {
    if (!(Test-Path -LiteralPath (Join-Path $root $required))) {
      Stop-Fetch "ONNX Runtime $version package has no $required"
    }
  }

  # Zipped by the cmake that will extract it.
  $built = Join-Path $work 'onnxruntime.zip'
  Push-Location $stage
  try {
    & cmake -E tar cf $built --format=zip $rootName
    $tarExit = $LASTEXITCODE
  } finally {
    Pop-Location
  }
  if ($tarExit -ne 0 -or !(Test-Path -LiteralPath $built)) { Stop-Fetch "cmake -E tar failed ($tarExit)" }

  New-Item -ItemType Directory -Path (Split-Path -Parent $zipPath) -Force | Out-Null
  Move-Item -LiteralPath $built -Destination $zipPath
  Write-Host "ONNX Runtime $version zip written: $zipPath"
} finally {
  Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
}
