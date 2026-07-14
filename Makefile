VERSION ?= 1.0.5
APP_NAME = NetBar
GITHUB_USER = mh-sudo
ZIP_NAME = $(APP_NAME)-$(VERSION).zip

.PHONY: build release update-formula check-release

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

release: check-release build
	@echo "🚀 Creating GitHub release v$(VERSION)..."
	gh release create v$(VERSION) $(ZIP_NAME) \
	  --title "$(APP_NAME) v$(VERSION)" \
	  --notes "Release v$(VERSION)"
	@echo "✅ Release published"
	@echo ""
	@echo "⚠️  Now run: make update-formula VERSION=$(VERSION)"

update-formula:
	@echo "📦 Updating Homebrew formula..."
	@SHA256=$$(shasum -a 256 $(ZIP_NAME) | awk '{print $$1}'); \
	sed -i '' "s|url \".*\"|url \"https://github.com/$(GITHUB_USER)/$(APP_NAME)/releases/download/v$(VERSION)/$(ZIP_NAME)\"|" \
	  Casks/netbar.rb; \
	sed -i '' "s|sha256 \".*\"|sha256 \"$$SHA256\"|" \
	  Casks/netbar.rb; \
	sed -i '' "s|version \".*\"|version \"$(VERSION)\"|" \
	  Casks/netbar.rb
	@git add Casks/netbar.rb && \
	  git commit -m "Update NetBar formula to v$(VERSION)" && \
	  git push
	@echo "✅ Formula updated and pushed"
