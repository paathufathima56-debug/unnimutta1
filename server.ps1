$port = 5173
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:$port/")
$listener.Prefixes.Add("http://127.0.0.1:$port/")

try {
    $listener.Start()
    Write-Host "UNNIMUTTA Server listening on http://localhost:$port/"
    while ($listener.IsListening) {
        $context = $listener.GetContext()
        [System.Threading.ThreadPool]::QueueUserWorkItem({
            param($ctx)
            try {
                $req = $ctx.Request
                $res = $ctx.Response
                $localPath = $req.Url.LocalPath
                if ($localPath -eq "/" -or [string]::IsNullOrWhiteSpace($localPath)) {
                    $localPath = "/index.html"
                }
                $cleanPath = $localPath.TrimStart('/').Replace('/', [System.IO.Path]::DirectorySeparatorChar)
                $filePath = Join-Path $using:PSScriptRoot $cleanPath

                if (Test-Path $filePath -PathType Leaf) {
                    $bytes = [System.IO.File]::ReadAllBytes($filePath)
                    $ext = [System.IO.Path]::GetExtension($filePath).ToLower()
                    $contentType = switch ($ext) {
                        ".html" { "text/html; charset=utf-8" }
                        ".js"   { "application/javascript; charset=utf-8" }
                        ".css"  { "text/css; charset=utf-8" }
                        ".json" { "application/json; charset=utf-8" }
                        ".svg"  { "image/svg+xml" }
                        ".png"  { "image/png" }
                        ".jpg"  { "image/jpeg" }
                        ".jpeg" { "image/jpeg" }
                        default { "application/octet-stream" }
                    }
                    $res.ContentType = $contentType
                    $res.OutputStream.Write($bytes, 0, $bytes.Length)
                } else {
                    $res.StatusCode = 404
                    $err = [System.Text.Encoding]::UTF8.GetBytes("Not Found: $localPath")
                    $res.OutputStream.Write($err, 0, $err.Length)
                }
            } catch {
                # Ignore client disconnect
            } finally {
                try { $ctx.Response.Close() } catch {}
            }
        }, $context) | Out-Null
    }
} finally {
    $listener.Stop()
}
