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
      sha256 "2bf48ef1c665c71082cd6ed14a11ae5a50bcdb39c7ba79b02d27b2f93060f0db"
    end
  end

  on_linux do
    on_arm do
      url "https://github.com/Tetraslam/lispium/releases/download/v0.16.0/lispium-linux-aarch64.tar.gz"
      sha256 "5f55c2488dd51cf31d5a325beb233af11692d6829de32362fc414a6d670c1d30"
    end
    on_intel do
      url "https://github.com/Tetraslam/lispium/releases/download/v0.16.0/lispium-linux-x86_64.tar.gz"
      sha256 "66e191b13e83550c6b17e8e6fe840d165e8d7dce113e3b513890e09b0a7276eb"
    end
  end

  def install
    bin.install "lispium"
  end

  test do
    assert_match "6", shell_output("#{bin}/lispium eval \"(+ 1 2 3)\"").strip
  end
end
