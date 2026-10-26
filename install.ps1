# Installs or updates Ramat on Windows from the latest release. Experimental: see the README.
#
#   irm https://raw.githubusercontent.com/alberthorta/ramat-releases/main/install.ps1 | iex
#   iex "& { $(irm https://raw.githubusercontent.com/alberthorta/ramat-releases/main/install.ps1) } viewer"
#
# The first line installs the agent, the second the viewer. It reads manifest.json, downloads
# the file for this machine and checks its SHA-256. All of it runs in a script block, so its
# settings do not stay in the shell that ran it with iex.
& {
param([ValidateSet('agent', 'viewer')][string]$What = 'agent')
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
$component = $m.components.$What
$asset = $component.assets | Where-Object { $_.os -eq 'windows' -and $_.arch -eq $arch } | Select-Object -First 1
if (-not $asset) { throw "No $What build for windows $arch." }

$tmp = Join-Path ([IO.Path]::GetTempPath()) ("ramat-" + [guid]::NewGuid())
New-Item -ItemType Directory $tmp | Out-Null
try {
    Write-Host "Downloading $What $($component.version) ($arch)..."
    $zip = Join-Path $tmp $asset.name
    Invoke-WebRequest $asset.url -OutFile $zip -UseBasicParsing
    if ((Get-FileHash $zip -Algorithm SHA256).Hash.ToLower() -ne $asset.sha256.ToLower()) {
        throw 'The download does not match the manifest checksum. Nothing was installed.'
    }
    Expand-Archive $zip -DestinationPath $tmp

    if ($What -eq 'viewer') {
        # A folder of this user, like other per-user apps: the viewer updates itself there
        # without asking for an administrator.
        $dir = Join-Path $env:LOCALAPPDATA 'Programs\Ramat'
        New-Item -ItemType Directory -Force $dir | Out-Null
        $exe = Join-Path $dir 'Ramat.exe'
        # A running viewer cannot be replaced, only moved away; it keeps working until it quits.
        if (Test-Path $exe) {
            Remove-Item "$exe.old" -Force -ErrorAction SilentlyContinue
            Move-Item $exe "$exe.old" -Force
        }
        Copy-Item (Join-Path $tmp 'Ramat.exe') $exe
        Unblock-File $exe
        $menu = Join-Path ([Environment]::GetFolderPath('Programs')) 'Ramat.lnk'
        $link = (New-Object -ComObject WScript.Shell).CreateShortcut($menu)
        $link.TargetPath = $exe
        $link.WorkingDirectory = $dir
        $link.Description = 'Every Claude Code session, on every farm, live in one place.'
        $link.Save()
        Write-Host "Installed the Ramat viewer $($component.version) in $dir, with a Start menu entry."
        if (-not $env:RAMAT_NO_START) { Start-Process $exe }
        return
    }

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
    Write-Host "Installed ramat $($component.version) in $bin."
} finally {
    Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
}
} @args
