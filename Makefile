JEKYLL_ENV ?= production

build:
	JEKYLL_ENV=$(JEKYLL_ENV) bundle exec jekyll build

# Shared with the weekly link-check workflow, which also needs --disable-external
# off and --ignore-status-codes 429 on top -- see link-check below.
PROOFER_FLAGS = --no-enforce-https \
  --swap-urls '^https\://crimsonglow\.ca:' \
  --ignore-urls '/^\/$$/'

# --enforce-https is off: it's a scheme check on link text, not a network
# request, so it fires even under --disable-external. Several posts predate
# HTTPS being universal and link to http:// resources as written; that's a
# content call, not a build break. External reachability (including scheme
# redirects) is covered separately by the weekly link-check workflow.
check: build
	bundle exec htmlproofer ./_site --disable-external $(PROOFER_FLAGS)

# Companion to check: same flags, but external links are live-checked instead
# of skipped, and 429 (rate-limited) responses are ignored rather than failed.
# Used by the weekly link-check workflow; kept separate from check because it
# hits 2004-era posts' external links, which fail intermittently for reasons
# unrelated to this repo and must never block a build.
link-check: build
	bundle exec htmlproofer ./_site $(PROOFER_FLAGS) --ignore-status-codes "429"

deploy: check
	tools/deploy.sh

deploy-dry-run: check
	tools/deploy.sh --dry-run

serve: build
	python3 -m http.server -d _site 8000

og-card:
	tools/og-card.sh

.PHONY: build check link-check deploy deploy-dry-run serve og-card
