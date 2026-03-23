#!/bin/bash
set -euo pipefail

# Usage: ./release.sh 1.0.1
# Builds, zips, creates GitHub release, updates Homebrew tap

VERSION="${1:?Usage: ./release.sh <version> (e.g. 1.0.1)}"
BIN_NAME="ClaudeMonitor"
APP_NAME="Claude Monitor"
REPO="lvolland/claude-monitor"
TAP_REPO="lvolland/homebrew-tap"
ZIP_NAME="${BIN_NAME}-v${VERSION}-macOS.zip"
BUILD_DIR="build"

echo "==> Building v${VERSION} (release)..."
swift build -c release

echo "==> Creating .app bundle..."
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}/${APP_NAME}.app/Contents/MacOS"
mkdir -p "${BUILD_DIR}/${APP_NAME}.app/Contents/Resources"
cp ".build/release/${BIN_NAME}" "${BUILD_DIR}/${APP_NAME}.app/Contents/MacOS/${BIN_NAME}"
cp "assets/AppIcon.icns" "${BUILD_DIR}/${APP_NAME}.app/Contents/Resources/"

cat > "${BUILD_DIR}/${APP_NAME}.app/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>${BIN_NAME}</string>
    <key>CFBundleIdentifier</key><string>com.lvolland.claude-monitor</string>
    <key>CFBundleName</key><string>Claude Monitor</string>
    <key>CFBundleDisplayName</key><string>Claude Monitor</string>
    <key>CFBundleVersion</key><string>${VERSION}</string>
    <key>CFBundleShortVersionString</key><string>${VERSION}</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSUIElement</key><true/>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>NSAppTransportSecurity</key><dict><key>NSAllowsArbitraryLoads</key><true/></dict>
</dict>
</plist>
PLIST

echo "==> Zipping..."
cd "${BUILD_DIR}"
rm -f "${ZIP_NAME}"
zip -r "${ZIP_NAME}" "Claude Monitor.app"
cd ..

SHA=$(shasum -a 256 "${BUILD_DIR}/${ZIP_NAME}" | awk '{print $1}')
echo "==> SHA256: ${SHA}"

echo "==> Creating GitHub release v${VERSION}..."
gh release create "v${VERSION}" "${BUILD_DIR}/${ZIP_NAME}" \
  --repo "${REPO}" \
  --title "v${VERSION}" \
  --notes "## Claude Monitor v${VERSION}

### Install
\`\`\`bash
brew tap lvolland/tap
brew install --cask claude-monitor
\`\`\`

Or download \`${ZIP_NAME}\`, unzip, move to /Applications, right-click → Open."

echo "==> Updating Homebrew tap..."
TAP_DIR=$(brew --repo "${TAP_REPO}" 2>/dev/null || echo "")

if [ -z "${TAP_DIR}" ] || [ ! -d "${TAP_DIR}" ]; then
  TAP_DIR=$(mktemp -d)
  git clone "git@github.com:${TAP_REPO}.git" "${TAP_DIR}"
  CLONED=1
else
  cd "${TAP_DIR}" && git pull --rebase origin main && cd -
  CLONED=0
fi

CASK_FILE="${TAP_DIR}/Casks/claude-monitor.rb"
cat > "${CASK_FILE}" <<CASK
cask "claude-monitor" do
  version "${VERSION}"
  sha256 "${SHA}"

  url "https://github.com/${REPO}/releases/download/v#{version}/${BIN_NAME}-v#{version}-macOS.zip"
  name "Claude Monitor"
  desc "macOS menu bar app to monitor Claude subscription usage"
  homepage "https://github.com/${REPO}"

  depends_on macos: ">= :ventura"

  app "Claude Monitor.app"

  postflight do
    system_command "/usr/bin/xattr", args: ["-d", "com.apple.quarantine", "#{appdir}/Claude Monitor.app"]
  end

  zap trash: [
    "~/Library/Preferences/com.lvolland.claude-monitor.plist",
  ]
end
CASK

cd "${TAP_DIR}"
git add Casks/claude-monitor.rb
git commit -m "Update claude-monitor to v${VERSION}"
git push origin main
cd -

if [ "${CLONED}" = "1" ]; then
  rm -rf "${TAP_DIR}"
fi

echo ""
echo "==> Done! v${VERSION} released."
echo "    https://github.com/${REPO}/releases/tag/v${VERSION}"
echo "    brew upgrade --cask claude-monitor"
