# Local dev in one command: server + Claude Code + browser, with live reload.
# macOS only. Assumes a bare machine with just `make` and `brew` -- everything
# else is installed on first run. Just: make
#
#   left pane  -> browser-sync (serves the site, live-reloads, opens browser)
#   right pane -> claude
#
# `make shot` screenshots the running site to a PNG so Claude can look at it.
# `make help` lists every target with a one-line description.

SESSION := emilyaudio
CHROME  := /Applications/Google Chrome.app/Contents/MacOS/Google Chrome
URL     ?= http://localhost:3000/
SHOT    ?= /tmp/emilyaudio-shot.png
SIZE    ?= 1280,900

# Accessibility audits (pa11y / axe / lighthouse) run against a served copy of
# the site. SITE_URL has NO trailing slash; PAGES carry their own slashes.
# Default target is the browser-sync dev server (`make` in another pane). To
# audit the deployed site instead, no local server needed:
#   make a11y SITE_URL=https://emilyaudio.com
SITE_URL ?= http://localhost:3000
PAGES    := / /vo/ /audio/

# Bare `make` launches the dev session (all); `make help` lists every target.
.DEFAULT_GOAL := all

.PHONY: help
help: ## List every target with a one-line description
	@awk 'BEGIN {FS = ":.*##"} /^[a-zA-Z0-9_-]+:.*##/ { printf "  %-15s %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

.PHONY: all
all: deps ## Start (or attach to) the tmux dev session: browser-sync + claude
	@if tmux has-session -t $(SESSION) 2>/dev/null; then \
		echo "Session '$(SESSION)' already running -- attaching."; \
	else \
		tmux new-session -d -s $(SESSION) -c "$(CURDIR)" 'npx browser-sync start --server --no-notify --files "**/*.html,**/*.css,**/*.js"; exec $$SHELL'; \
		tmux split-window -h -t $(SESSION) -c "$(CURDIR)" 'exec claude'; \
	fi
	@if [ -n "$$TMUX" ]; then tmux switch-client -t $(SESSION); else tmux attach -t $(SESSION); fi

# Provision from a bare system. brew installs tmux/node/chrome; claude uses
# Anthropic's recommended native installer (self-contained, auto-updating --
# https://code.claude.com/docs/en/setup); node brings npm/npx for browser-sync.
# Each check is a no-op once satisfied, so re-running is cheap.
.PHONY: deps
deps: ## Install dev prerequisites (tmux, node, chrome, claude) if missing
	@command -v brew >/dev/null || { echo "Install Homebrew first: https://brew.sh"; exit 1; }
	@command -v tmux >/dev/null || brew install tmux
	@command -v node >/dev/null || brew install node
	@[ -e "$(CHROME)" ] || brew install --cask google-chrome
	@command -v claude >/dev/null || curl -fsSL https://claude.ai/install.sh | bash

# Screenshot the running site to $(SHOT) so Claude can Read it. Scrollbars are
# left visible on purpose -- a stray scrollbar is a real layout bug worth seeing.
# Override the page:  make shot URL=http://localhost:3000/vo/
# Override the viewport:  make shot SIZE=1440,900
# NOTE: headless Chrome on macOS floors the layout viewport at ~485px wide, so
# SIZE widths below that render a ~485px page clipped to the canvas (not a true
# phone). 485 still stacks to the single-column mobile layout, so it validates
# reflow; pixel-true <390px emulation would need CDP device-metrics (not worth
# it here). Real phones are fine -- verify narrow layouts at SIZE=500,900.
.PHONY: shot
shot: ## Screenshot the running site to $(SHOT) (override URL=, SIZE=)
	@"$(CHROME)" --headless=new --disable-gpu \
		--force-device-scale-factor=1 --window-size=$(SIZE) \
		--screenshot="$(SHOT)" "$(URL)" >/dev/null 2>&1 && echo "wrote $(SHOT)"

.PHONY: stop
stop: ## Tear down the dev session
	@tmux kill-session -t $(SESSION) 2>/dev/null && echo "Stopped." || echo "Not running."

# --- Accessibility tooling -------------------------------------------------
# Dev-only. The site has no build step; these targets install npm devDeps
# (pa11y, axe-core, lighthouse, puppeteer) on first run and audit a served copy
# of the site against WCAG 2.2 AA. Bootstraps from a bare machine: only brew
# (on macOS) is assumed -- Node is installed if missing. A system Chrome or
# Chromium is used when present; otherwise puppeteer downloads its own into
# .cache (this also works on Linux where Node is already present). Everything
# installed here (node_modules/, .cache/, reports/) is gitignored.

# Prefer a system Chrome/Chromium; fall back to puppeteer's downloaded copy.
# Node's newest releases break puppeteer's own Chrome unzip, so a system browser
# is the reliable path -- the download stays as a fallback for machines without
# one. Override with `make a11y CHROME_BIN=/path/to/chrome`.
CHROME_BIN := $(shell for b in google-chrome google-chrome-stable chromium chromium-browser; do command -v $$b 2>/dev/null && break; done)

# Resolve the browser once and export it for pa11y (via puppeteer) and
# lighthouse (via chrome-launcher). PUPPETEER_EXECUTABLE_PATH makes pa11y's
# bundled puppeteer launch the chosen binary instead of its own download.
BROWSER_ENV = browser="$(CHROME_BIN)"; [ -n "$$browser" ] || browser=$$(node scripts/chrome-path.cjs); export CHROME_PATH="$$browser" PUPPETEER_EXECUTABLE_PATH="$$browser";

# Ensure Node (brings npm/npx) is available; install via brew on macOS if
# missing. Order-only prerequisite of node_modules so it can't force a reinstall.
.PHONY: ensure-node
ensure-node:
	@command -v npm >/dev/null || { \
	    command -v brew >/dev/null || { echo "Install Homebrew first: https://brew.sh" >&2; exit 1; }; \
	    brew install node; \
	}

node_modules: package.json | ensure-node
	npm install
	@touch node_modules

# Ensure a Chrome/Chromium binary is available. Prefer a system install; only
# when none is found do we fall back to puppeteer's download into .cache.
.PHONY: chrome
chrome: node_modules ## Ensure a Chrome/Chromium is available (system, else puppeteer)
	@if [ -n "$(CHROME_BIN)" ]; then \
	    echo "Using system Chrome: $(CHROME_BIN)"; \
	else \
	    node scripts/chrome-path.cjs > /dev/null 2>&1 || npx puppeteer browsers install chrome; \
	fi

.PHONY: check-server
check-server: ## Verify a server is answering at $(SITE_URL)
	@curl --silent --fail $(SITE_URL)/ > /dev/null 2>&1 || ( \
	    echo "Error: no server at $(SITE_URL). Run 'make' in another shell (browser-sync)," >&2; \
	    echo "       or audit the live site: make a11y SITE_URL=https://emilyaudio.com" >&2; \
	    exit 1; \
	)

.PHONY: pa11y
pa11y: chrome check-server ## pa11y HTMLCS WCAG2AA checks, printed to the terminal
	@$(BROWSER_ENV) \
	for page in $(PAGES); do \
	    npx pa11y --standard WCAG2AA $(SITE_URL)$$page; \
	done

.PHONY: pa11y-json
pa11y-json: chrome check-server ## pa11y HTMLCS checks, write JSON to reports/
	mkdir -p reports
	rm -f reports/pa11y-*.json
	@$(BROWSER_ENV) \
	for page in $(PAGES); do \
	    slug=$$(echo "$$page" | tr -d '/'); slug=$${slug:-index}; \
	    npx pa11y --reporter json --standard WCAG2AA $(SITE_URL)$$page > reports/pa11y-$$slug.json; \
	done

.PHONY: axe
axe: chrome check-server ## axe-core WCAG2AA checks (catches a partly different set)
	@$(BROWSER_ENV) \
	for page in $(PAGES); do \
	    npx pa11y --runner axe --standard WCAG2AA $(SITE_URL)$$page; \
	done

.PHONY: axe-json
axe-json: chrome check-server ## axe-core checks, write JSON to reports/
	mkdir -p reports
	rm -f reports/axe-*.json
	@$(BROWSER_ENV) \
	for page in $(PAGES); do \
	    slug=$$(echo "$$page" | tr -d '/'); slug=$${slug:-index}; \
	    npx pa11y --runner axe --reporter json --standard WCAG2AA $(SITE_URL)$$page > reports/axe-$$slug.json; \
	done

.PHONY: lighthouse
lighthouse: chrome check-server ## Full lighthouse audits, HTML reports opened in the browser
	mkdir -p reports
	rm -f reports/*.html
	@$(BROWSER_ENV) \
	for page in $(PAGES); do \
	    slug=$$(echo "$$page" | tr -d '/'); slug=$${slug:-index}; \
	    npx lighthouse $(SITE_URL)$$page --output html --output-path reports/$$slug.html --view; \
	done

.PHONY: lighthouse-json
lighthouse-json: chrome check-server ## Full lighthouse audits, write JSON to reports/
	mkdir -p reports
	rm -f reports/lighthouse-*.json
	@$(BROWSER_ENV) \
	for page in $(PAGES); do \
	    slug=$$(echo "$$page" | tr -d '/'); slug=$${slug:-index}; \
	    npx lighthouse $(SITE_URL)$$page --output json --output-path reports/lighthouse-$$slug.json; \
	done

# Run every audit; don't stop at the first tool that reports findings -- an audit
# finding issues has done its job, not failed. Each sub-audit still exits
# non-zero on findings (useful alone / in CI), so we run them independently and
# fail at the end if any did: you see all three, and the signal survives. A
# missing server still fails fast (check-server), since that is a real error.
.PHONY: a11y
a11y: check-server ## Run every audit (terminal); report all, fail if any had findings
	@rc=0; \
	for t in pa11y axe lighthouse; do \
	    $(MAKE) --no-print-directory $$t || rc=1; \
	done; \
	exit $$rc

.PHONY: a11y-json
a11y-json: check-server ## Run every audit, write JSON to reports/; fail if any had findings
	@rc=0; \
	for t in pa11y-json axe-json lighthouse-json; do \
	    $(MAKE) --no-print-directory $$t || rc=1; \
	done; \
	exit $$rc
