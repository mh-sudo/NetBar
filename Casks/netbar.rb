cask "netbar" do
  version "1.0.2"
  sha256 "03a6002c813464d73196cc3f0b2ff10fd04ba4bd8e82f75f86c0a2195fb7587c"

  url "https://github.com/mh-sudo/NetBar/releases/download/v1.0.2/NetBar-1.0.2.zip"
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
