{
  lib,
  formats,
  python3Packages,
  fetchFromGitHub,
  ffmpeg,
}:

let
  pyproject-format = formats.toml { };
in
python3Packages.buildPythonApplication rec {
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

  dependencies = [
    python3Packages.discordpy # voice support by default
    # pynacl included as dependency of discordpy with voice support
    python3Packages.googletrans
    # ffmpeg included as dependency of youtube-dl
    python3Packages.yt-dlp
    python3Packages.parsedatetime
  ];

  makeWrapperArgs = [
    "--prefix PATH : ${lib.makeBinPath [ ffmpeg ]}"
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

  meta = {
    description = "bruh bot (a discord bot)";
    homepage = "https://github.com/HexoKnight/Bruh-Bot";
    mainProgram = pname;
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
  };
}
