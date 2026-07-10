class Lispium < Formula
  desc "Symbolic Computer Algebra System written in Zig"
  homepage "https://github.com/Tetraslam/lispium"
  version "0.5.1"
  license "MIT"

  on_macos do
    on_arm do
      url "https://github.com/Tetraslam/lispium/releases/download/v0.5.1/lispium-macos-aarch64.tar.gz"
      sha256 "d8283502d17458ff111b844c343b11e7a3d57469849edc406d8a149eecc70117"
    end
    on_intel do
      url "https://github.com/Tetraslam/lispium/releases/download/v0.5.1/lispium-macos-x86_64.tar.gz"
      sha256 "e90a4fe1e934a1010f39de31ee336ac1cbdfb1f081ff0d441ca6890edf2bb2a1"
    end
  end

  on_linux do
    on_arm do
      url "https://github.com/Tetraslam/lispium/releases/download/v0.5.1/lispium-linux-aarch64.tar.gz"
      sha256 "481c5e9415714f1bcd05632813e853c613da172b8f9c2c62d6eea2f1f86a08fd"
    end
    on_intel do
      url "https://github.com/Tetraslam/lispium/releases/download/v0.5.1/lispium-linux-x86_64.tar.gz"
      sha256 "c65d6a489f0b82532d7cf6c1f08860372b4799d7764aef7c001784e11908dfde"
    end
  end

  def install
    bin.install "lispium"
  end

  test do
    assert_match "6", shell_output("#{bin}/lispium eval \"(+ 1 2 3)\"").strip
  end
end
