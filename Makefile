SHELL := /bin/bash
VERSION := $(shell tr -d '[:space:]' < VERSION)
ISO := dist/2d-os-$(VERSION)-amd64.iso

.PHONY: help build iso assets vm flash persistence clean version

help:
	@echo "2D OS - comandi disponibili"
	@echo
	@echo "  make build        costruisce la ISO in un container Docker"
	@echo "  make assets       rigenera gli asset grafici del tema di avvio"
	@echo "  make vm           avvia la ISO in QEMU per i test"
	@echo "  make flash        scrive la ISO su una chiavetta USB (DEST=/dev/sdX)"
	@echo "  make persistence  prepara la partizione persistente sulla chiavetta"
	@echo "  make clean        rimuove gli artefatti di build"
	@echo "  make version      mostra la versione corrente ($(VERSION))"
	@echo

build:
	./scripts/build.sh

iso: build

assets:
	python3 brand/generate-plymouth-assets.py
	python3 brand/generate-sounds.py

vm:
	./scripts/test-vm.sh "$(ISO)"

flash:
	@test -n "$(DEST)" || { echo "Uso: make flash DEST=/dev/sdX"; exit 1; }
	@test -f "$(ISO)" || { echo "ISO assente: esegui prima 'make build'"; exit 1; }
	./scripts/flash-usb.sh "$(ISO)" "$(DEST)"

persistence:
	@test -n "$(DEST)" || { echo "Uso: make persistence DEST=/dev/sdX"; exit 1; }
	./scripts/setup-persistence.sh "$(DEST)"

clean:
	./scripts/clean.sh

version:
	@echo $(VERSION)
