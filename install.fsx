// include Fake lib
#r "packages/FAKE/tools/FakeLib.dll"
open Fake
open System
open System.IO
open System.Net
open System.Text.RegularExpressions

let homeVimPath =
    if Environment.OSVersion.Platform = PlatformID.Unix || Environment.OSVersion.Platform = PlatformID.MacOSX then
        Environment.GetEnvironmentVariable("HOME") @@ ".vim"
    else Environment.ExpandEnvironmentVariables("%HOMEDRIVE%%HOMEPATH%") @@ "vimfiles"

let vimInstallDir = homeVimPath @@ "bundle/vim_fsharp_languageclient"

let vimBinDir = __SOURCE_DIRECTORY__ @@ "fsac"
let ftpluginDir = __SOURCE_DIRECTORY__ @@ "ftplugin"
let autoloadDir = __SOURCE_DIRECTORY__ @@ "autoload"
let syntaxDir = __SOURCE_DIRECTORY__ @@ "syntax"
let indentDir = __SOURCE_DIRECTORY__ @@ "indent"
let ftdetectDir = __SOURCE_DIRECTORY__ @@ "ftdetect"

let acArchive = "fsautocomplete.netcore.zip"
let acVersion = "master"

Target "FSharp.AutoComplete" (fun _ ->
  CreateDir vimBinDir
  use client = new WebClient()
  Net.ServicePointManager.SecurityProtocol <- Net.SecurityProtocolType.Tls12
  tracefn "Downloading version %s of FsAutoComplete" acVersion
  client.DownloadFile(sprintf "https://ci.appveyor.com/api/projects/fsautocomplete/fsautocomplete/artifacts/bin/pkgs/%s?branch=%s" acArchive acVersion, vimBinDir @@ acArchive)
  tracefn "Download complete"
  tracefn "Unzipping"
  Unzip vimBinDir (vimBinDir @@ acArchive))

Target "Install" (fun _ ->
    DeleteDir vimInstallDir
    CreateDir vimInstallDir
    CopyDir (vimInstallDir @@ "fsac") vimBinDir (fun _ -> true)
    CopyDir (vimInstallDir @@ "ftplugin") ftpluginDir (fun _ -> true)
    CopyDir (vimInstallDir @@ "autoload") autoloadDir (fun _ -> true)
    CopyDir (vimInstallDir @@ "syntax") syntaxDir (fun _ -> true)
    CopyDir (vimInstallDir @@ "indent") indentDir (fun _ -> true)
    CopyDir (vimInstallDir @@ "ftdetect") ftdetectDir (fun _ -> true))

Target "Clean" (fun _ ->
    CleanDirs [ vimBinDir; vimInstallDir ])

Target "All" id

"FSharp.AutoComplete"
    ==> "Install"
    ==> "All"

RunTargetOrDefault "All"
