[CmdletBinding()]
param([string]$Lecture)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$RepositoryRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$QuartoRoot = Join-Path $RepositoryRoot 'Quarto'
$DocsRoot = Join-Path $RepositoryRoot 'docs'
$SlidesDestination = Join-Path $DocsRoot 'slides'

if (-not (Get-Command quarto -ErrorAction SilentlyContinue)) { throw 'Required tool is missing: quarto' }
if (-not (Test-Path -LiteralPath $QuartoRoot -PathType Container)) { throw "Missing Quarto directory: $QuartoRoot" }
New-Item -ItemType Directory -Path $SlidesDestination -Force | Out-Null

if ($Lecture) {
    $Candidates = @(Get-ChildItem -LiteralPath $QuartoRoot -File -Filter "$Lecture*.qmd" | Where-Object Name -NotMatch '_backup')
    if ($Candidates.Count -ne 1) { throw "Expected one QMD target for '$Lecture'; found $($Candidates.Count)." }
} else {
    $Candidates = @(Get-ChildItem -LiteralPath $QuartoRoot -File -Filter '*.qmd' | Where-Object Name -NotMatch '_backup')
}

foreach ($Qmd in $Candidates) {
    & quarto render $Qmd.FullName
    if ($LASTEXITCODE -ne 0) { throw "Quarto render failed: $($Qmd.FullName)" }
}

foreach ($Html in Get-ChildItem -LiteralPath $QuartoRoot -File -Filter '*.html') {
    Copy-Item -LiteralPath $Html.FullName -Destination (Join-Path $SlidesDestination $Html.Name) -Force
    $AssetSource = Join-Path $QuartoRoot ($Html.BaseName + '_files')
    if (Test-Path -LiteralPath $AssetSource -PathType Container) {
        Copy-Item -LiteralPath $AssetSource -Destination $SlidesDestination -Recurse -Force
    }
}

$SlidesRoot = Join-Path $RepositoryRoot 'Slides'
if (Test-Path -LiteralPath $SlidesRoot -PathType Container) {
    Get-ChildItem -LiteralPath $SlidesRoot -File -Filter '*.pdf' | ForEach-Object {
        Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $SlidesDestination $_.Name) -Force
    }
}

$CodeDestination = Join-Path $DocsRoot 'files\code'
New-Item -ItemType Directory -Path $CodeDestination -Force | Out-Null
$RRoot = Join-Path $RepositoryRoot 'scripts\R'
if (Test-Path -LiteralPath $RRoot -PathType Container) {
    Get-ChildItem -LiteralPath $RRoot -File -Filter '*.R' | ForEach-Object {
        Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $CodeDestination $_.Name) -Force
    }
}

$FiguresRoot = Join-Path $RepositoryRoot 'Figures'
if (Test-Path -LiteralPath $FiguresRoot -PathType Container) {
    Copy-Item -LiteralPath $FiguresRoot -Destination $DocsRoot -Recurse -Force
}

Write-Host "Rendered and synchronized outputs under: $DocsRoot"
