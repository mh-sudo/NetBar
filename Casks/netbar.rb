cask "netbar" do
  version "1.1"
  sha256 "737c9b0ed5eaf3097bc86474de8b286d16c9320086f7baa3f3c29fded4968833"

  url "https://github.com/mh-sudo/NetBar/releases/download/v1.1/NetBar-1.1.zip"
  name "NetBar"
  desc "Minimalist menubar app showing network speed and IP country flag"
  homepage "https://github.com/mh-sudo/NetBar"

  app "NetBar.app"

  # Strip quarantine flag so Gatekeeper doesn't block ad-hoc signed app
  postflight do
    system_command "/usr/bin/xattr",
      args: ["-cr", "#{appdir}/NetBar.app"],
      sudo: false
  end

  zap trash: [
    "~/Library/Preferences/com.netbar.app.plist",
    "~/Library/Application Support/NetBar",
    "~/Library/Caches/com.netbar.app",
  ]
end
