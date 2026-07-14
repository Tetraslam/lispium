class Lispium < Formula
  desc "Symbolic Computer Algebra System written in Zig"
  homepage "https://github.com/Tetraslam/lispium"
  version "0.16.0"
  license "MIT"

  on_macos do
    on_arm do
      url "https://github.com/Tetraslam/lispium/releases/download/v0.16.0/lispium-macos-aarch64.tar.gz"
      sha256 "b61825bc3b92cfe5a9bc0daaccd32caed85da262462c4d896467081172df1dbc"
    end
    on_intel do
      url "https://github.com/Tetraslam/lispium/releases/download/v0.16.0/lispium-macos-x86_64.tar.gz"
      sha256 "ca9c2cee6bb05011891e4b127f12d0bd2b8f6c05e04431e20a871b59ba8978e7"
    end
  end

  on_linux do
    on_arm do
      url "https://github.com/Tetraslam/lispium/releases/download/v0.16.0/lispium-linux-aarch64.tar.gz"
      sha256 "5f55c2488dd51cf31d5a325beb233af11692d6829de32362fc414a6d670c1d30"
    end
    on_intel do
      url "https://github.com/Tetraslam/lispium/releases/download/v0.16.0/lispium-linux-x86_64.tar.gz"
      sha256 "e277d9813df842e236cc46dcad66cf9f984f1e6a3a5fa457441439c9f2ea61c2"
    end
  end

  def install
    bin.install "lispium"
  end

  test do
    assert_match "6", shell_output("#{bin}/lispium eval \"(+ 1 2 3)\"").strip
  end
end
