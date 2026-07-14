cask "netbar" do
  version "1.0.5"
  sha256 "9b2ebb07decb64c31e841c1e47a29d9fb352c78aab7b7ba586d4c1072bf6210f"

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
