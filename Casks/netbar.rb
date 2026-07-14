cask "netbar" do
  version "1.0.2"
  sha256 "0f184cc8bd7e8434594e9a926222797546dae22c8a08b8886049780533a0669d"

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
