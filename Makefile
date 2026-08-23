VERSION ?= 1.2.1

.PHONY: build check-release

build:
	@bash NetBar/scripts/build_release.sh $(VERSION)

check-release:
	@echo "🔍 Checking release preconditions..."
	@if ! git diff-index --quiet HEAD --; then \
	  echo "❌ Error: You have uncommitted changes. Please commit and push them first."; \
	  exit 1; \
	fi
	@git fetch origin main >/dev/null 2>&1
	@LOCAL=$$(git rev-parse HEAD); \
	REMOTE=$$(git rev-parse origin/main); \
	if [ "$$LOCAL" != "$$REMOTE" ]; then \
	  echo "❌ Error: Local branch is not in sync with origin/main. Please push your changes first."; \
	  exit 1; \
	fi
	@PLIST_VERSION=$$(grep -A1 "CFBundleShortVersionString" NetBar/NetBar/Info.plist | tail -n1 | sed -e 's/^[[:space:]]*//' -e 's/<string>//' -e 's/<\/string>//'); \
	if [ "$$PLIST_VERSION" != "$(VERSION)" ]; then \
	  echo "❌ Error: Info.plist version ($$PLIST_VERSION) does not match Makefile VERSION ($(VERSION))."; \
	  exit 1; \
	fi
	@echo "✅ Preconditions satisfied!"

# Release publishing and formula updates are owned by
# .github/workflows/release.yml (triggered by the v* tag push).
# Do NOT add local release/formula targets here — a local zip differs from the
# CI-built zip (timestamps → different SHA256) and would break the cask checksum.
