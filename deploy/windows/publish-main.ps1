param(
    [string]$ProjectRoot = 'C:\project',
    [string]$SourceBranch = 'dev',
    [string]$TargetBranch = 'main',
    [switch]$SkipAnalyze,
    [switch]$SkipOriginPush,
    [switch]$SkipProductionPush
)

$ErrorActionPreference = 'Stop'

Push-Location $ProjectRoot
try {
    $status = git status --porcelain
    if ($status) {
        throw 'Working tree is not clean. Commit or stash your changes first.'
    }

    if (-not $SkipAnalyze) {
        flutter analyze
    }

    $currentBranch = (git branch --show-current).Trim()
    if ($currentBranch -ne $SourceBranch -and $currentBranch -ne $TargetBranch) {
        throw "Current branch is '$currentBranch'. Expected '$SourceBranch' or '$TargetBranch'."
    }

    if ($currentBranch -ne $TargetBranch) {
        git checkout $TargetBranch
    }

    git merge --ff-only $SourceBranch

    if (-not $SkipOriginPush) {
        git push origin $TargetBranch
    }

    if (-not $SkipProductionPush) {
        git push production $TargetBranch
    }
}
finally {
    Pop-Location
}
