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
    $originalBranch = $currentBranch
    if ($currentBranch -ne $SourceBranch -and $currentBranch -ne $TargetBranch) {
        throw "Current branch is '$currentBranch'. Expected '$SourceBranch' or '$TargetBranch'."
    }

    if ($currentBranch -ne $TargetBranch) {
        git checkout $TargetBranch
    }

    git merge --ff-only $SourceBranch

    if (-not $SkipWebBuild) {
        flutter build web --release --dart-define=API_BASE_URL=/api --no-wasm-dry-run
    }

    if (-not $SkipOriginPush) {
        git push origin $TargetBranch
    }

    if (-not $SkipProductionPush) {
        git push production $TargetBranch
    }

    if (-not $SkipWebDeploy) {
        tar -czf $archivePath -C (Join-Path $ProjectRoot 'build\web') .
        $targetSha = (git rev-parse $TargetBranch).Trim()
        $remoteArchive = "$remoteArchiveDir/web-$targetSha.tgz"

        scp $archivePath "${remote}:$remoteArchive"
        ssh $remote "/opt/indgas-express/bin/deploy-main.sh --web-archive $remoteArchive"
    }
}
finally {
    $activeBranch = (git branch --show-current).Trim()
    if ($originalBranch -and $activeBranch -ne $originalBranch) {
        git checkout $originalBranch | Out-Null
    }
    Pop-Location
}
