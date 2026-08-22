cask "desktop-commander" do
  version "1.2.0"
  sha256 "c27a9dd5f2353c97d5414888f49155aa20cdc0960c3456edcdfa95606feb951b"

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
