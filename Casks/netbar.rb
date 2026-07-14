cask "netbar" do
  version "1.0.3"
  sha256 "b702172ae36cbe7873cb05e67f03b4f5363f58e699e4c24f94825b6c84de1ef2"

  url "https://github.com/mh-sudo/NetBar/releases/download/v1.0.3/NetBar-1.0.3.zip"
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
