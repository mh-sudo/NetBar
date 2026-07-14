cask "netbar" do
  version "1.0.1"
  sha256 "dac4193614728bb1476d1a5a019ab5b813e938076c074769af57c9d640964073"

  url "https://github.com/mh-sudo/NetBar/releases/download/v1.0.1/NetBar-1.0.1.zip"
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
