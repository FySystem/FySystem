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
    foreach ($forbidden in @("oasis-skill-plus", "oasis-origins-mcp", "Oasis 玩法能力扩展", "Windows 底层实验", "Game Tooling", "Driver Lab")) {
        if ($dashboard.Contains($forbidden)) {
            $failures.Add("dashboard.svg 不应显示过时或具体项目文案: $forbidden")
        }
    }
    foreach ($required in @("Windows 驱动开发", "游戏外挂")) {
        if (-not $dashboard.Contains($required)) {
            $failures.Add("dashboard.svg 应显示新方向文案: $required")
        }
    }
    if ($dashboard -match "scaleX") {
        $failures.Add("dashboard.svg 进度条动画不应使用 scaleX，避免跨面板位移")
    }
    $barTrackMatches = [regex]::Matches($dashboard, '<rect x="(?<x>\d+)" y="(?<y>\d+)" width="(?<track>\d+)" height="14" rx="7" fill="#21262D"/>\s*<rect class="(?<class>bar-[a-z])"')
    $barTrackWidths = @{}
    foreach ($match in $barTrackMatches) {
        $barTrackWidths[$match.Groups["class"].Value] = [double]$match.Groups["track"].Value
    }
    foreach ($barName in $barTrackWidths.Keys) {
        $keyframeName = "load" + $barName.Substring(4).ToUpperInvariant()
        $keyframeMatch = [regex]::Match($dashboard, "@keyframes $keyframeName \{[^\n]*\}")
        if (-not $keyframeMatch.Success) {
            $failures.Add("未找到 $barName 对应动画: $keyframeName")
            continue
        }
        $widths = [regex]::Matches($keyframeMatch.Value, 'width:\s*(\d+(?:\.\d+)?)px') |
            ForEach-Object { [double]$_.Groups[1].Value }
        foreach ($width in $widths) {
            if ($width -gt $barTrackWidths[$barName]) {
                $failures.Add("$barName 动画宽度 $width px 超过轨道宽度 $($barTrackWidths[$barName]) px")
            }
        }
    }
    if ($dashboard -notmatch '<g[^>]+id="snake-vertical"') {
        $failures.Add("贡献蛇应改为右侧纵向模块，并标记为 snake-vertical")
    }
    if ($dashboard -notmatch '<rect x="760" y="184" width="96" height="466"') {
        $failures.Add("贡献蛇应位于右侧纵向栏，而不是底部横向模块")
    }
    if ($dashboard -match '<image[^>]+href="https?://') {
        $failures.Add("dashboard.svg 不应在内部引用远端图片，避免 GitHub README 渲染失败")
    }
    if ($dashboard -notmatch 'id="snake-inline"') {
        $failures.Add("贡献蛇应内联到 dashboard.svg，并标记为 snake-inline")
    }
    foreach ($snakeMarker in @("Generated with https://github.com/Platane/snk", 'class="c ', 'class="u ', 'class="s ')) {
        if (-not $dashboard.Contains($snakeMarker)) {
            $failures.Add("贡献蛇应使用真实 Platane/snk 产物内联，而不是手写模拟数据，缺少标记: $snakeMarker")
        }
    }
    $snakeFrameMatch = [regex]::Match($dashboard, '<svg x="(?<x>-?\d+(?:\.\d+)?)" y="(?<y>-?\d+(?:\.\d+)?)" width="(?<width>\d+(?:\.\d+)?)" height="(?<height>\d+(?:\.\d+)?)" viewBox="[^"]+" preserveAspectRatio="xMidYMid meet" transform="rotate\(90 (?<cx>-?\d+(?:\.\d+)?) (?<cy>-?\d+(?:\.\d+)?)\)">')
    if ($snakeFrameMatch.Success) {
        $containerX = 786.0
        $containerY = 276.0
        $panelX = 760.0
        $panelY = 184.0
        $panelWidth = 96.0
        $panelHeight = 466.0
        $contentTop = 276.0
        $contentBottom = 628.0
        $x = [double]$snakeFrameMatch.Groups["x"].Value
        $y = [double]$snakeFrameMatch.Groups["y"].Value
        $width = [double]$snakeFrameMatch.Groups["width"].Value
        $height = [double]$snakeFrameMatch.Groups["height"].Value
        $cx = [double]$snakeFrameMatch.Groups["cx"].Value
        $cy = [double]$snakeFrameMatch.Groups["cy"].Value
        $corners = @(
            [pscustomobject]@{ X = $x; Y = $y },
            [pscustomobject]@{ X = $x + $width; Y = $y },
            [pscustomobject]@{ X = $x; Y = $y + $height },
            [pscustomobject]@{ X = $x + $width; Y = $y + $height }
        )
        $rotated = foreach ($corner in $corners) {
            $px = [double]$corner.X
            $py = [double]$corner.Y
            [pscustomobject]@{
                X = $containerX + $cx - ($py - $cy)
                Y = $containerY + $cy + ($px - $cx)
            }
        }
        $minX = ($rotated | Measure-Object -Property X -Minimum).Minimum
        $maxX = ($rotated | Measure-Object -Property X -Maximum).Maximum
        $minY = ($rotated | Measure-Object -Property Y -Minimum).Minimum
        $maxY = ($rotated | Measure-Object -Property Y -Maximum).Maximum
        if ($minX -lt $panelX -or $maxX -gt ($panelX + $panelWidth) -or $minY -lt $contentTop -or $maxY -gt $contentBottom) {
            $failures.Add("真实贡献蛇旋转后越出右侧内容区: x=$([math]::Round($minX, 1))..$([math]::Round($maxX, 1)), y=$([math]::Round($minY, 1))..$([math]::Round($maxY, 1))")
        }
    }
    else {
        $failures.Add("未找到真实贡献蛇内联 SVG 的定位参数")
    }
    if ($dashboard -notmatch '<rect x="44" y="386" width="692" height="264"') {
        $failures.Add("提交轨迹应上移到项目卡片空位并增加高度")
    }
    $trackMatch = [regex]::Match($dashboard, '<text[^>]*>提交轨迹</text>[\s\S]*?<polyline points="([^"]+)"')
    if ($trackMatch.Success) {
        $pointNumbers = [regex]::Matches($trackMatch.Groups[1].Value, '-?\d+(?:\.\d+)?') |
            ForEach-Object { [double]$_.Value }
        for ($i = 1; $i -lt $pointNumbers.Count; $i += 2) {
            if ($pointNumbers[$i] -lt 470) {
                $failures.Add("提交轨迹折线进入标题区域，y=$($pointNumbers[$i])；折线 y 坐标应 >= 470")
                break
            }
        }
    }
    else {
        $failures.Add("未找到提交轨迹折线模块")
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
