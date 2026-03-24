param(
    [string]$ProjectRoot = 'C:\project',
    [string]$SourceBranch = 'dev',
    [string]$TargetBranch = 'main',
    [string]$DeployHost = '82.148.17.131',
    [string]$DeployUser = 'gitdeploy',
    [switch]$SkipAnalyze,
    [switch]$SkipWebBuild,
    [switch]$SkipOriginPush,
    [switch]$SkipProductionPush,
    [switch]$SkipWebDeploy
)

$ErrorActionPreference = 'Stop'
$remote = "$DeployUser@$DeployHost"
$archivePath = Join-Path $ProjectRoot 'deploy\web-build.tgz'
$remoteArchiveDir = '/home/gitdeploy/incoming'

function Assert-LastExitCode {
    param([string]$Step)

    if ($LASTEXITCODE -ne 0) {
        throw "$Step failed with exit code $LASTEXITCODE."
    }
}

Push-Location $ProjectRoot
try {
    $status = git status --porcelain
    if ($status) {
        throw 'Working tree is not clean. Commit or stash your changes first.'
    }

    if (-not $SkipAnalyze) {
        flutter analyze
        Assert-LastExitCode 'flutter analyze'
    }

    $currentBranch = (git branch --show-current).Trim()
    $originalBranch = $currentBranch
    if ($currentBranch -ne $SourceBranch -and $currentBranch -ne $TargetBranch) {
        throw "Current branch is '$currentBranch'. Expected '$SourceBranch' or '$TargetBranch'."
    }

    if ($currentBranch -ne $TargetBranch) {
        git checkout $TargetBranch
        Assert-LastExitCode "git checkout $TargetBranch"
    }

    git merge --ff-only $SourceBranch
    Assert-LastExitCode "git merge --ff-only $SourceBranch"

    if (-not $SkipWebBuild) {
        flutter build web --release --dart-define=API_BASE_URL=/api --no-wasm-dry-run
        Assert-LastExitCode 'flutter build web'
    }

    if (-not $SkipOriginPush) {
        git push origin $TargetBranch
        Assert-LastExitCode "git push origin $TargetBranch"
    }

    if (-not $SkipProductionPush) {
        git push production $TargetBranch
        Assert-LastExitCode "git push production $TargetBranch"
    }

    if (-not $SkipWebDeploy) {
        tar -czf $archivePath -C (Join-Path $ProjectRoot 'build\web') .
        Assert-LastExitCode 'archive web bundle'
        $targetSha = (git rev-parse $TargetBranch).Trim()
        Assert-LastExitCode "git rev-parse $TargetBranch"
        $remoteArchive = "$remoteArchiveDir/web-$targetSha.tgz"

        scp $archivePath "${remote}:$remoteArchive"
        Assert-LastExitCode 'scp web bundle'
        ssh $remote "/opt/indgas-express/bin/deploy-main.sh --web-archive $remoteArchive"
        Assert-LastExitCode 'remote web deploy'
    }
}
finally {
    $activeBranch = (git branch --show-current).Trim()
    if ($originalBranch -and $activeBranch -ne $originalBranch) {
        git checkout $originalBranch | Out-Null
    }
    Pop-Location
}
