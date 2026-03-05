cask "misttray" do
  version "0.2.0"
  sha256 "eb7896fdd4822ca07bd614c3086a921b2aba78aa45f87184977451c4bc539186"
  
  url "https://github.com/DDVTECH/MistMacTray/releases/download/v#{version}/MistTray-v#{version}.zip"
  name "MistTray"
  desc "System tray interface for MistServer media streaming platform"
  homepage "https://github.com/DDVTECH/MistMacTray"

  livecheck do
    url :url
    strategy :github_latest
  end

  app "MistTray.app"

  postflight do
    system "open", "#{appdir}/MistTray.app"
  end

  zap trash: [
    "~/Library/Application Support/MistTray",
    "~/Library/Preferences/com.ddvtech.MistTray.plist",
    "~/Library/Caches/com.ddvtech.MistTray",
    "~/Library/Logs/MistTray",
  ]

  # Post-install message
  caveats do
    <<~EOS
      MistTray requires MistServer to be installed and running.
      
      If you haven't installed MistServer yet, it's in the same tap:
        brew install ddvtech/mistserver
      
      To start MistServer:
        brew services start mistserver
      
      MistTray will appear in your menu bar and provide a GUI interface
      for managing your MistServer instance.
    EOS
  end
end 