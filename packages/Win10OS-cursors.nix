{ lib, stdenvNoCC, fetchFromGitHub,
inkscape }:

stdenvNoCC.mkDerivation rec {
  name = "Win10OS-cursors";

  src = fetchFromGitHub {
    owner = "yeyushengfan258";
    repo = "Win10OS-cursors";
    rev = "79d13bb90eb9346a40a2da5a1f5cb24cb919f256";
    hash = "sha256-fwnTC1jZl88orC4sBsMglmMlA2N1SlD/6qT5FBPpL4c=";
  };

  installPhase = ''
    install -dm 0755 $out/share/icons
    cp -pr dist $out/share/icons/Win10OS-cursors
  '';

  meta = with lib; {
    description = "An x-cursor theme inspired by WinOS and based on capitaine-cursors";
    homepage = "https://github.com/yeyushengfan258/Win10OS-cursors";
    license = licenses.gpl3Only;
    platforms = platforms.all;
  };
}
