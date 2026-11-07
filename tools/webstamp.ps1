# tools/webstamp.ps1 - build.bat web: stamp each file's hash into
# docs\play\index.html, as tools/webstamp.sh does for make web. The
# snapshot's address ends in &type=.sna because JSSpeccy picks a file's
# type by how the whole address ends (docs/WEB.md).
$ErrorActionPreference = 'Stop'
$sna = (Get-FileHash 'build\atlantis.sna' -Algorithm SHA1).Hash.Substring(0, 8).ToLower()
$tap = (Get-FileHash 'build\atlantis.tap' -Algorithm SHA1).Hash.Substring(0, 8).ToLower()
$page = 'docs\play\index.html'
$text = [IO.File]::ReadAllText($page)
$text = $text -replace "'atlantis\.sna(\?v=[0-9a-f]+&type=\.sna)?'", "'atlantis.sna?v=$sna&type=.sna'"
$text = $text -replace 'href="atlantis\.tap(\?v=[0-9a-f]+)?"', "href=`"atlantis.tap?v=$tap`""
[IO.File]::WriteAllText($page, $text, (New-Object Text.UTF8Encoding $false))
Write-Output "docs\play\index.html: atlantis.sna v=$sna, atlantis.tap v=$tap"
