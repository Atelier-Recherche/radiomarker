#Requires -Version 5.1
<#
.SYNOPSIS
  Release Radiomarker : bump semver dans l’installeur Inno, compile RadiomarkerSetup.exe, commit, tag, push, release GitHub.

.DESCRIPTION
  - Version de référence : #define MyAppVersion "x.y.z" dans installer/RadiomarkerSetup.iss
  - Compile avec ISCC.exe (Inno Setup 6)
  - N’ajoute pas dist/*.exe au dépôt ; l’installeur est joint à la release GitHub via gh
  - Tag Git : v1.2.3 (préfixe v, semver dans le tag après le v)

.PARAMETER BumpKind
  Patch (défaut), Minor ou Major.

.PARAMETER SkipBuild
  Ne pas lancer ISCC (l’exe doit déjà exister dans dist/).

.PARAMETER NoPush
  Commit et tag en local uniquement.

.PARAMETER NoGhRelease
  Ne pas appeler gh release create (même si gh est disponible).

.PARAMETER Remote
  Remote Git (défaut : origin).

.PARAMETER InnoSetupCompiler
  Chemin complet vers ISCC.exe (défaut : détection Program Files x86 / Program Files).

.EXAMPLE
  .\Release.ps1
  .\Release.ps1 -BumpKind Minor
  .\Release.ps1 -NoPush
  .\Release.ps1 -SkipBuild -NoGhRelease
#>
param(
    [ValidateSet('Patch', 'Minor', 'Major')]
    [string] $BumpKind = 'Patch',

    [switch] $SkipBuild,

    [switch] $NoPush,

    [switch] $NoGhRelease,

    [string] $Remote = 'origin',

    [string] $InnoSetupCompiler = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = $PSScriptRoot
$issRel = 'installer\RadiomarkerSetup.iss'
$issPath = Join-Path $repoRoot $issRel
$distDir = Join-Path $repoRoot 'dist'
$setupExe = Join-Path $distDir 'RadiomarkerSetup.exe'
$notesBasename = 'radiomarker-release-notes.md'

Set-Location -LiteralPath $repoRoot

function Test-CommandExists {
    param([Parameter(Mandatory)][string] $Name)
    return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

function Set-Utf8NoBomFile {
    param(
        [Parameter(Mandatory)][string] $Path,
        [Parameter(Mandatory)][string] $Content
    )
    $utf8 = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($Path, $Content, $utf8)
}

function Get-NextSemVer {
    param(
        [Parameter(Mandatory)][string] $Version,
        [Parameter(Mandatory)][ValidateSet('Patch', 'Minor', 'Major')][string] $Kind
    )
    if ($Version -notmatch '^(\d+)\.(\d+)\.(\d+)$') {
        throw "Version non semver à trois segments : $Version"
    }
    $major = [int]$Matches[1]
    $minor = [int]$Matches[2]
    $patch = [int]$Matches[3]
    switch ($Kind) {
        'Major' { return "$($major + 1).0.0" }
        'Minor' { return "$major.$($minor + 1).0" }
        'Patch' { return "$major.$minor.$($patch + 1)" }
    }
}

function Get-IsccPath {
    param([string] $Preferred)
    if ($Preferred -and (Test-Path -LiteralPath $Preferred)) {
        return $Preferred
    }
    $candidates = @(
        "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
        "${env:ProgramFiles}\Inno Setup 6\ISCC.exe"
    )
    foreach ($c in $candidates) {
        if (Test-Path -LiteralPath $c) {
            return $c
        }
    }
    throw "ISCC.exe introuvable. Installe Inno Setup 6 ou passe -InnoSetupCompiler 'C:\...\ISCC.exe'."
}

function Get-IssAppVersion {
    param([Parameter(Mandatory)][string] $IssContent)
    if ($IssContent -notmatch '(?m)^#define MyAppVersion "(\d+\.\d+\.\d+)"\s*$') {
        throw "Impossible de lire #define MyAppVersion ""x.y.z"" dans $issRel."
    }
    return [string]$Matches[1]
}

foreach ($cmd in @('git')) {
    if (-not (Test-CommandExists $cmd)) {
        throw "Commande introuvable dans le PATH : $cmd"
    }
}

if (-not (Test-Path -LiteralPath $issPath)) {
    throw "Fichier absent : $issPath"
}

$dirty = (& git status --porcelain 2>&1 | Out-String).Trim()
if ($dirty) {
    throw "Arbre Git non propre. Committe ou stash avant une release.`n$dirty"
}

$issRaw = Get-Content -LiteralPath $issPath -Raw -Encoding UTF8
$currentVersion = Get-IssAppVersion -IssContent $issRaw
$newVersion = Get-NextSemVer -Version $currentVersion -Kind $BumpKind
$tagName = "v$newVersion"

Write-Host "Radiomarker : $currentVersion → $newVersion ($BumpKind) | tag $tagName" -ForegroundColor Cyan

$escapedCurrent = [regex]::Escape($currentVersion)
$updatedIss = [regex]::Replace(
    $issRaw,
    '(?m)^(#define MyAppVersion ")' + $escapedCurrent + '(")\s*$',
    '${1}' + $newVersion + '$2',
    1
)
if ($updatedIss -eq $issRaw) {
    throw "Impossible de mettre à jour MyAppVersion dans $issRel."
}
Set-Utf8NoBomFile -Path $issPath -Content $updatedIss

if (-not $SkipBuild) {
    $iscc = Get-IsccPath -Preferred $InnoSetupCompiler
    Write-Host "Compilation installeur : $iscc" -ForegroundColor Cyan
    & $iscc $issPath
    if ($LASTEXITCODE -ne 0) { throw "Compilation Inno Setup a échoué (code $LASTEXITCODE)." }
}
else {
    Write-Host "Build ignoré (-SkipBuild)." -ForegroundColor Yellow
}

if (-not (Test-Path -LiteralPath $setupExe)) {
    throw "Installeur absent : $setupExe — lance sans -SkipBuild ou compile manuellement."
}

$notesPath = Join-Path $repoRoot $notesBasename
$lastTag = $null
$describeResult = & git describe --tags --abbrev=0 --match 'v[0-9]*.[0-9]*.[0-9]*' 2>&1
if ($LASTEXITCODE -eq 0) {
    $lastTag = ($describeResult | Out-String).Trim()
}
$logLines = if ($lastTag) {
    & git log "$lastTag..HEAD" --oneline 2>&1
}
else {
    & git log --oneline -n 30 2>&1
}
if ($LASTEXITCODE -ne 0) { throw "git log a échoué (code $LASTEXITCODE)." }

$notesBody = @"
# Radiomarker $newVersion

## Changements

$($logLines | Out-String)

## Fichier

- ``RadiomarkerSetup.exe`` (installeur Windows)

"@
Set-Utf8NoBomFile -Path $notesPath -Content ($notesBody.TrimEnd() + "`n")

& git rev-parse --verify --quiet "refs/tags/$tagName" 2>$null | Out-Null
if ($LASTEXITCODE -eq 0) {
    throw "Le tag Git '$tagName' existe déjà."
}

$pathsToAdd = @(
    $issRel,
    $notesBasename
)
& git add -- $pathsToAdd
if ($LASTEXITCODE -ne 0) { throw "git add a échoué (code $LASTEXITCODE)." }

$commitMsg = @"
release: Radiomarker $newVersion

Bump MyAppVersion, notes de release, installeur compile localement (non versionne).
"@

& git commit -m $commitMsg
if ($LASTEXITCODE -ne 0) { throw "git commit a échoué (code $LASTEXITCODE)." }

& git tag -a $tagName -m "Radiomarker $newVersion"
if ($LASTEXITCODE -ne 0) { throw "git tag a échoué (code $LASTEXITCODE)." }

if ($NoPush) {
    Write-Host "OK — Release $newVersion préparée en local (-NoPush)." -ForegroundColor Green
    Write-Host "  git push $Remote HEAD" -ForegroundColor Gray
    Write-Host "  git push $Remote refs/tags/$tagName" -ForegroundColor Gray
    if (-not $NoGhRelease -and (Test-CommandExists 'gh')) {
        Write-Host "Puis : gh release create $tagName --title `"Radiomarker $newVersion`" --notes-file $notesBasename `"dist/RadiomarkerSetup.exe`"" -ForegroundColor Gray
    }
    exit 0
}

& git push $Remote HEAD
if ($LASTEXITCODE -ne 0) { throw "git push a échoué (code $LASTEXITCODE)." }

& git push $Remote "refs/tags/$tagName"
if ($LASTEXITCODE -ne 0) { throw "git push du tag a échoué (code $LASTEXITCODE)." }

Write-Host "Branche et tag poussés sur $Remote." -ForegroundColor Green

if ($NoGhRelease) {
    Write-Host "GitHub release non créée (-NoGhRelease)." -ForegroundColor Yellow
    exit 0
}

if (-not (Test-CommandExists 'gh')) {
    Write-Host "gh CLI absent — crée la release à la main et attache dist\RadiomarkerSetup.exe" -ForegroundColor Yellow
    exit 0
}

Write-Host "Création release GitHub $tagName..." -ForegroundColor Cyan
& gh release create $tagName --title "Radiomarker $newVersion" --notes-file $notesPath -- $setupExe
if ($LASTEXITCODE -ne 0) {
    throw "gh release create a échoué (code $LASTEXITCODE). Vérifie gh auth login."
}

Write-Host "Release GitHub $tagName publiée avec l’installeur." -ForegroundColor Green
