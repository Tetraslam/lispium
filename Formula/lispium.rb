class Lispium < Formula
  desc "Symbolic Computer Algebra System written in Zig"
  homepage "https://github.com/Tetraslam/lispium"
  version "0.6.1"
  license "MIT"

  on_macos do
    on_arm do
      url "https://github.com/Tetraslam/lispium/releases/download/v0.6.1/lispium-macos-aarch64.tar.gz"
      sha256 "6e2b900eec0401f0c9c2f52d11f88be6ad8905b8eb9d17eb1f344fe48ac2c41b"
    end
    on_intel do
      url "https://github.com/Tetraslam/lispium/releases/download/v0.6.1/lispium-macos-x86_64.tar.gz"
      sha256 "04467107faeb3eb91c8b266ce92d2c4340be64723442376730197245cab8e4f8"
    end
  end

  on_linux do
    on_arm do
      url "https://github.com/Tetraslam/lispium/releases/download/v0.6.1/lispium-linux-aarch64.tar.gz"
      sha256 "63f24aeacab1d4bac9a74cb4a532eff70bbad65a5e7c0f1ad8b27fea8e7a222e"
    end
    on_intel do
      url "https://github.com/Tetraslam/lispium/releases/download/v0.6.1/lispium-linux-x86_64.tar.gz"
      sha256 "f543c80a2b27032e51513a8a51d5e7e150bbfee7e5745d9efef57a9e9f4ca82e"
    end
  end

  def install
    bin.install "lispium"
  end

  test do
    assert_match "6", shell_output("#{bin}/lispium eval \"(+ 1 2 3)\"").strip
  end
end
