class Lispium < Formula
  desc "Symbolic Computer Algebra System written in Zig"
  homepage "https://github.com/Tetraslam/lispium"
  version "0.13.0"
  license "MIT"

  on_macos do
    on_arm do
      url "https://github.com/Tetraslam/lispium/releases/download/v0.13.0/lispium-macos-aarch64.tar.gz"
      sha256 "5d6ae6d8e418afddf3e2546110b1d68b68872a2daca34fc10473ef0a2a691d4d"
    end
    on_intel do
      url "https://github.com/Tetraslam/lispium/releases/download/v0.13.0/lispium-macos-x86_64.tar.gz"
      sha256 "71632e9ff0192351fd757e1e9dff75bd4788e14e4575b91e93295e206186ca9e"
    end
  end

  on_linux do
    on_arm do
      url "https://github.com/Tetraslam/lispium/releases/download/v0.13.0/lispium-linux-aarch64.tar.gz"
      sha256 "1cfe41eedfded3762defdf0d52cf67bcf7e8c3ee3d538f05c3ae0e169b2ae841"
    end
    on_intel do
      url "https://github.com/Tetraslam/lispium/releases/download/v0.13.0/lispium-linux-x86_64.tar.gz"
      sha256 "0792ef90523305eb0af37609c6e359a212899cdbb1031de7cef0d67ffb774b59"
    end
  end

  def install
    bin.install "lispium"
  end

  test do
    assert_match "6", shell_output("#{bin}/lispium eval \"(+ 1 2 3)\"").strip
  end
end
