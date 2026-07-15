class Mistserver < Formula
  desc "Next-generation streaming media server"
  homepage "https://mistserver.org"
  url "https://github.com/DDVTECH/mistserver/archive/refs/tags/3.11.tar.gz"
  version "3.11"
  sha256 "bf982b8f11d8bdec1e543d347db733340d171206c0c86a60775f9021c5ee4ea6"
  license "Unlicense"

  depends_on "meson" => :build
  depends_on "ninja" => :build
  depends_on "pkg-config" => :build
  depends_on "cmake" => :build

  depends_on "srt"
  depends_on "srtp"
  depends_on "ffmpeg"

  def install
    mkdir "build" do
      cmake_formula = Formula["cmake"]
      ENV["CMAKE"] = cmake_formula.opt_bin/"cmake"
      ENV["PATH"] = "#{cmake_formula.opt_bin}:#{ENV["PATH"]}"

      meson_args = std_meson_args.reject { |arg| arg.include?("wrap-mode") }
      meson_args += [
        "--wrap-mode=default",
        "--force-fallback-for=mbedtls,usrsctp",
        "-DVERSION=#{version}",
        "-DNOUPDATE=true",
        "-DNORIST=true",
        "-DWITH_AV=true",
        "-Dmbedtls:default_library=static",
        "-Dusrsctp:default_library=static",
      ]
      system "meson", "setup", *meson_args, ".."
      system "ninja"
      system "meson", "install", "--skip-subprojects"
    end

    # Create a wrapper script instead of a symlink so MistController can find other binaries
    # MistController scans its own directory for Mist* binaries on startup
    (bin/"mistserver").write <<~EOS
      #!/bin/bash
      cd "#{bin}" && exec ./MistController "$@"
    EOS
    chmod 0755, bin/"mistserver"
  end

  service do
    run [opt_bin/"mistserver"]
    keep_alive true
    working_dir var
    log_path var/"log/mistserver/mistserver.log"
    error_log_path var/"log/mistserver/mistserver.err.log"
  end

  def caveats
    <<~EOS
      To start MistServer as a background service and have it restart at login:
        brew services start mistserver

      To run MistServer manually in the foreground:
        mistserver

      The web interface will be available at http://localhost:4242

      For a system tray interface to manage MistServer:
        brew install --cask ddvtech/mistserver/misttray
    EOS
  end

  test do
    # Check that 'mistserver --help' shows the help text (including "MistController")
    assert_match "MistController", shell_output("#{bin}/mistserver --help")
  end
end
