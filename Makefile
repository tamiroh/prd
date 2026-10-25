KOKA ?= koka
PREFIX ?= /usr/local

.PHONY: all
all: prd

prd: Makefile main.kk period.kk json.kk package-lock.kk license-animation.kk
	$(KOKA) -O2 --output=prd main.kk

.PHONY: install
install: prd
	install -d $(DESTDIR)$(PREFIX)/bin
	install -m 755 prd $(DESTDIR)$(PREFIX)/bin/prd

.PHONY: clean
clean:
	rm -f prd
	rm -rf .koka
