# Ensure emacs always runs from this makefile's PWD
EMACS_LIBS=-l core/core.el
EMACS=/usr/local/bin/emacs --batch --eval '(setq user-emacs-directory default-directory)' $(EMACS_LIBS)
TEST_EMACS=$(EMACS) --eval '(setq noninteractive nil)' $(EMACS_LIBS)
TESTS=$(shell find test/ -type f -name 'test-*.el')

all: autoloads autoremove install

## Package management
install: init.el .local/autoloads.el
	@$(EMACS) -f doom/packages-install

update: init.el .local/autoloads.el
	@$(EMACS) -f doom/packages-update

autoremove: init.el .local/autoloads.el
	@$(EMACS) -f doom/packages-autoremove

autoloads: init.el
	@$(EMACS) -f doom/reload-autoloads


## Byte compilation
# compile
# compile:core
# compile:module
# compile:module/submodule
compile: init.el clean
	@$(EMACS) -f doom/compile

compile\:core: init.el clean
	@$(EMACS) -f doom/compile -- init.el core

$(patsubst %, compile\:%, $(MODULES)): init.el .local/autoloads.el
	@rm -fv $(shell find $(patsubst compile:%, modules/%, $@) -type f -name '*.elc')
	@$(EMACS) -f doom/compile -- $(patsubst compile:%, modules/%, $@)

recompile: init.el
	@$(EMACS) -f doom/recompile

clean:
	@$(EMACS) -f doom/clean-compiled-files

clean-pcache:
	@$(EMACS) -l persistent-soft --eval '(delete-directory pcache-directory t)'

reset:
	@$(EMACS) -f doom/reset


## Unit tests
# test
# test:core
# test:module
# test:module/submodule
test: init.el .local/autoloads.el
	@$(EMACS) -f doom-run-tests

test\:core $(patsubst %, test\:%, $(MODULES)): init.el .local/autoloads.el
	@$(EMACS) -f doom-run-tests -- $(subst test:, , $@)

# run tests interactively
testi: init.el .local/autoloads.el
	@$(EMACSI) -f doom-run-tests -f ert


## Utility tasks
# Runs Emacs from a different folder than ~/.emacs.d
run:
	@$(EMACSI) -l init.el

# Diagnoses potential OS/environment issues
doctor:
	@./bin/doom-doctor

## Internal tasks
init.el:
	@$(error No init.el file; create one or copy init.example.el)

.local/autoloads.el:
	@$(EMACS) -f doom-initialize-autoloads

%.elc: %.el
	@$(EMACS) -f doom/compile -- $<

.PHONY: all compile test testi
