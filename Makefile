VERSION = 0.8.22

.PHONY: all
all: mok.deploy tags

mok.deploy: src/*.sh src/lib/*.sh mok-image mok-image/* mok-image/files/*
	bash src/embed-dockerfile.sh
	cd src && ( echo '#!/usr/bin/env bash'; cat macos.sh \
		lib/parser.sh globals.sh error.sh util.sh getcluster.sh machine.sh \
		exec.sh deletecluster.sh createcluster.sh versions.sh containerutils.sh \
		buildimage.deploy lib/JSONPath.sh main.sh; \
		printf 'if [ "$$0" = "$${BASH_SOURCE[0]}" ] || [ -z "$${BASH_SOURCE[0]}" ]; then\n  MA_main "$$@"\nfi\n' \
		) >../mok.deploy
	chmod +x mok.deploy
	# cp mok.deploy package/

.PHONY: package
package: mok.deploy
	cp -v mok.deploy package/mok

.PHONY: install
install: all
	install mok.deploy /usr/local/bin/mok

.PHONY: uninstall
uninstall:
	rm -f /usr/local/bin/mok

.PHONY: clean
clean:
	rm -f mok.deploy src/buildimage.deploy package/mok.deploy \
		tests/hardcopy tests/screenlog.0 tags

.PHONY: test
test: clean mok.deploy
	shellcheck mok.deploy
	shfmt -s -i 2 -d src/*.sh
	cd tests && ./usage-checks.sh && ./e2e-tests.sh

.PHONY: buildtest
buildtest: clean mok.deploy
	./tests/build-tests.sh

tags: src/*.sh
	ctags --language-force=sh src/*.sh src/lib/*.sh tests/unit-tests.sh

# vim:noet:ts=2:sw=2
