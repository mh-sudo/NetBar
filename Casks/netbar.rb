cask "netbar" do
  version "1.0.0"
  sha256 "85ddf756942d5709b09a638f345cf017042e4f18568bea41fb935be3a15c7d98"

  url "https://github.com/mh-sudo/NetBar/releases/download/v1.0.0/NetBar-1.0.0.zip"
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
