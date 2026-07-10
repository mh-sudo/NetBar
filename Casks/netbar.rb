cask "netbar" do
  version "1.0.0"
  sha256 "a79fa0dda1a8aaee69e929d877dfa4ce6d348f02e6258febb756af0769a8ee88"

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
