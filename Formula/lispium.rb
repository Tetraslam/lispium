class Lispium < Formula
  desc "Symbolic Computer Algebra System written in Zig"
  homepage "https://github.com/Tetraslam/lispium"
  version "0.5.1"
  license "MIT"

  on_macos do
    on_arm do
      url "https://github.com/Tetraslam/lispium/releases/download/v0.5.1/lispium-macos-aarch64.tar.gz"
      sha256 "0771a7c264ef38176150c6b9d04765405cfbff179b3916eb55cf389bd6f0769d"
    end
    on_intel do
      url "https://github.com/Tetraslam/lispium/releases/download/v0.5.1/lispium-macos-x86_64.tar.gz"
      sha256 "b3f2ef0fe5db898fae8e35c888521e7bacca3ea6718da10796b708787e6d785a"
    end
  end

  on_linux do
    on_arm do
      url "https://github.com/Tetraslam/lispium/releases/download/v0.5.1/lispium-linux-aarch64.tar.gz"
      sha256 "904479c653aa72df7045d3c1779acf43908a99ffa40ccf9c9a2844931ff0bd5b"
    end
    on_intel do
      url "https://github.com/Tetraslam/lispium/releases/download/v0.5.1/lispium-linux-x86_64.tar.gz"
      sha256 "ee7983c6d1e6c32d5f368d236c866b552584af4e2e30771120a49f78f0e64556"
    end
  end

  def install
    bin.install "lispium"
  end

  test do
    assert_match "6", shell_output("#{bin}/lispium eval \"(+ 1 2 3)\"").strip
  end
end
