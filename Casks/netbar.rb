cask "netbar" do
  version "1.0.5"
  sha256 "6dfd68af282a862c854d06b4672cc02bddbd6b88de87134e1eba2e99bfaf1903"

  url "https://github.com/mh-sudo/NetBar/releases/download/v1.0.5/NetBar-1.0.5.zip"
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
