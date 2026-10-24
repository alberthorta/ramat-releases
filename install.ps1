# Installs or updates the Ramat agent on Windows from the latest release. Experimental: see
# the README.
#
#   irm https://raw.githubusercontent.com/alberthorta/ramat-releases/main/install.ps1 | iex
#
# It reads manifest.json, downloads the file for this machine and checks its SHA-256. All of it
# runs in a script block, so its settings do not stay in the shell that ran it with iex.
& {
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$manifest = 'https://raw.githubusercontent.com/alberthorta/ramat-releases/main/manifest.json'
$arch = switch ($env:PROCESSOR_ARCHITECTURE) {
    'AMD64' { 'amd64' }
    'ARM64' { 'arm64' }
    default { throw "No Ramat build for $env:PROCESSOR_ARCHITECTURE." }
}

$m = Invoke-RestMethod $manifest
$agent = $m.components.agent
$asset = $agent.assets | Where-Object { $_.os -eq 'windows' -and $_.arch -eq $arch } | Select-Object -First 1
if (-not $asset) { throw "No agent build for windows $arch." }

$tmp = Join-Path ([IO.Path]::GetTempPath()) ("ramat-" + [guid]::NewGuid())
New-Item -ItemType Directory $tmp | Out-Null
try {
    Write-Host "Downloading agent $($agent.version) ($arch)..."
    $zip = Join-Path $tmp $asset.name
    Invoke-WebRequest $asset.url -OutFile $zip -UseBasicParsing
    if ((Get-FileHash $zip -Algorithm SHA256).Hash.ToLower() -ne $asset.sha256.ToLower()) {
        throw 'The download does not match the manifest checksum. Nothing was installed.'
    }
    Expand-Archive $zip -DestinationPath $tmp

    # The same folder as Claude Code's own installer, so it is usually in PATH already.
    $bin = Join-Path $env:USERPROFILE '.local\bin'
    New-Item -ItemType Directory -Force $bin | Out-Null
    $exe = Join-Path $bin 'ramat.exe'
    # Through cmd: under Stop, Windows PowerShell 5.1 turns the error text of a missing task
    # (a first install) into an exception.
    cmd /c 'schtasks /End /TN "Ramat agent" >nul 2>&1'
    # A running ramat.exe (a hook) cannot be replaced, only moved away.
    if (Test-Path $exe) {
        Remove-Item "$exe.old" -Force -ErrorAction SilentlyContinue
        Move-Item $exe "$exe.old" -Force
    }
    Copy-Item (Join-Path $tmp 'ramat.exe') $exe
    Unblock-File $exe

    $path = [string][Environment]::GetEnvironmentVariable('Path', 'User')
    if (($path -split ';') -notcontains $bin) {
        [Environment]::SetEnvironmentVariable('Path', ($path.TrimEnd(';') + ';' + $bin).TrimStart(';'), 'User')
        Write-Host "Added $bin to your PATH: Claude Code hooks call 'ramat'. Open a new terminal to use it."
    }
    $env:Path = "$env:Path;$bin"

    & $exe service install
    if ($LASTEXITCODE) { throw 'ramat service install failed.' }
    Write-Host "Installed ramat $($agent.version) in $bin."
} finally {
    Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
}
}
