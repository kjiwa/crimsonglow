JEKYLL_ENV ?= production
SITE = site

build:
	cd $(SITE) && JEKYLL_ENV=$(JEKYLL_ENV) bundle exec jekyll build

# Shared with the weekly link-check workflow, which also needs --disable-external
# off and --ignore-status-codes 429,999 on top -- see link-check below.
PROOFER_FLAGS = --no-enforce-https \
  --swap-urls '^https\://crimsonglow\.ca:' \
  --ignore-urls '/^\/$$/'

# --enforce-https is off: it's a scheme check on link text, not a network
# request, so it fires even under --disable-external. Several posts predate
# HTTPS being universal and link to http:// resources as written; that's a
# content call, not a build break. External reachability (including scheme
# redirects) is covered separately by the weekly link-check workflow.
check: build
	scripts/check-redirects.sh
	cd $(SITE) && bundle exec htmlproofer ./_site --disable-external $(PROOFER_FLAGS)

check-live:
	scripts/check-headers.sh
	scripts/check-routes.sh
	scripts/check-mail.sh

# Companion to check: same flags, but external links are live-checked instead
# of skipped, and 429 (rate-limited) / 999 (LinkedIn's anti-bot response, not
# real rot) are ignored rather than failed. Used by the weekly link-check
# workflow; kept separate from check because it hits 2004-era posts' external
# links, which fail intermittently for reasons unrelated to this repo and must
# never block a build.
link-check: build
	cd $(SITE) && bundle exec htmlproofer ./_site $(PROOFER_FLAGS) --ignore-status-codes "429,999"

lint:
	shellcheck -x -P SCRIPTDIR scripts/*.sh webmail/*.sh

webmail:
	scripts/webmail-build.sh

serve: build
	python3 -m http.server -d $(SITE)/_site 8000

og-card:
	scripts/og-card.sh

.PHONY: build check check-live link-check lint serve og-card webmail
