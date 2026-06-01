param(
    [string]$ReadmePath = "README.md"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $ReadmePath)) {
    throw "找不到 README 文件: $ReadmePath"
}

$readme = Get-Content -Raw -LiteralPath $ReadmePath
$readmeDir = Split-Path -Parent $ReadmePath
if ([string]::IsNullOrWhiteSpace($readmeDir)) {
    $readmeDir = "."
}
$urls = New-Object System.Collections.Generic.List[string]

[regex]::Matches($readme, '<img[^>]+src="([^"]+)"') | ForEach-Object {
    $urls.Add($_.Groups[1].Value)
}

[regex]::Matches($readme, '<source[^>]+srcset="([^"]+)"') | ForEach-Object {
    $urls.Add($_.Groups[1].Value)
}

[regex]::Matches($readme, '!\[[^\]]*\]\(([^)]+)\)') | ForEach-Object {
    $urls.Add($_.Groups[1].Value)
}

$uniqueUrls = $urls | Where-Object { $_ } | Select-Object -Unique
if (-not $uniqueUrls) {
    throw "README 中没有找到图片引用"
}

$failures = New-Object System.Collections.Generic.List[string]

foreach ($url in $uniqueUrls) {
    if ($url.StartsWith("./") -or $url.StartsWith("../")) {
        $localPath = Join-Path $readmeDir $url
        if (-not (Test-Path -LiteralPath $localPath)) {
            $failures.Add("本地图片不存在: $url")
            continue
        }
        Write-Host "OK local $url"
        if ([System.IO.Path]::GetExtension($localPath) -eq ".svg") {
            $svg = Get-Content -Raw -LiteralPath $localPath
            [regex]::Matches($svg, '<image[^>]+(?:href|xlink:href)="([^"]+)"') | ForEach-Object {
                $urls.Add($_.Groups[1].Value)
            }
        }
        continue
    }

    try {
        $response = Invoke-WebRequest -Uri $url -UseBasicParsing -Headers @{ "User-Agent" = "FySystem-README-check" } -TimeoutSec 25
        $contentType = [string]$response.Headers["Content-Type"]
        if ($response.StatusCode -lt 200 -or $response.StatusCode -ge 300) {
            $failures.Add("HTTP $($response.StatusCode): $url")
            continue
        }
        if ($contentType -notmatch '^image/') {
            $failures.Add("不是图片响应: $url -> $contentType")
            continue
        }
        Write-Host "OK remote $url -> $contentType"
    }
    catch {
        $failures.Add("请求失败: $url -> $($_.Exception.Message)")
    }
}

$nestedUrls = $urls | Where-Object { $_ } | Select-Object -Unique
foreach ($url in $nestedUrls) {
    if ($uniqueUrls -contains $url) {
        continue
    }
    if ($url.StartsWith("./") -or $url.StartsWith("../")) {
        continue
    }
    try {
        $response = Invoke-WebRequest -Uri $url -UseBasicParsing -Headers @{ "User-Agent" = "FySystem-README-check" } -TimeoutSec 25
        $contentType = [string]$response.Headers["Content-Type"]
        if ($response.StatusCode -lt 200 -or $response.StatusCode -ge 300) {
            $failures.Add("HTTP $($response.StatusCode): $url")
            continue
        }
        if ($contentType -notmatch '^image/') {
            $failures.Add("不是图片响应: $url -> $contentType")
            continue
        }
        Write-Host "OK nested $url -> $contentType"
    }
    catch {
        $failures.Add("请求失败: $url -> $($_.Exception.Message)")
    }
}

if ($failures.Count -gt 0) {
    Write-Host "README 图片检查失败:"
    $failures | ForEach-Object { Write-Host " - $_" }
    exit 1
}

Write-Host "README 图片检查通过，共 $($uniqueUrls.Count) 个图片引用。"
