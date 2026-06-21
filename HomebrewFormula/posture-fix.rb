class PostureFix < Formula
  desc "Menu-bar app that nudges your posture using AirPods motion sensors"
  homepage "https://github.com/chandansgowda/posture-fix"
  # Build-from-source HEAD install. Replace the URL with your repo, then:
  #   brew install --HEAD chandansgowda/posture-fix/posture-fix
  head "https://github.com/chandansgowda/posture-fix.git", branch: "main"
  license "MIT"

  depends_on :macos
  depends_on xcode: ["15.0", :build]

  def install
    system "./build.sh", "release"
    bin_path = `swift build -c release --show-bin-path`.strip
    prefix.install "#{bin_path}/PostureFix.app"

    # Convenience launcher: `posture-fix` opens the menu-bar app.
    (bin/"posture-fix").write <<~SH
      #!/bin/bash
      open "#{prefix}/PostureFix.app"
    SH
  end

  def caveats
    <<~EOS
      PostureFix is a menu-bar app. Launch it with:
        posture-fix
      or copy it into /Applications so it shows in Spotlight:
        cp -R #{prefix}/PostureFix.app /Applications/

      On first launch: connect your AirPods, grant Motion + Notification
      permission, click Start, sit upright, then Calibrate.
    EOS
  end

  test do
    assert_predicate prefix/"PostureFix.app", :exist?
  end
end
