# teil.ing-client Makefile
#
# Usage:
#   make build              — Debug build
#   make build-release      — Release build
#   make test               — Run unit tests
#   make dmg                — Build unsigned DMG locally (fast)
#   make dmg-signed         — Build signed DMG locally
#   make dmg-release        — Build signed + notarized DMG
#   make release V=1.0.5    — Bump, build, commit, tag, create GH release, push
#   make clean              — Remove build artifacts

PROJECT  := teil.ing-client.xcodeproj
SCHEME   := teil.ing-client
VERSION  := $(shell sed -n 's/.*MARKETING_VERSION: *"\(.*\)"/\1/p' project.yml | head -1)
BUILD    := $(shell sed -n 's/.*CURRENT_PROJECT_VERSION: *"\(.*\)"/\1/p' project.yml | head -1)

.PHONY: build build-release test xcodegen dmg dmg-signed dmg-release bump release push clean

build: xcodegen
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration Debug build

build-release: xcodegen
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration Release -quiet build

test: xcodegen
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) test

xcodegen:
	xcodegen generate

dmg:
	CODE_SIGN_IDENTITY=- ./build-dmg.sh $(VERSION)

dmg-signed:
	./build-dmg.sh $(VERSION)

dmg-release:
	NOTARIZE=1 ./build-dmg.sh $(VERSION)

clean:
	rm -rf build/
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) clean 2>/dev/null || true

# Bump version in project.yml and regenerate Xcode project
# Usage: make bump V=1.0.5
bump:
	@test -n "$(V)" || { echo "Usage: make bump V=x.y.z"; exit 1; }
	@NEW_BUILD=$$(( $(BUILD) + 1 )); \
	sed -i '' 's/MARKETING_VERSION: ".*"/MARKETING_VERSION: "$(V)"/' project.yml; \
	sed -i '' "s/CURRENT_PROJECT_VERSION: \".*\"/CURRENT_PROJECT_VERSION: \"$$NEW_BUILD\"/" project.yml; \
	echo "Bumped to v$(V) (build $$NEW_BUILD)"
	xcodegen generate

# Full release pipeline: bump → build → commit → tag → GH release → push
# Usage: make release V=1.0.5
release:
	@test -n "$(V)" || { echo "Usage: make release V=x.y.z"; exit 1; }
	@echo "==> Bumping to v$(V)..."
	$(MAKE) bump V=$(V)
	@echo "==> Building release..."
	$(MAKE) build-release
	@echo "==> Committing..."
	git add project.yml $(PROJECT)
	git commit -m "Bump version to v$(V)"
	@echo "==> Tagging v$(V)..."
	git tag -a "v$(V)" -m "v$(V)"
	@echo "==> Pushing..."
	git push && git push --tags
	@echo "==> Creating draft GitHub release (CI publishes it after attaching the DMG)..."
	gh release create "v$(V)" --title "v$(V)" --generate-notes --draft
	@echo "==> Released v$(V) — CI will build and upload DMG"
