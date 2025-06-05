class Mistserver < Formula
  desc "Next-generation streaming media server"
  homepage "https://mistserver.org"
  url "https://github.com/DDVTECH/mistserver/archive/refs/tags/3.6.1.tar.gz"
  version "3.6.1"
  sha256 "e3c330d5bb57c183954ff9c46225c2511f80332b912727ca29963ec3d2055f11"
  license "Unlicense"

  depends_on "meson" => :build
  depends_on "ninja" => :build
  depends_on "pkg-config" => :build

  # Core dependencies
  depends_on "srtp"
  depends_on "srt" => :optional

  def install
    # Create a native file to override problematic dependency detection
    (buildpath/"native_file.ini").write <<~EOS
      [binaries]

      [properties]
      # Force mbedtls to not be found, so fallback subproject is used
      mbedtls = 'false'
      mbedx509 = 'false'
      mbedcrypto = 'false'
    EOS

    mkdir "build" do
      # Allow fallback dependencies since MistServer is designed to use them
      meson_args = std_meson_args.reject { |arg| arg.include?("wrap-mode") }
      meson_args += [
        "--wrap-mode=default",
        "--native-file=../native_file.ini",
        "-DNOUPDATE=true",
        "-DNORIST=true"
      ]

      system "meson", "setup", *meson_args, ".."
      system "ninja"
      system "ninja", "install"
    end

    # Meson installed all Mist*-binaries under bin/
    # Leave them there and make one extra symlink for 'mistserver'.
    # MistController is the main controller binary.
    bin.install_symlink "MistController" => "mistserver"
  end

  service do
    run [opt_bin/"mistserver"]
    keep_alive true
    working_dir var
    log_path var/"log/mistserver.log"
    error_log_path var/"log/mistserver.err.log"
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
