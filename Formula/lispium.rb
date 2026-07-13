class Lispium < Formula
  desc "Symbolic Computer Algebra System written in Zig"
  homepage "https://github.com/Tetraslam/lispium"
  version "0.9.0"
  license "MIT"

  on_macos do
    on_arm do
      url "https://github.com/Tetraslam/lispium/releases/download/v0.9.0/lispium-macos-aarch64.tar.gz"
      sha256 "004ff341da8b7fb8eebd12ed5b7d3fb132708f031f56cb1d74cc4e3fac35748d"
    end
    on_intel do
      url "https://github.com/Tetraslam/lispium/releases/download/v0.9.0/lispium-macos-x86_64.tar.gz"
      sha256 "7d6780a597fe6e6be80740238465bbdb415497db4fa38d26a0c9c1d5229f2deb"
    end
  end

  on_linux do
    on_arm do
      url "https://github.com/Tetraslam/lispium/releases/download/v0.9.0/lispium-linux-aarch64.tar.gz"
      sha256 "62526ce5bdc115b1036e5ced698b681e7a534bf8a390ebda0d593ed6e9912714"
    end
    on_intel do
      url "https://github.com/Tetraslam/lispium/releases/download/v0.9.0/lispium-linux-x86_64.tar.gz"
      sha256 "bfb78f22b947618051f75dd79eb46bca267142dbf6437dbd6b30c01290914dc8"
    end
  end

  def install
    bin.install "lispium"
  end

  test do
    assert_match "6", shell_output("#{bin}/lispium eval \"(+ 1 2 3)\"").strip
  end
end
