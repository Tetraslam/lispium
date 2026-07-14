class Lispium < Formula
  desc "Symbolic Computer Algebra System written in Zig"
  homepage "https://github.com/Tetraslam/lispium"
  version "0.12.0"
  license "MIT"

  on_macos do
    on_arm do
      url "https://github.com/Tetraslam/lispium/releases/download/v0.12.0/lispium-macos-aarch64.tar.gz"
      sha256 "8d872df6189567a9e7a94872427ef425880dfdfd2e3c9a27a0e573544dbd9307"
    end
    on_intel do
      url "https://github.com/Tetraslam/lispium/releases/download/v0.12.0/lispium-macos-x86_64.tar.gz"
      sha256 "89ea92ff7b1907f1d71a367d5f31dc986b9368699211de01086adc10cc8202bf"
    end
  end

  on_linux do
    on_arm do
      url "https://github.com/Tetraslam/lispium/releases/download/v0.12.0/lispium-linux-aarch64.tar.gz"
      sha256 "8b9cb4a361219ac95260774b53029f08fbdb0ce23e4efbfb53a6090e4daf8485"
    end
    on_intel do
      url "https://github.com/Tetraslam/lispium/releases/download/v0.12.0/lispium-linux-x86_64.tar.gz"
      sha256 "473449d40915b1d3869949a1df56e83b108353d659927710d0ac92607acbce10"
    end
  end

  def install
    bin.install "lispium"
  end

  test do
    assert_match "6", shell_output("#{bin}/lispium eval \"(+ 1 2 3)\"").strip
  end
end
