cask "netbar" do
  version "1.0.1"
  sha256 "825a10097ca92d7c1f253f326e5804e4c1d484d6f2523efe2da3b1dadbcefcbc"

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
