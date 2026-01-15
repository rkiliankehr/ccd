# ccd - quick directory navigation
# https://github.com/rkiliankehr/ccd

INSTALL_DIR = $(HOME)/bin
INSTALL_PATH = $(INSTALL_DIR)/ccd

.PHONY: all install uninstall help

all: help

help:
	@echo "ccd - quick directory navigation"
	@echo ""
	@echo "Usage:"
	@echo "  make install    Install ccd to ~/bin and add shell function"
	@echo "  make uninstall  Remove ccd from ~/bin"
	@echo "  make help       Show this help"

install:
	@./install.sh

uninstall:
	@echo "Removing ccd..."
	@rm -f $(INSTALL_PATH)
	@echo "Removed $(INSTALL_PATH)"
	@echo ""
	@echo "Note: Shell function in your .bashrc/.zshrc was not removed."
	@echo "Remove manually if desired:"
	@echo "  function ccd() { source ~/bin/ccd \"\$$@\"; }"
