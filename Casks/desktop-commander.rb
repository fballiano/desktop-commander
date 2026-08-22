cask "desktop-commander" do
  version "1.1.0"
  sha256 "79615a0697ad4d46d499c8f46fd8fdcb5afdebbebd50b326a2a5725c08934950"

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
