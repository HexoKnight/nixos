{
  lib,
  formats,
  python3Packages,
  fetchPypi, fetchFromGitHub,
  ffmpeg,
}:

let
  inherit (python3Packages) buildPythonPackage buildPythonApplication;
  pyproject-format = formats.toml {};

  googletrans = buildPythonPackage rec {
    pname = "googletrans";
    version = "4.0.2";
    format = "pyproject";

    src = fetchPypi {
      inherit pname version;
      hash = "sha256-2e8Sa12S+r7sC7ndzb7s1Dhl/ADhfx36B3F4N4J6F94=";
    };

    build-system = [ python3Packages.hatchling ];

    dependencies = with python3Packages; [
      httpx
      httpx.optional-dependencies.http2
    ];

    meta = with lib; {
      homepage = "https://py-googletrans.readthedocs.io";
      description = "Python library to interact with Google Translate API";
      license = licenses.mit;
    };
  };
in
buildPythonApplication rec {
  pname = "bruh-bot";
  # instead of 'YYYY-MM-DD' to conform to pep440
  version = "2023.09.13";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "HexoKnight";
    repo = "Bruh-Bot";
    rev = "fac964aed95fe88f9d266ae0a3aa2418380165c3";
    hash = "sha256-mTxD6co3aMIeTSo90MTEy75gTBB7p6yWTLBBBJW9O10=";
  };

  build-system = [ python3Packages.setuptools ];

  dependencies = with python3Packages; [
    discordpy # voice support by default
    # pynacl included as dependency of discordpy with voice support
    googletrans
    # ffmpeg included as dependency of youtube-dl
    yt-dlp
    parsedatetime
  ];

  makeWrapperArgs = [
    "--prefix PATH : ${lib.makeBinPath [ ffmpeg ] }"
  ];

  pyproject-toml = pyproject-format.generate "pyproject.toml" {
    project = {
      name = pname;
      inherit version;
      inherit (meta) description;

      dynamic = [ "dependencies" ];

      scripts = {
        ${pname} = "main:main";
      };
    };
    tool.setuptools = {
      dynamic = {
        dependencies.file = "requirements.txt";
      };
      py-modules = [
        "main"
        "data"
        "admin_commands"
        "user_commands"
        "client_events"
        "audio"
      ];
    };
  };

  postPatch = ''
    substituteInPlace requirements.txt \
      --replace-fail 'googletrans==3.1.0a0' 'googletrans' \
      --replace-fail 'youtube-dl' 'yt_dlp'

    # wow. I really dislike python importing
    substituteInPlace data.py admin_commands.py user_commands.py client_events.py audio.py \
      --replace-fail '__main__' 'main'
    substituteInPlace main.py \
      --replace-fail 'if __name__ == "__main__":' 'def main():'

    substituteInPlace user_commands.py \
      --replace-fail 'from datetime import datetime' "" \
      --replace-fail \
        'translated = googletrans.Translator().translate' \
        'translated = await googletrans.Translator().translate'

    substituteInPlace audio.py \
      --replace-fail 'youtube_dl' 'yt_dlp'
  '';

  preBuild = ''
    ln -s ${pyproject-toml} pyproject.toml
  '';

  meta = with lib; {
    description = "bruh bot (a discord bot)";
    homepage = "https://github.com/HexoKnight/Bruh-Bot";
    mainProgram = pname;
    platforms = platforms.linux ++ platforms.darwin;
  };
}
