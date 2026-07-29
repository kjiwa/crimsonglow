JEKYLL_ENV ?= production

build:
	JEKYLL_ENV=$(JEKYLL_ENV) bundle exec jekyll build

# --enforce-https is off: it's a scheme check on link text, not a network
# request, so it fires even under --disable-external. Several posts predate
# HTTPS being universal and link to http:// resources as written; that's a
# content call, not a build break. External reachability (including scheme
# redirects) is covered separately by the weekly link-check workflow.
check: build
	bundle exec htmlproofer ./_site \
	  --disable-external \
	  --no-enforce-https \
	  --swap-urls '^https\://crimsonglow\.ca:' \
	  --ignore-urls '/^\/$$/'

deploy: check
	tools/deploy.sh

deploy-dry-run: check
	tools/deploy.sh --dry-run

serve: build
	python3 -m http.server -d _site 8000

og-card:
	tools/og-card.sh

.PHONY: build check deploy deploy-dry-run serve og-card
