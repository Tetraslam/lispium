class Lispium < Formula
  desc "Symbolic Computer Algebra System written in Zig"
  homepage "https://github.com/Tetraslam/lispium"
  version "0.8.0"
  license "MIT"

  on_macos do
    on_arm do
      url "https://github.com/Tetraslam/lispium/releases/download/v0.8.0/lispium-macos-aarch64.tar.gz"
      sha256 "5432521b213b6bb2cd1aa5c633f9cee19acee9180f28117dfb53288cb1fcb8f7"
    end
    on_intel do
      url "https://github.com/Tetraslam/lispium/releases/download/v0.8.0/lispium-macos-x86_64.tar.gz"
      sha256 "2da8093182a763187616e11f4f96028113a96cf3032e70159f29f0e7c716b601"
    end
  end

  on_linux do
    on_arm do
      url "https://github.com/Tetraslam/lispium/releases/download/v0.8.0/lispium-linux-aarch64.tar.gz"
      sha256 "afd9b702f84607ad744ea7a0b4b83c6fce2b1c5b17974f1f2b22d159d0ae7b07"
    end
    on_intel do
      url "https://github.com/Tetraslam/lispium/releases/download/v0.8.0/lispium-linux-x86_64.tar.gz"
      sha256 "3b24d06193487c36413d502ca7bc4d192c4d6647c139e1c840ae4f7feb374ee6"
    end
  end

  def install
    bin.install "lispium"
  end

  test do
    assert_match "6", shell_output("#{bin}/lispium eval \"(+ 1 2 3)\"").strip
  end
end
