# Serves the web build in docs/ at http://localhost:8060 for local testing (no Python needed).
param([int]$Port = 8060)
$root = Join-Path (Split-Path -Parent $PSScriptRoot) "docs"
$types = @{ ".html" = "text/html"; ".js" = "application/javascript"; ".wasm" = "application/wasm";
            ".pck" = "application/octet-stream"; ".png" = "image/png"; ".svg" = "image/svg+xml" }
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:$Port/")
$listener.Start()
Write-Host "Serving $root at http://localhost:$Port/"
while ($listener.IsListening) {
    $ctx = $listener.GetContext()
    $path = [Uri]::UnescapeDataString($ctx.Request.Url.AbsolutePath.TrimStart('/'))
    if ($path -eq "") { $path = "index.html" }
    $file = Join-Path $root $path
    if ((Test-Path $file -PathType Leaf) -and ((Resolve-Path $file).Path.StartsWith($root))) {
        $bytes = [IO.File]::ReadAllBytes($file)
        $ext = [IO.Path]::GetExtension($file).ToLower()
        $ctx.Response.ContentType = $(if ($types.ContainsKey($ext)) { $types[$ext] } else { "application/octet-stream" })
        $ctx.Response.Headers.Add("Cache-Control", "no-store")   # always test the latest export
        $ctx.Response.ContentLength64 = $bytes.Length
        $ctx.Response.OutputStream.Write($bytes, 0, $bytes.Length)
    } else {
        $ctx.Response.StatusCode = 404
    }
    $ctx.Response.Close()
}
