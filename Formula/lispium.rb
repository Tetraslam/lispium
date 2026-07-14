class Lispium < Formula
  desc "Symbolic Computer Algebra System written in Zig"
  homepage "https://github.com/Tetraslam/lispium"
  version "0.14.0"
  license "MIT"

  on_macos do
    on_arm do
      url "https://github.com/Tetraslam/lispium/releases/download/v0.14.0/lispium-macos-aarch64.tar.gz"
      sha256 "e20f97ef5efda92d59c1f6c9db36aba78289dbed948230a0fe15535373fb8d4f"
    end
    on_intel do
      url "https://github.com/Tetraslam/lispium/releases/download/v0.14.0/lispium-macos-x86_64.tar.gz"
      sha256 "307a8bb668cd0c55338e8e71357397b291bf7247ba89887d8131266e7b34e90c"
    end
  end

  on_linux do
    on_arm do
      url "https://github.com/Tetraslam/lispium/releases/download/v0.14.0/lispium-linux-aarch64.tar.gz"
      sha256 "60c5e37f6cb3bfbf219f3ad1db5c009fc9925ab9c0f283eb534ab660604a851e"
    end
    on_intel do
      url "https://github.com/Tetraslam/lispium/releases/download/v0.14.0/lispium-linux-x86_64.tar.gz"
      sha256 "3d711c9f8b13a2d5e0e90f7e36435f3561a815d30ddcdbb6d4614565d4a2887f"
    end
  end

  def install
    bin.install "lispium"
  end

  test do
    assert_match "6", shell_output("#{bin}/lispium eval \"(+ 1 2 3)\"").strip
  end
end
