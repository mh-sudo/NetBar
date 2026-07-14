cask "netbar" do
  version "1.2"
  sha256 "87a15bce863d44da1bda6a33354430bb90c40ff67e968e328f21bd8d91313688"

  url "https://github.com/mh-sudo/NetBar/releases/download/v1.2/NetBar-1.2.zip"
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
