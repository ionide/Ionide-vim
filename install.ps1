Param(
    [String]$Arg1 = "install"
)
$bin_d  = Join-Path $PSScriptRoot "fsac"

$ac_exe     = "${bin_d}/fsautocomplete.dll"
$ac_archive = "fsautocomplete.netcore.zip"
$ac_url     = "https://github.com/fsharp/FsAutoComplete/releases/latest/download/${ac_archive}"
$zip_path   = (Join-Path $bin_d $ac_archive)

Function Update {
  New-Item $bin_d -ItemType Directory -Force | Out-Null

  echo "Downloading the latest release of $ac_archive"
  Invoke-WebRequest -Uri $ac_url -outfile $zip_path

  echo "Unzipping $ac_archive to $bin_d"
  Expand-Archive -Path $zip_path -DestinationPath $bin_d -Force
  if (!(Test-Path $ac_exe)) { Write-Warning "something is wrong" }
}

Function Install {
  if (!(Test-Path $ac_exe)) { Update }
  else {
    echo "$ac_exe is already installed"
  }
}

if ($Arg1 -eq "install") { Install }
elseif ($Arg1 -eq "update") { Update }
else {
  echo "usage install.ps1 [install|update] (default: install)"
}

