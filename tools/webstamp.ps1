# tools/webstamp.ps1 - build.bat web: stamp each file's hash into
# docs\play\index.html, as tools/webstamp.sh does for make web. The
# snapshot's address ends in &type=.sna because JSSpeccy picks a file's
# type by how the whole address ends (docs/WEB.md).
# -Name and -Dir: the game and its page's folder (atlantis, docs\play by
# default; build.bat web runs it again with trigon, docs\play\trigon).
param([string]$Name = 'atlantis', [string]$Dir = 'docs\play')
$ErrorActionPreference = 'Stop'
$sna = (Get-FileHash "$Dir\$Name.sna" -Algorithm SHA1).Hash.Substring(0, 8).ToLower()
$tap = (Get-FileHash "$Dir\$Name.tap" -Algorithm SHA1).Hash.Substring(0, 8).ToLower()
$page = "$Dir\index.html"
$text = [IO.File]::ReadAllText($page)
$text = $text -replace "'$Name\.sna(\?v=[0-9a-f]+&type=\.sna)?'", "'$Name.sna?v=$sna&type=.sna'"
$text = $text -replace "href=`"$Name\.tap(\?v=[0-9a-f]+)?`"", "href=`"$Name.tap?v=$tap`""
[IO.File]::WriteAllText($page, $text, (New-Object Text.UTF8Encoding $false))
Write-Output "${page}: $Name.sna v=$sna, $Name.tap v=$tap"
