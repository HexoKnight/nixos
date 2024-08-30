{ lib,
  formats,
  python3Packages,
  fetchPypi, fetchFromGitHub,

  # python function body evaluating to
  # the path used for storing data
  config_path_py ? /* python */ ''
    from pathlib import Path
    from os import mkdir, environ

    xdg_config_dir = environ.get('XDG_CONFIG_DIR', default="")
    if len(xdg_config_dir) > 0:
      config_dir = Path(xdg_config_dir)
    else:
      config_dir = Path.home() / ".config"

    return config_dir / "steam-presence"
  '',

... }:

let
  inherit (python3Packages) buildPythonPackage buildPythonApplication;
  pyproject-format = formats.toml {};

  python-steamgriddb = buildPythonPackage rec {
    pname = "python-steamgriddb";
    version = "1.0.5";
    format = "setuptools";

    src = fetchPypi {
      inherit pname version;
      sha256 = "sha256-A223uwmGXac7QLaM8E+5Z1zRi0kIJ1CS2R83vxYkUGk=";
    };

    dependencies = [
      python3Packages.requests
    ];

    nativeCheckInputs = [
      python3Packages.pip
    ];

    meta = with lib; {
      homepage = "https://github.com/ZebcoWeb/python-steamgriddb";
      description = "Python API wrapper for SteamGridDB.com";
      license = licenses.mit;
    };
  };
in
buildPythonApplication rec {
  pname = "steam-presence";
  # instead of 'YYYY-MM-DD' in order to conform to pep440
  version = "2024.08.21";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "JustTemmie";
    repo = "steam-presence";
    rev = "efec15f14db2fcb4a966cc0f2392ce77fe4805e7";
    hash = "sha256-IPGy7wpX7Y8rKgtmq7BD3ckLQ8PUrx4uUDdzmr0ld/U=";
  };

  build-system = [ python3Packages.setuptools ];

  dependencies = with python3Packages; [
    python-steamgriddb
    pypresence
    beautifulsoup4
    requests
    psutil
  ];

  pyproject-toml = pyproject-format.generate "pyproject.toml" {
    project = {
      name = pname;
      inherit version;
      inherit (meta) description;

      dynamic = [ "dependencies" ];

      scripts = {
        ${pname} = "main:main";
        runningApps = "runningApps:main";
      };
    };
    tool.setuptools = {
      dynamic = {
        dependencies.file = "requirements.txt";
      };
      py-modules = [ "main" "runningApps" ];
    };
  };

  postPatch = ''
    {
      printf '%s\n' ${lib.escapeShellArg /* python */ ''
        def __get_data_dir():
            ${lib.concatStringsSep "\n    " (lib.splitString "\n" config_path_py)}

        __file__dir = __import__("pathlib").Path(__get_data_dir())
        __file__dir.mkdir(parents=True, exist_ok=True)
        __file__ = __file__dir / "does_not_exist"
      ''}
      cat main.py
    } >$TMPDIR/temp-main.py
    mv $TMPDIR/temp-main.py main.py

    # the script will be 'run' when being imported
    printf %s ${lib.escapeShellArg /* python */ ''
      def main():
          pass
    ''} >>runningApps.py
  '';

  preBuild = ''
    ln -s ${pyproject-toml} pyproject.toml
  '';

  meta = with lib; {
    description = "A script that takes the game you're playing on steam and displays it on discord";
    homepage = "https://github.com/JustTemmie/steam-presence";
    mainProgram = pname;
    license = licenses.mit;
    platforms = platforms.linux ++ platforms.darwin;
  };
}
