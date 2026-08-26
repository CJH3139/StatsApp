<#
    Packages src/apstats.lua into StatsApp.tns using Luna.

    Luna is the open-source .tns packager: https://github.com/ndless-nspire/Luna
    Put luna.exe on your PATH or drop it in tools/ next to this script.

    If you don't have Luna, see README.md -- the TI-Nspire Student Software
    and TI-Planet's Project Builder both work without any command line.
#>

$ErrorActionPreference = 'Stop'

$root   = Split-Path -Parent $MyInvocation.MyCommand.Path
$source = Join-Path $root 'src\apstats.lua'
$output = Join-Path $root 'StatsApp.tns'

if (-not (Test-Path $source)) {
    throw "Cannot find $source"
}

# Look for luna on PATH first, then in tools/
$luna = $null
$onPath = Get-Command luna -ErrorAction SilentlyContinue
if ($null -ne $onPath) {
    $luna = $onPath.Source
} else {
    $local = Join-Path $root 'tools\luna.exe'
    if (Test-Path $local) { $luna = $local }
}

if ($null -eq $luna) {
    Write-Host "Luna was not found." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  Download it from https://github.com/ndless-nspire/Luna and either"
    Write-Host "  put luna.exe on your PATH or save it as tools\luna.exe here."
    Write-Host ""
    Write-Host "  No command line? README.md has two point-and-click routes:"
    Write-Host "    - TI-Nspire Student Software: Insert > Script Editor"
    Write-Host "    - TI-Planet Project Builder:  https://tiplanet.org/pb/"
    exit 1
}

Write-Host "luna:   $luna"
Write-Host "source: $source"

& $luna $source $output
if ($LASTEXITCODE -ne 0) {
    throw "luna failed with exit code $LASTEXITCODE"
}

$size = (Get-Item $output).Length
Write-Host ""
Write-Host "Built $output ($size bytes)" -ForegroundColor Green
Write-Host "Connect the handheld and drag it across, or open it in the TI software."
