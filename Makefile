# Directories

bin_d  = $(abspath fsac)

ac_exe     = $(bin_d)/fsautocomplete.dll
ac_archive = fsautocomplete.netcore.zip
ac_url     = https://github.com/fsharp/FsAutoComplete/releases/latest/download/$(ac_archive)

# ----------------------------------------------------------------------------

EXECUTABLES = curl unzip
K := $(foreach exec,$(EXECUTABLES),\
        $(if $(shell which $(exec)),some string,$(error "No $(exec) in PATH")))

# Building

fsautocomplete : $(ac_exe)
$(ac_exe) : $(bin_d)
	curl -L "$(ac_url)" -o "$(bin_d)/$(ac_archive)"
	unzip -o "$(bin_d)/$(ac_archive)" -d "$(bin_d)"
	find $(bin_d) -type f -exec chmod 777 \{\} \;
	touch "$(ac_exe)"

update:
	curl -L "$(ac_url)" -o "$(bin_d)/$(ac_archive)"
	unzip -o "$(bin_d)/$(ac_archive)" -d "$(bin_d)"
	find $(bin_d) -type f -exec chmod 777 \{\} \;
	touch "$(ac_exe)"

$(bin_d)     :; mkdir -p $(bin_d)

# Cleaning

clean :
	rm -rf $(bin_d)

.PHONY: fsautocomplete update clean
