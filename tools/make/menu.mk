# help / menu / help-check / help-doc cho makefile bat ky. Trong makefile chi can:
#   -include $(HOME)/.local/share/make-menu/menu.mk     (sau khi chay install.sh)
# Mo ta viet bang chu thich ## ngay tai target — xem README.md cung thu muc.
#
# Khong doi default goal cua makefile include no: muon `make` = help thi tu
# dat `.DEFAULT_GOAL := help`.
MM_GOAL := $(.DEFAULT_GOAL)
MM_DIR  := $(dir $(realpath $(lastword $(MAKEFILE_LIST))))
MM      := $(MM_DIR)mm -f $(firstword $(MAKEFILE_LIST))

.PHONY: help menu help-check help-doc
help:
	@$(MM) help
menu:
	@$(MM) menu
help-check:
	@$(MM) check
help-doc:
	@$(MM) doc

.DEFAULT_GOAL := $(MM_GOAL)
