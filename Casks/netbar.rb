cask "netbar" do
  version "1.0.4"
  sha256 "08793fdf93a23ee100050f392c5f2847e18f2498f2feab35d9ceea5e133598c7"

  url "https://github.com/mh-sudo/NetBar/releases/download/v1.0.4/NetBar-1.0.4.zip"
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
