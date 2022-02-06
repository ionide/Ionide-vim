# FsAutoComplete should now be installed via `dotnet tool install`.
# This Makefile is just for users who still call `make fsautocomplete`
# because they don't update their .vimrc.

fsautocomplete :
	@echo \'make fsautocomplete\' is deprecated. Install FSAC via \'dotnet tool install\'.

update: fsautocomplete

clean :

.PHONY: fsautocomplete update clean
