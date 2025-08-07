class Mistserver < Formula
  desc "Next-generation streaming media server"
  homepage "https://mistserver.org"
  url "https://github.com/DDVTECH/mistserver/archive/refs/tags/3.8.tar.gz"
  version "3.8"
  sha256 "11fdb2a810fe20b0292fde1569382a54ccce054077b5dd9efb2b71eae88ddcaf"
  license "Unlicense"

  depends_on "meson" => :build
  depends_on "ninja" => :build
  depends_on "pkg-config" => :build
  depends_on "cmake" => :build

  # Core dependencies - same approach as ffmpeg
  depends_on "srt"
  depends_on "srtp"
  depends_on "mbedtls"
  depends_on "libusrsctp"

  def install
    mkdir "build" do
      # Fix Homebrew's broken build environment
      cmake_formula = Formula["cmake"]
      ENV["CMAKE"] = cmake_formula.opt_bin/"cmake"
      ENV["PATH"] = "#{cmake_formula.opt_bin}:#{ENV["PATH"]}"

      # Use standard Homebrew meson args - all dependencies from system packages
      system "meson", "setup", *std_meson_args, "-DNOUPDATE=true", "-DNORIST=true", ".."
      system "ninja"
      system "ninja", "install"
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
    EOS
  end

  test do
    # Check that 'mistserver --help' shows the help text (including "MistController")
    assert_match "MistController", shell_output("#{bin}/mistserver --help")
  end
end
