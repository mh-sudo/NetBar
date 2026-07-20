cask "netbar" do
  version "1.2.1"
  sha256 "8e15790adc8ac0a486facff205eeea636c2291d1f9af593d991410973caf2063"

  url "https://github.com/mh-sudo/NetBar/releases/download/v1.2.1/NetBar-1.2.1.zip"
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
