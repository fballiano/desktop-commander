cask "desktop-commander" do
  version "1.3.1"
  sha256 "a10fe0b902c5234936b104c34bbff4cf4dda4f7f64077bf9c3bc1835b633fd0f"

  url "https://github.com/fballiano/desktop-commander/releases/download/v#{version}/desktop-commander-#{version}.dmg"
  name "desktop-commander"
  desc "Menu bar switches for macOS and window management"
  homepage "https://github.com/fballiano/desktop-commander"

  livecheck do
    url :url
    strategy :github_latest
  end

  deprecate! date: "2026-11-08", because: "has moved to fballiano/tap/deskyard"

  depends_on macos: :sequoia

  app "desktop-commander.app"

  zap trash: [
    "~/Library/Application Support/desktop-commander",
    "~/Library/Caches/com.fabrizioballiano.desktop-commander",
    "~/Library/HTTPStorages/com.fabrizioballiano.desktop-commander",
    "~/Library/Preferences/com.fabrizioballiano.desktop-commander.plist",
  ]
end
