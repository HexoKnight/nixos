{
  lib,
  formats,
  python3Packages,
  fetchPypi,
  fetchFromGitHub,

  # python function body evaluating to
  # the path used for storing data
  config_path_py ? ''
    from pathlib import Path
    from os import mkdir, environ

    xdg_config_dir = environ.get('XDG_CONFIG_DIR', default="")
    if len(xdg_config_dir) > 0:
      config_dir = Path(xdg_config_dir)
    else:
      config_dir = Path.home() / ".config"

    return config_dir / "steam-presence"
  '',

  ...
}:

let
  inherit (python3Packages) buildPythonPackage buildPythonApplication;
  pyproject-format = formats.toml { };

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
  version = "1.12.4";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "JustTemmie";
    repo = "steam-presence";
    rev = "v${version}";
    hash = "sha256-PUlNAktrpPygeJBYF0IQfqfz7g/sMayZA9/pUybh7Ig=";
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
      py-modules = [
        "main"
        "runningApps"
      ];
    };
  };

  postPatch =
    let
      mainPrefix = ''
        def __get_data_dir():
            ${lib.concatStringsSep "\n    " (lib.splitString "\n" config_path_py)}

        __file__dir = __import__("pathlib").Path(__get_data_dir())
        __file__dir.mkdir(parents=True, exist_ok=True)
        __file__ = __file__dir / "does_not_exist"
      '';

      # the script will be 'run' when being imported
      runningAppsSuffix = ''
        def main():
            pass
      '';
    in
    ''
      {
        printf '%s\n' ${lib.escapeShellArg mainPrefix}
        cat main.py
      } >$TMPDIR/temp-main.py
      mv $TMPDIR/temp-main.py main.py

      printf '\n%s' ${lib.escapeShellArg runningAppsSuffix} >>runningApps.py

      substituteInPlace requirements.txt \
        --replace-fail 'pypresence == 4.3.0' 'pypresence == 4.4.0'
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
