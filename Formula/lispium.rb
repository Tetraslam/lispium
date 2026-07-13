class Lispium < Formula
  desc "Symbolic Computer Algebra System written in Zig"
  homepage "https://github.com/Tetraslam/lispium"
  version "0.10.0"
  license "MIT"

  on_macos do
    on_arm do
      url "https://github.com/Tetraslam/lispium/releases/download/v0.10.0/lispium-macos-aarch64.tar.gz"
      sha256 "d1cd2a3d1437559b5e94d83c0f85b2ab69d555d936dc9a880dc88a402d686446"
    end
    on_intel do
      url "https://github.com/Tetraslam/lispium/releases/download/v0.10.0/lispium-macos-x86_64.tar.gz"
      sha256 "7347c281b2e1d8383cb5868c2c4e67ed0bf8fba914fe36c0dac9dcf03b523335"
    end
  end

  on_linux do
    on_arm do
      url "https://github.com/Tetraslam/lispium/releases/download/v0.10.0/lispium-linux-aarch64.tar.gz"
      sha256 "0847e81529ed36bd95242adddf840001ac7041f5edc95e75cba01e34f83c42a7"
    end
    on_intel do
      url "https://github.com/Tetraslam/lispium/releases/download/v0.10.0/lispium-linux-x86_64.tar.gz"
      sha256 "eff34aaa63a1538d498f70d2f1921234d2a3058847f7b838e6dd251c23dfaf90"
    end
  end

  def install
    bin.install "lispium"
  end

  test do
    assert_match "6", shell_output("#{bin}/lispium eval \"(+ 1 2 3)\"").strip
  end
end
