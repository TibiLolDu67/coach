# Petit serveur local pour tester l'appli (le service worker ne marche pas en file://)
$root = Split-Path $PSScriptRoot -Parent
$types = @{'.html'='text/html; charset=utf-8';'.js'='text/javascript';'.webmanifest'='application/manifest+json';'.png'='image/png';'.json'='application/json'}
$l = New-Object System.Net.HttpListener
$l.Prefixes.Add('http://localhost:8123/')
$l.Start()
Write-Host 'Coach sur http://localhost:8123/'
while ($l.IsListening) {
  $c = $l.GetContext()
  $p = [Uri]::UnescapeDataString($c.Request.Url.AbsolutePath).TrimStart('/')
  if (-not $p) { $p = 'index.html' }
  $f = Join-Path $root $p
  if ((Test-Path $f -PathType Leaf) -and ((Resolve-Path $f).Path.StartsWith($root))) {
    $b = [IO.File]::ReadAllBytes($f)
    $t = $types[[IO.Path]::GetExtension($f)]
    if ($t) { $c.Response.ContentType = $t }
    $c.Response.Headers['Cache-Control'] = 'no-cache'
    try { $c.Response.ContentLength64 = $b.Length; if ($c.Request.HttpMethod -ne 'HEAD') { $c.Response.OutputStream.Write($b, 0, $b.Length) } } catch {}
  } else { $c.Response.StatusCode = 404 }
  try { $c.Response.Close() } catch {}
}
