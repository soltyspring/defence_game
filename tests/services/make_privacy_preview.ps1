# 06-services: build the working-title PREVIEW of the privacy page. Owner: 06-services.
# Usage (workspace root):  pwsh -NoProfile -File tests/services/make_privacy_preview.ps1
# Reads docs/services/privacy_site/index.html (the publishable template; it keeps {{APP_NAME}}) and
# writes docs/services/previews/privacy_preview_working_title.html with {{APP_NAME}} filled by the
# user's working title (Q3, 2026-10-31 16:19 KST), a visible "preview only / KIPRIS not checked"
# banner and robots noindex. The preview is NOT for publishing and lives outside privacy_site/ so
# copying that folder cannot publish it. Other placeholders stay. Checked by
# tests/services/test_services_listing.gd group `privacy_preview` (reverse transform == index.html).
$ErrorActionPreference = 'Stop'
Set-Location (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent)
$ko = '빵집 기사단: 곰팡이 디펜스'
$en = 'Bakery Knights: Mold Defense'
$src = [IO.File]::ReadAllText((Resolve-Path 'docs/services/privacy_site/index.html')) -replace "`r`n", "`n"
$i = $src.IndexOf('<section id="en"')
if ($i -lt 0 -or -not $src.Contains('{{APP_NAME}}')) { throw 'index.html layout changed: no en section or no {{APP_NAME}}' }
$head = $src.Substring(0, $i)
$tail = $src.Substring($i)
$t0 = $head.IndexOf('<title>'); $t1 = $head.IndexOf('</title>')
$titleTag = $head.Substring($t0, $t1 - $t0).Replace('{{APP_NAME}}', "$ko / $en")
$head = $head.Substring(0, $t0) + $titleTag + $head.Substring($t1)
$head = $head.Replace('{{APP_NAME}}', $ko)
$tail = $tail.Replace('{{APP_NAME}}', $en)
$robots = '<meta name="robots" content="noindex, nofollow"> <!-- PREVIEW-ONLY -->'
$banner = @'
<!-- PREVIEW-BANNER BEGIN -->
<div role="note" style="border:3px solid #b00;background:#fee;padding:.8rem;margin-bottom:1.5rem">
<strong>미리보기 전용 — 공개 금지.</strong> 앱 이름은 사용자가 2026-10-31 16:19에 정한 <strong>작업 제목</strong>이며, KIPRIS 9류·41류 상표 조회를 아직 하지 않았습니다(KIPRIS 미확인). 다른 {{…}} 항목도 아직 채우지 않았습니다.<br>
<strong>Preview only — do not publish.</strong> The app name is the user's <strong>working title</strong> (2026-10-31 16:19 KST); the KIPRIS class 9/41 trademark check has not been done (KIPRIS not checked). Other {{…}} items are still unfilled.
</div>
<!-- PREVIEW-BANNER END -->
'@ -replace "`r`n", "`n"
$out = $head + $tail
$out = $out.Replace('<meta charset="utf-8">', "<meta charset=`"utf-8`">`n" + $robots)
$b = $out.IndexOf('<body>')
if ($b -lt 0) { throw 'index.html has no <body>' }
$out = $out.Substring(0, $b + 6) + "`n" + $banner + $out.Substring($b + 6)
New-Item -ItemType Directory -Force 'docs/services/previews' | Out-Null
[IO.File]::WriteAllText((Join-Path (Get-Location) 'docs/services/previews/privacy_preview_working_title.html'), $out, (New-Object System.Text.UTF8Encoding($false)))
Write-Output 'wrote docs/services/previews/privacy_preview_working_title.html'
