class Lispium < Formula
  desc "Symbolic Computer Algebra System written in Zig"
  homepage "https://github.com/Tetraslam/lispium"
  version "0.6.1"
  license "MIT"

  on_macos do
    on_arm do
      url "https://github.com/Tetraslam/lispium/releases/download/v0.6.1/lispium-macos-aarch64.tar.gz"
      sha256 "8aea8145f154e7eb209ed992c54c6f360574b9a40269ebb6489b476a3a2faf13"
    end
    on_intel do
      url "https://github.com/Tetraslam/lispium/releases/download/v0.6.1/lispium-macos-x86_64.tar.gz"
      sha256 "7a298a65f920e874e29ab0255bbf74c25f5e9122781708cbab352ed258370983"
    end
  end

  on_linux do
    on_arm do
      url "https://github.com/Tetraslam/lispium/releases/download/v0.6.1/lispium-linux-aarch64.tar.gz"
      sha256 "e038da3b4aed1c802773ba5c16627b05cad2ed2d9421c92926f973077769135c"
    end
    on_intel do
      url "https://github.com/Tetraslam/lispium/releases/download/v0.6.1/lispium-linux-x86_64.tar.gz"
      sha256 "95e8f2279ef9b26113b7a0da197d938693d7b89ddc11fc68161ba7600e1117d6"
    end
  end

  def install
    bin.install "lispium"
  end

  test do
    assert_match "6", shell_output("#{bin}/lispium eval \"(+ 1 2 3)\"").strip
  end
end
