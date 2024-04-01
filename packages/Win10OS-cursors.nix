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
}
