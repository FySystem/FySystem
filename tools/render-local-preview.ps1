param(
    [string]$ReadmePath = "README.md",
    [string]$OutputPath = "preview.html"
)

$ErrorActionPreference = "Stop"

$readme = Get-Content -Raw -LiteralPath $ReadmePath
$body = $readme
$body = [regex]::Replace($body, '!\[([^\]]*)\]\(([^)]+)\)', '<img alt="$1" src="$2" />')
$body = $body -replace '<br />', '<br />'

$html = @"
<!doctype html>
<html lang="zh-CN">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>FySystem README 本地预览</title>
  <style>
    :root {
      color-scheme: dark;
      --bg: #0d1117;
      --panel: #0d1117;
      --line: #30363d;
      --text: #c9d1d9;
    }
    body {
      margin: 0;
      background: #010409;
      color: var(--text);
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
    }
    .markdown-body {
      max-width: 980px;
      margin: 24px auto;
      padding: 32px;
      border: 1px solid var(--line);
      border-radius: 8px;
      background: var(--panel);
    }
    .markdown-body img {
      max-width: 100%;
      height: auto;
      vertical-align: middle;
    }
    .markdown-body a {
      color: #58a6ff;
      text-decoration: none;
    }
  </style>
</head>
<body>
  <main class="markdown-body">
$body
  </main>
</body>
</html>
"@

Set-Content -LiteralPath $OutputPath -Value $html -Encoding UTF8
Write-Host (Resolve-Path -LiteralPath $OutputPath)
