.DEFAULT_GOAL := help

.PHONY: clean
clean:
	python3 setup.py clean
	rm src/PIL/*.so || true
	rm -r build || true
	find . -name __pycache__ | xargs rm -r || true

.PHONY: coverage
coverage:
	python3 -c "import pytest" > /dev/null 2>&1 || python3 -m pip install pytest
	python3 -m pytest -qq
	rm -r htmlcov || true
	python3 -c "import coverage" > /dev/null 2>&1 || python3 -m pip install coverage
	python3 -m coverage report

.PHONY: doc
doc:
	$(MAKE) -C docs html

.PHONY: doccheck
doccheck:
	$(MAKE) -C docs html
# Don't make our tests rely on the links in the docs being up every single build.
# We don't control them.  But do check, and update them to the target of their redirects.
	$(MAKE) -C docs linkcheck || true

.PHONY: docserve
docserve:
	cd docs/_build/html && python3 -m http.server 2> /dev/null&

.PHONY: help
help:
	@echo "Welcome to Pillow development. Please use \`make <target>\` where <target> is one of"
	@echo "  clean              remove build products"
	@echo "  coverage           run coverage test (in progress)"
	@echo "  doc                make HTML docs"
	@echo "  docserve           run an HTTP server on the docs directory"
	@echo "  html               to make standalone HTML files"
	@echo "  inplace            make inplace extension"
	@echo "  install            make and install"
	@echo "  install-coverage   make and install with C coverage"
	@echo "  lint               run the lint checks"
	@echo "  lint-fix           run Black and isort to (mostly) fix lint issues"
	@echo "  release-test       run code and package tests before release"
	@echo "  test               run tests on installed Pillow"

.PHONY: inplace
inplace: clean
	python3 -m pip install -e --global-option="build_ext" --global-option="--inplace" .

.PHONY: install
install:
	python3 -m pip install .
	python3 selftest.py

.PHONY: install-coverage
install-coverage:
	CFLAGS="-coverage -Werror=implicit-function-declaration" python3 -m pip install --global-option="build_ext" .
	python3 selftest.py

.PHONY: debug
debug:
# make a debug version if we don't have a -dbg python. Leaves in symbols
# for our stuff, kills optimization, and redirects to dev null so we
# see any build failures.
	make clean > /dev/null
	CFLAGS='-g -O0' python3 -m pip install --global-option="build_ext" . > /dev/null

.PHONY: release-test
release-test:
	python3 -m pip install -e .[tests]
	python3 selftest.py
	python3 -m pytest Tests
	python3 -m pip install .
	-rm dist/*.egg
	-rmdir dist
	python3 -m pytest -qq
	check-manifest
	python3 -m pyroma .
	$(MAKE) readme

.PHONY: sdist
sdist:
	python3 -m build --help > /dev/null 2>&1 || python3 -m pip install build
	python3 -m build --sdist

.PHONY: test
test:
	python3 -c "import pytest" > /dev/null 2>&1 || python3 -m pip install pytest
	python3 -m pytest -qq

.PHONY: valgrind
valgrind:
	python3 -c "import pytest_valgrind" > /dev/null 2>&1 || python3 -m pip install pytest-valgrind
	PYTHONMALLOC=malloc valgrind --suppressions=Tests/oss-fuzz/python.supp --leak-check=no \
            --log-file=/tmp/valgrind-output \
            python3 -m pytest --no-memcheck -vv --valgrind --valgrind-log=/tmp/valgrind-output

.PHONY: readme
readme:
	python3 -c "import markdown2" > /dev/null 2>&1 || python3 -m pip install markdown2
	python3 -m markdown2 README.md > .long-description.html && open .long-description.html


.PHONY: lint
lint:
	python3 -c "import tox" > /dev/null 2>&1 || python3 -m pip install tox
	python3 -m tox -e lint

.PHONY: lint-fix
lint-fix:
	python3 -c "import black" > /dev/null 2>&1 || python3 -m pip install black
	python3 -c "import isort" > /dev/null 2>&1 || python3 -m pip install isort
	python3 -m black --target-version py37 .
	python3 -m isort .
