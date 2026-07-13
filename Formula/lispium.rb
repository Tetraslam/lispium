class Lispium < Formula
  desc "Symbolic Computer Algebra System written in Zig"
  homepage "https://github.com/Tetraslam/lispium"
  version "0.9.0"
  license "MIT"

  on_macos do
    on_arm do
      url "https://github.com/Tetraslam/lispium/releases/download/v0.9.0/lispium-macos-aarch64.tar.gz"
      sha256 "52f1017fa2794db0c780ef04aeef58f43e4cccd887797e473097391e6de2128d"
    end
    on_intel do
      url "https://github.com/Tetraslam/lispium/releases/download/v0.9.0/lispium-macos-x86_64.tar.gz"
      sha256 "c9c5fc0d74345a08eb3ddb9335782d1b271045db2736b5c8a4318b45bf8f4dd9"
    end
  end

  on_linux do
    on_arm do
      url "https://github.com/Tetraslam/lispium/releases/download/v0.9.0/lispium-linux-aarch64.tar.gz"
      sha256 "fd44654770411d7f8fd5bb81b0f814bb55cb73c115b18ba4af8e40885ee27582"
    end
    on_intel do
      url "https://github.com/Tetraslam/lispium/releases/download/v0.9.0/lispium-linux-x86_64.tar.gz"
      sha256 "5d71d55bcaf9997cb80517219d6690b3127cbc9c10153a4367107b7596a91fcf"
    end
  end

  def install
    bin.install "lispium"
  end

  test do
    assert_match "6", shell_output("#{bin}/lispium eval \"(+ 1 2 3)\"").strip
  end
end
