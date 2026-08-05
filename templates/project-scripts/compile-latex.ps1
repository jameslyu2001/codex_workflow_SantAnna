[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Target
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$RepositoryRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$SlidesRoot = Join-Path $RepositoryRoot 'Slides'

if (Test-Path -LiteralPath $Target -PathType Leaf) {
    $TexPath = (Resolve-Path -LiteralPath $Target).Path
} else {
    $Candidate = Join-Path $SlidesRoot $Target
    if ([IO.Path]::GetExtension($Candidate) -ne '.tex') { $Candidate += '.tex' }
    if (Test-Path -LiteralPath $Candidate -PathType Leaf) {
        $TexPath = (Resolve-Path -LiteralPath $Candidate).Path
    } else {
        $Matches = @(Get-ChildItem -LiteralPath $SlidesRoot -File -Filter "$Target*.tex")
        if ($Matches.Count -ne 1) { throw "Expected one TeX target for '$Target'; found $($Matches.Count)." }
        $TexPath = $Matches[0].FullName
    }
}

if ([IO.Path]::GetExtension($TexPath) -ne '.tex') { throw "Target must be a .tex file: $TexPath" }
if (-not (Get-Command xelatex -ErrorAction SilentlyContinue)) { throw 'Required tool is missing: xelatex' }

$OldTexInputs = $env:TEXINPUTS
$OldBibInputs = $env:BIBINPUTS
$Separator = [IO.Path]::PathSeparator
$env:TEXINPUTS = (Join-Path $RepositoryRoot 'Preambles') + $Separator + $OldTexInputs
$env:BIBINPUTS = $RepositoryRoot + $Separator + $OldBibInputs
$BaseName = [IO.Path]::GetFileNameWithoutExtension($TexPath)
$WorkingDirectory = Split-Path -Parent $TexPath

function Invoke-Checked {
    param([Parameter(Mandatory)][string]$Command, [Parameter(Mandatory)][string[]]$Arguments)
    & $Command @Arguments
    if ($LASTEXITCODE -ne 0) { throw "$Command failed with exit code $LASTEXITCODE." }
}

try {
    Push-Location $WorkingDirectory
    Invoke-Checked -Command 'xelatex' -Arguments @('-interaction=nonstopmode', '-halt-on-error', "$BaseName.tex")
    $AuxPath = Join-Path $WorkingDirectory "$BaseName.aux"
    if ((Test-Path -LiteralPath $AuxPath) -and (Select-String -LiteralPath $AuxPath -Pattern '\\bibdata' -Quiet)) {
        if (-not (Get-Command bibtex -ErrorAction SilentlyContinue)) { throw 'The document uses a bibliography, but bibtex is missing.' }
        Invoke-Checked -Command 'bibtex' -Arguments @($BaseName)
    }
    Invoke-Checked -Command 'xelatex' -Arguments @('-interaction=nonstopmode', '-halt-on-error', "$BaseName.tex")
    Invoke-Checked -Command 'xelatex' -Arguments @('-interaction=nonstopmode', '-halt-on-error', "$BaseName.tex")
} finally {
    Pop-Location
    $env:TEXINPUTS = $OldTexInputs
    $env:BIBINPUTS = $OldBibInputs
}

$PdfPath = [IO.Path]::ChangeExtension($TexPath, '.pdf')
if (-not (Test-Path -LiteralPath $PdfPath -PathType Leaf)) { throw "Compilation finished without producing $PdfPath" }
$LogPath = [IO.Path]::ChangeExtension($TexPath, '.log')
if (Test-Path -LiteralPath $LogPath -PathType Leaf) {
    $Unresolved = @(Select-String -LiteralPath $LogPath -Pattern @(
        'LaTeX Warning:.*undefined',
        'There were undefined references',
        'Package .* Warning: Citation .* undefined'
    ))
    if ($Unresolved.Count -gt 0) {
        throw "Compilation produced unresolved references or citations. Inspect: $LogPath"
    }
    $Overfull = @(Select-String -LiteralPath $LogPath -Pattern 'Overfull \\[hv]box')
    if ($Overfull.Count -gt 0) {
        Write-Warning "Compilation produced $($Overfull.Count) overfull box warning(s). Inspect: $LogPath"
    }
}
Write-Host "Compiled: $PdfPath"
