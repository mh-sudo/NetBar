VERSION ?= 1.1.0
APP_NAME = NetBar
GITHUB_USER = mh-sudo
ZIP_NAME = $(APP_NAME)-$(VERSION).zip

.PHONY: build release update-formula

build:
	@bash NetBar/scripts/build_release.sh $(VERSION)

release: build
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
