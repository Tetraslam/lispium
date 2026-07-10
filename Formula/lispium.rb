class Lispium < Formula
  desc "Symbolic Computer Algebra System written in Zig"
  homepage "https://github.com/Tetraslam/lispium"
  version "0.6.2"
  license "MIT"

  on_macos do
    on_arm do
      url "https://github.com/Tetraslam/lispium/releases/download/v0.6.2/lispium-macos-aarch64.tar.gz"
      sha256 "b802d6959bcb3757ab59d1c92e4853d2c7a81f91623d69f590476f920c70d5a8"
    end
    on_intel do
      url "https://github.com/Tetraslam/lispium/releases/download/v0.6.2/lispium-macos-x86_64.tar.gz"
      sha256 "017233c12eefbeb5c3effe928d7843a19164fe9a907c491b2be99e3c5ae47c32"
    end
  end

  on_linux do
    on_arm do
      url "https://github.com/Tetraslam/lispium/releases/download/v0.6.2/lispium-linux-aarch64.tar.gz"
      sha256 "a001814b696e1c88ae992b20970c0f17b403bbe235d8050b09fcecb3543ddd55"
    end
    on_intel do
      url "https://github.com/Tetraslam/lispium/releases/download/v0.6.2/lispium-linux-x86_64.tar.gz"
      sha256 "32aa3c2240369094fca586439d8f24e09801fbcba0f1d852e880b4d38db91949"
    end
  end

  def install
    bin.install "lispium"
  end

  test do
    assert_match "6", shell_output("#{bin}/lispium eval \"(+ 1 2 3)\"").strip
  end
end
