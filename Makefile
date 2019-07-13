# Directories

bin_d  = $(abspath fsac)

# Installation paths.
#dest_root = $(HOME)/.vim/bundle/vim-fsharp/
#dest_bin  = $(dest_root)/ftplugin/bin/

ac_exe     = $(bin_d)/fsautocomplete.exe
ac_archive = fsautocomplete.netcore.zip
ac_version = master
ac_url     = https://github.com/fsharp/FSharp.AutoComplete/releases/download/$(ac_version)/$(ac_archive)
ac_url     = https://ci.appveyor.com/api/projects/fsautocomplete/fsautocomplete/artifacts/bin/pkgs/$(ac_archive)?branch=$(ac_version)
	
git_url    = https://github.com/fsharp/FsAutoComplete.git

# ----------------------------------------------------------------------------

# Building

fsautocomplete : $(ac_exe)
$(ac_exe) : $(bin_d)
	curl -L "$(ac_url)" -o "$(bin_d)/$(ac_archive)"
	unzip "$(bin_d)/$(ac_archive)" -d "$(bin_d)"
	touch "$(ac_exe)"

~/.config/.mono/certs:
	mozroots --import --sync --quiet

$(dest_root) :; mkdir -p $(dest_root)
$(dest_bin)  :; mkdir -p $(dest_bin)
$(bin_d)     :; mkdir -p $(bin_d)

# Cleaning

clean :
	rm -rf $(bin_d)
	rm -rf FsAutoComplete

git :
	rm -rf FsAutoComplete
	rm -rf $(bin_d)
	git clone $(git_url)
	./FsAutoComplete/build.sh BuildRelease
	mkdir $(bin_d)
	cp FsAutoComplete/src/FsAutoComplete/bin/Release/* $(bin_d)


.PHONY: fsautocomplete
