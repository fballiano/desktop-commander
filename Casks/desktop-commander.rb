cask "desktop-commander" do
  version "1.0.0"
  sha256 "0000000000000000000000000000000000000000000000000000000000000000"

  url "https://github.com/fballiano/desktop-commander/releases/download/v#{version}/desktop-commander-#{version}.dmg"
  name "desktop-commander"
  desc "Menu bar switches for macOS and window management"
  homepage "https://github.com/fballiano/desktop-commander"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on macos: :sequoia

  app "desktop-commander.app"

  zap trash: [
    "~/Library/Application Support/desktop-commander",
    "~/Library/Caches/com.fabrizioballiano.desktop-commander",
    "~/Library/HTTPStorages/com.fabrizioballiano.desktop-commander",
    "~/Library/Preferences/com.fabrizioballiano.desktop-commander.plist",
  ]
end
