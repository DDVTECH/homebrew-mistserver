class Mistserver < Formula
  desc "Next-generation streaming media server"
  homepage "https://mistserver.org"
  url "https://github.com/DDVTECH/mistserver/archive/refs/tags/3.9.2.tar.gz"
  version "3.9.2"
  sha256 "3c6ac63efa4415dd3fb0f3d538cc4f7a18c03d8b88d09afed17e1910dfafa66c"
  license "Unlicense"

  depends_on "meson" => :build
  depends_on "ninja" => :build
  depends_on "pkg-config" => :build
  depends_on "cmake" => :build

  depends_on "srt"
  depends_on "srtp"
  depends_on "libusrsctp"
  depends_on "ffmpeg"

  def install
    mkdir "build" do
      # Fix Homebrew's broken build environment
      cmake_formula = Formula["cmake"]
      ENV["CMAKE"] = cmake_formula.opt_bin/"cmake"
      ENV["PATH"] = "#{cmake_formula.opt_bin}:#{ENV["PATH"]}"

      # Allow meson to use subproject fallbacks (bundled mbedtls 3.6.x instead of Homebrew's incompatible 4.0)
      meson_args = std_meson_args.reject { |arg| arg.include?("wrap-mode") }
      meson_args += [
        "--wrap-mode=default",
        "-DNOUPDATE=true",
        "-DNORIST=true",
        "-DWITH_AV=true",
        "-Dmbedtls:default_library=static",
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
    EOS
  end

  test do
    # Check that 'mistserver --help' shows the help text (including "MistController")
    assert_match "MistController", shell_output("#{bin}/mistserver --help")
  end
end
