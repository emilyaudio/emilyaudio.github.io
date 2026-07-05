# Local dev in one command: server + Claude Code + browser, with live reload.
# macOS only. Assumes a bare machine with just `make` and `brew` -- everything
# else is installed on first run. Just: make
#
#   left pane  -> browser-sync (serves the site, live-reloads, opens browser)
#   right pane -> claude
#
# `make shot` screenshots the running site to a PNG so Claude can look at it.

SESSION := emilyaudio
CHROME  := /Applications/Google Chrome.app/Contents/MacOS/Google Chrome
URL     ?= http://localhost:3000/
SHOT    ?= /tmp/emilyaudio-shot.png
SIZE    ?= 1280,900

.PHONY: all deps stop shot

all: deps
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
deps:
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
shot:
	@"$(CHROME)" --headless=new --disable-gpu \
		--force-device-scale-factor=1 --window-size=$(SIZE) \
		--screenshot="$(SHOT)" "$(URL)" >/dev/null 2>&1 && echo "wrote $(SHOT)"

# Tear down the dev session.
stop:
	@tmux kill-session -t $(SESSION) 2>/dev/null && echo "Stopped." || echo "Not running."
