param(
    [string]$ReadmePath = "README.md"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $ReadmePath)) {
    throw "找不到 README 文件: $ReadmePath"
}

$readme = Get-Content -Raw -LiteralPath $ReadmePath
$failures = New-Object System.Collections.Generic.List[string]

$forbiddenPhrases = @(
    "避免外部统计卡片加载失败",
    "不依赖容易 503",
    "本地 SVG 表达方向",
    "外部统计卡片"
)

foreach ($phrase in $forbiddenPhrases) {
    if ($readme.Contains($phrase)) {
        $failures.Add("README 不应出现实现说明文案: $phrase")
    }
}

if ($readme -notmatch '\./assets/dashboard\.svg') {
    $failures.Add("README 应使用整合布局图: ./assets/dashboard.svg")
}

$readmeDir = Split-Path -Parent $ReadmePath
if ([string]::IsNullOrWhiteSpace($readmeDir)) {
    $readmeDir = "."
}
$dashboardPath = Join-Path $readmeDir "assets/dashboard.svg"
if (Test-Path -LiteralPath $dashboardPath) {
    $dashboard = Get-Content -Raw -LiteralPath $dashboardPath
    if ($dashboard -notmatch "贡献蛇") {
        $failures.Add("dashboard.svg 应保留贡献蛇模块")
    }
    if ($dashboard -match "scaleX") {
        $failures.Add("dashboard.svg 进度条动画不应使用 scaleX，避免跨面板位移")
    }
}

if ($readme -match '\./assets/projects\.svg') {
    $failures.Add("README 不应继续使用分散项目面板: ./assets/projects.svg")
}

if ($readme -match '\./assets/status\.svg') {
    $failures.Add("README 不应继续使用分散状态面板: ./assets/status.svg")
}

$localReadmeImages = [regex]::Matches($readme, '!\[[^\]]*\]\((\./assets/[^)]+)\)') |
    ForEach-Object { $_.Groups[1].Value } |
    Select-Object -Unique

$allowedLocalImages = @("./assets/dashboard.svg")
foreach ($image in $localReadmeImages) {
    if ($allowedLocalImages -notcontains $image) {
        $failures.Add("README 中的本地主视觉应收敛到 dashboard.svg，发现: $image")
    }
}

$allImageRefs = New-Object System.Collections.Generic.List[string]
[regex]::Matches($readme, '<img[^>]+src="([^"]+)"') | ForEach-Object {
    $allImageRefs.Add($_.Groups[1].Value)
}
[regex]::Matches($readme, '<source[^>]+srcset="([^"]+)"') | ForEach-Object {
    $allImageRefs.Add($_.Groups[1].Value)
}
[regex]::Matches($readme, '!\[[^\]]*\]\(([^)]+)\)') | ForEach-Object {
    $allImageRefs.Add($_.Groups[1].Value)
}

$uniqueImageRefs = @($allImageRefs | Where-Object { $_ } | Select-Object -Unique)
if ($uniqueImageRefs.Count -ne 1 -or $uniqueImageRefs[0] -ne "./assets/dashboard.svg") {
    $failures.Add("README 应收敛为单张主视觉图，当前图片引用数: $($uniqueImageRefs.Count)")
}

if ($failures.Count -gt 0) {
    Write-Host "README 布局检查失败:"
    $failures | ForEach-Object { Write-Host " - $_" }
    exit 1
}

Write-Host "README 布局检查通过。"
