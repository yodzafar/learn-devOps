# dev-ops — o'quv loyihasi Makefile
#
# Umumiy:
#   make help                                  barcha buyruqlar
#   make list                                  modullar va yozilgan darslar ro'yxati
#   make lesson m=linux n=03                   darsni terminalda o'qish (linux/docs/03-*.md)
#
# Yangi ish papkasi (ichida README.md shabloni bilan):
#   make new m=linux n=03 name=basic-commands  -> linux/03-basic-commands/
#
# Modullar (m=): linux git network docker cloud cicd iac observability kubernetes
#
# Sifat (topshirishdan oldin):
#   make check                                 quyidagilarning hammasi
#   make lint-sh                               shellcheck: barcha *.sh
#   make lint-yaml                             yamllint: barcha *.yaml / *.yml
#   make lint-docker                           hadolint: barcha Dockerfile
#   make lint-tf                               terraform fmt -check (tofu bo'lsa TF=tofu)
#   make secrets                               commit qilinmasligi kerak bo'lgan fayllarni qidirish
#
# Asbob o'rnatilmagan bo'lsa tegishli tekshiruv "o'tkazib yuborildi" deb chiqadi.
# O'rnatish: sudo apt install shellcheck yamllint; hadolint: https://github.com/hadolint/hadolint

.DEFAULT_GOAL := help
SHELL := /bin/bash

MODULES := linux git network docker cloud cicd iac observability kubernetes
TF ?= terraform

# ish papkalaridagi fayllar (docs/ va yashirin papkalar kirmaydi)
FIND_WORK = find $(MODULES) -path '*/docs' -prune -o -path '*/.terraform' -prune -o -path '*/node_modules' -prune -o -type f

# ---- umumiy ----
.PHONY: help
help:
	@sed -n '2,22p' $(MAKEFILE_LIST) | sed 's/^# \{0,1\}//'

.PHONY: list
list:
	@for m in $(MODULES); do \
		echo "$$m:"; \
		ls $$m/docs 2>/dev/null | grep -E '^[0-9]{2}-' | sed 's/^/  /'; \
	done

.PHONY: lesson
lesson:
	@test -n "$(m)" -a -n "$(n)" || (echo "m=<modul> n=<raqam> bering, masalan: make lesson m=linux n=03"; exit 1)
	@f=$$(ls $(m)/docs/$(n)-*.md 2>/dev/null | head -1); \
	test -n "$$f" || (echo "Dars topilmadi: $(m)/docs/$(n)-*.md"; exit 1); \
	$${PAGER:-less} "$$f"

# ---- yangi ish papkasi ----
.PHONY: new
new:
	@test -n "$(m)" -a -n "$(n)" -a -n "$(name)" || (echo "m=<modul> n=<raqam> name=<nom> bering, masalan: make new m=linux n=03 name=basic-commands"; exit 1)
	@echo " $(MODULES) " | grep -q " $(m) " || (echo "Noma'lum modul: $(m). Modullar: $(MODULES)"; exit 1)
	@test ! -e "$(m)/$(n)-$(name)" || (echo "Mavjud: $(m)/$(n)-$(name)"; exit 1)
	@mkdir -p "$(m)/$(n)-$(name)"
	@printf '# %s/%s-%s\n\nDars: `%s/docs/%s-%s.md`\n\nHar vazifa uchun: buyruqlar, natijaning muhim qismi, o'"'"'z so'"'"'zingiz bilan izoh.\n\n## 1. Title\n\n' \
		"$(m)" "$(n)" "$(name)" "$(m)" "$(n)" "$(name)" > "$(m)/$(n)-$(name)/README.md"
	@echo "Yaratildi: $(m)/$(n)-$(name)/README.md"

# ---- sifat ----
.PHONY: check
check: lint-sh lint-yaml lint-docker lint-tf secrets
	@echo "check tugadi"

.PHONY: lint-sh
lint-sh:
	@if ! command -v shellcheck >/dev/null; then echo "shellcheck yo'q, o'tkazib yuborildi"; exit 0; fi; \
	files=$$($(FIND_WORK) -name '*.sh' -print); \
	if [ -z "$$files" ]; then echo "lint-sh: *.sh fayl yo'q"; else shellcheck $$files && echo "lint-sh: toza"; fi

.PHONY: lint-yaml
lint-yaml:
	@if ! command -v yamllint >/dev/null; then echo "yamllint yo'q, o'tkazib yuborildi"; exit 0; fi; \
	files=$$($(FIND_WORK) \( -name '*.yaml' -o -name '*.yml' \) -not -path '*/templates/*' -print); \
	if [ -z "$$files" ]; then echo "lint-yaml: YAML fayl yo'q"; else yamllint -d '{extends: relaxed, rules: {line-length: disable}}' $$files && echo "lint-yaml: toza"; fi

.PHONY: lint-docker
lint-docker:
	@if ! command -v hadolint >/dev/null; then echo "hadolint yo'q, o'tkazib yuborildi"; exit 0; fi; \
	files=$$($(FIND_WORK) \( -name 'Dockerfile' -o -name 'Dockerfile.*' -o -name '*.Dockerfile' \) -print); \
	if [ -z "$$files" ]; then echo "lint-docker: Dockerfile yo'q"; else hadolint $$files && echo "lint-docker: toza"; fi

.PHONY: lint-tf
lint-tf:
	@if ! command -v $(TF) >/dev/null; then echo "$(TF) yo'q, o'tkazib yuborildi"; exit 0; fi; \
	if [ -z "$$($(FIND_WORK) -name '*.tf' -print -quit)" ]; then echo "lint-tf: *.tf fayl yo'q"; else $(TF) fmt -check -recursive . && echo "lint-tf: toza"; fi

.PHONY: secrets
secrets:
	@bad=$$(git ls-files | grep -E '(^|/)(\.env|.*\.pem|.*\.key|id_rsa|id_ed25519|kubeconfig|.*\.tfstate|.*\.tfstate\.backup|.*\.tfvars|credentials)$$' || true); \
	if [ -n "$$bad" ]; then echo "Git'da bo'lmasligi kerak bo'lgan fayllar:"; echo "$$bad"; exit 1; else echo "secrets: toza"; fi
