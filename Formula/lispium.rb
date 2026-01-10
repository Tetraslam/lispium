class Lispium < Formula
  desc "Symbolic Computer Algebra System written in Zig"
  homepage "https://github.com/Tetraslam/lispium"
  version "0.1.0"
  license "MIT"

  on_macos do
    on_arm do
      url "https://github.com/Tetraslam/lispium/releases/download/v0.1.0/lispium-macos-aarch64.tar.gz"
      sha256 "4b667ef73f2985880c2d20dfa4632fce5cbf455c60662a88399fad190856e50c"
    end
    on_intel do
      url "https://github.com/Tetraslam/lispium/releases/download/v0.1.0/lispium-macos-x86_64.tar.gz"
      sha256 "4ef0b1650d507af989058c55dd7e6198880430239493ecf54d8e1ad7a8211f97"
    end
  end

  on_linux do
    on_arm do
      url "https://github.com/Tetraslam/lispium/releases/download/v0.1.0/lispium-linux-aarch64.tar.gz"
      sha256 "f3507d19a2ab1fef17fdd95c4a46a1508ec755272d001d65110469fa979cbf9d"
    end
    on_intel do
      url "https://github.com/Tetraslam/lispium/releases/download/v0.1.0/lispium-linux-x86_64.tar.gz"
      sha256 "b816d769f40da3721fd25b73c2c8d4db930fa2b4b13f591365c9d1424593c2ab"
    end
  end

  def install
    bin.install "lispium"
  end

  test do
    assert_match "6", shell_output("#{bin}/lispium eval \"(+ 1 2 3)\"").strip
  end
end
