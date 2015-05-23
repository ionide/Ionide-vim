$vimInstallDir = "~\vimfiles\bundle\fsharpbinding-vim"

$local = Get-Location
$vimBinDir = Join-Path $local "ftplugin\bin"
$ftpluginDir = Join-Path $local "ftplugin"
$autoloadDir = Join-Path $local "autoload"
$syntaxDir = Join-Path $local "syntax"
$ftdetectDir = Join-Path $local "ftdetect"
$syntaxCheckersDir = Join-Path $local "syntax_checkers"

$acArchive = "fsautocomplete.zip"
$acVersion = "0.15.0"

# Building

if ((Test-Path $vimBinDir) -eq 0)
{
    md $vimBinDir
}
$url = "https://github.com/fsharp/FSharp.AutoComplete/releases/downloads/" + $acVersion + "/" + $acArchive
$file = Join-Path $vimBinDir $acArchive
Write-Output $file
$client = New-Object System.Net.WebClient
# TODO: get this working
#$client.DownloadFile($url, $file)
$client.Dispose()

# Installing

rm -r $vimInstallDir
md $vimInstallDir
cp -r (Join-Path $vimInstallDir "ftplugin") $ftpluginDir
cp -r (Join-Path $vimInstallDir "autoload") $autoloadDir
cp -r (Join-Path $vimInstallDir "syntax") $syntaxDir
cp -r (Join-Path $vimInstallDir "syntax_checkers") $syntax_checkersDir
cp -r (Join-Path $vimInstallDir "ftdetect") $ftdetectDir

# TODO: test for errors and only print the following if no errors occurred.
Write-Output ("Installed to " + $vimInstallDir)

