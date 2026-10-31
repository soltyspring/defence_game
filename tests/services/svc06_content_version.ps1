# 06-services: content_version outside Godot, same algorithm as 02's src/core/content.gd
# _compute_content_version(root="res://data"): sort the full paths of every *.json under data/ (hidden dirs
# skipped); for each file hash  <path without root>  "\n"  <file bytes>  "\n"  with SHA-256; result
# "c1-" + first 12 hex chars. Dot-source it. No Godot needed; read-only.
# Validated against 10's published values for 7b93d1f (LF c1-a7b265ce4f6f, CRLF c1-ea9c929ba40e).

## $Files: ordered dictionary or hashtable  "/units/units.json" -> [byte[]]
function Get-SvcContentVersion($Files) {
  $sha = [Security.Cryptography.SHA256]::Create()
  $ms = New-Object IO.MemoryStream
  $nl = [byte[]](10)
  # Godot sorts "res://data/<rel>" strings by code point; ordinal sort of the same strings matches.
  $keys = [string[]]@($Files.Keys)
  [Array]::Sort($keys, [StringComparer]::Ordinal)
  foreach ($k in $keys) {
    $p = [Text.Encoding]::UTF8.GetBytes($k)
    $ms.Write($p, 0, $p.Length); $ms.Write($nl, 0, 1)
    $b = [byte[]]$Files[$k]
    $ms.Write($b, 0, $b.Length); $ms.Write($nl, 0, 1)
  }
  $h = $sha.ComputeHash($ms.ToArray())
  return 'c1-' + (($h | ForEach-Object { $_.ToString('x2') }) -join '').Substring(0, 12)
}

## Committed bytes of data/**/*.json at <Ref> (git blobs, no checkout conversion).
function Get-SvcBlobDataFiles([string]$Ref) {
  $out = [ordered]@{}
  foreach ($f in (git ls-tree -r --name-only $Ref -- data | Where-Object { $_ -like '*.json' })) {
    $rel = $f.Substring(4)   # "data/x/y.json" -> "/x/y.json"
    if ($rel -match '/\.') { continue }
    $tmp = [IO.Path]::GetTempFileName()
    cmd /c "git cat-file blob `"$Ref`:$f`" > `"$tmp`""
    $out[$rel] = [IO.File]::ReadAllBytes($tmp)
    Remove-Item $tmp -Force
  }
  $out
}

## Count line endings: returns @{crlf=..; lf=..} for one byte array.
function Get-SvcEol([byte[]]$b) {
  $crlf = 0; $lf = 0
  for ($i = 0; $i -lt $b.Length; $i++) { if ($b[$i] -eq 10) { if ($i -gt 0 -and $b[$i - 1] -eq 13) { $crlf++ } else { $lf++ } } }
  @{ crlf = $crlf; lf = $lf }
}
