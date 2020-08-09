NAMESPACE := $(shell python -c 'import yaml; print(yaml.safe_load(open("galaxy.yml"))["namespace"])')
NAME := $(shell python -c 'import yaml; print(yaml.safe_load(open("galaxy.yml"))["name"])')
VERSION := $(shell python -c 'import yaml; print(yaml.safe_load(open("galaxy.yml"))["version"])')
MANIFEST := build/collections/ansible_collections/$(NAMESPACE)/$(NAME)/MANIFEST.json

PLUGIN_TYPES := $(filter-out __%,$(notdir $(wildcard plugins/*)))
METADATA := galaxy.yml LICENSE README.md
$(foreach PLUGIN_TYPE,$(PLUGIN_TYPES),$(eval _$(PLUGIN_TYPE) := $(filter-out %__init__.py,$(wildcard plugins/$(PLUGIN_TYPE)/*.py))))
DEPENDENCIES := $(METADATA) $(foreach PLUGIN_TYPE,$(PLUGIN_TYPES),$(_$(PLUGIN_TYPE)))

PYTHON_VERSION = $(shell python -c 'import sys; print("{}.{}".format(sys.version_info.major, sys.version_info.minor))')
COLLECTION_COMMAND ?= ansible-galaxy
SANITY_OPTS =
TEST =
PYTEST = pytest -n 4 --boxed -v

default: help
help:
	@echo "Please use \`make <target>' where <target> is one of:"
	@echo "  help           to show this message"
	@echo "  info           to show infos about the collection"
	@echo "  lint           to run code linting"
	@echo "  test           to run unit tests"
	@echo "  sanity         to run santy tests"
	@echo "  test-setup     to install test dependencies"
	@echo "  clean_<test>   to run a specific test playbook with the teardown and cleanup tags"
	@echo "  dist           to build the collection artifact"

info:
	@echo "Building collection $(NAMESPACE)-$(NAME)-$(VERSION)"
	@echo $(foreach PLUGIN_TYPE,$(PLUGIN_TYPES),"\n  $(PLUGIN_TYPE): $(basename $(notdir $(_$(PLUGIN_TYPE))))")

lint: $(MANIFEST)
	yamllint -f parsable playbooks
	ansible-playbook --syntax-check playbooks/util/linux/*.yml | grep -v '^$$'
	black . --diff --check

sanity: $(MANIFEST)
	# Fake a fresh git repo for ansible-test
	cd $(<D) ; git init ; echo tests > .gitignore ; ansible-test sanity $(SANITY_OPTS) --python $(PYTHON_VERSION)

test: $(MANIFEST)
	$(PYTEST) $(TEST)

clean_%: FORCE $(MANIFEST)
	ansible-playbook --tags teardown,cleanup -i tests/inventory/hosts 'tests/playbooks/$*.yaml'

test-setup: requirements.txt
	pip install --upgrade pip
	pip install -r requirements.txt

build/src/%: % | build
	cp $< $@

build:
	-mkdir build build/src build/src/plugins $(addprefix build/src/plugins/,$(PLUGIN_TYPES))

$(NAMESPACE)-$(NAME)-$(VERSION).tar.gz: $(addprefix build/src/,$(DEPENDENCIES)) | build
ifeq ($(COLLECTION_COMMAND),mazer)
	mazer build --collection-path=build/src
	cp build/src/releases/$@ .
else
	ansible-galaxy collection build build/src --force
endif

dist: $(NAMESPACE)-$(NAME)-$(VERSION).tar.gz

publish: $(NAMESPACE)-$(NAME)-$(VERSION).tar.gz
	ansible-galaxy collection publish --api-key $(GALAXY_API_KEY) $<

clean:
	rm -rf build

FORCE:

.PHONY: help dist lint sanity test test-setup publish FORCE
