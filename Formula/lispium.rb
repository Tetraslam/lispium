class Lispium < Formula
  desc "Symbolic Computer Algebra System written in Zig"
  homepage "https://github.com/Tetraslam/lispium"
  version "0.11.0"
  license "MIT"

  on_macos do
    on_arm do
      url "https://github.com/Tetraslam/lispium/releases/download/v0.11.0/lispium-macos-aarch64.tar.gz"
      sha256 "9e1ca13bb1c3472c9feb7fc2fe5df8485e1a448c11c604d3ea1a19215d223a24"
    end
    on_intel do
      url "https://github.com/Tetraslam/lispium/releases/download/v0.11.0/lispium-macos-x86_64.tar.gz"
      sha256 "001fdd95e976be522ddc90107fd1622591b206d8878921c8d6c8ab7d954205e3"
    end
  end

  on_linux do
    on_arm do
      url "https://github.com/Tetraslam/lispium/releases/download/v0.11.0/lispium-linux-aarch64.tar.gz"
      sha256 "5b59833eaf8a6f865bb1c853fffbd9c313c008ca8072d4eb7eaf49f8fbbb86bf"
    end
    on_intel do
      url "https://github.com/Tetraslam/lispium/releases/download/v0.11.0/lispium-linux-x86_64.tar.gz"
      sha256 "2363efeccf89f8f1eb96a921a04a4d38ffcd0f4a16b47c547e818a8f5a49d45d"
    end
  end

  def install
    bin.install "lispium"
  end

  test do
    assert_match "6", shell_output("#{bin}/lispium eval \"(+ 1 2 3)\"").strip
  end
end
