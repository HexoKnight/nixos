{ lib, config, ... }:

let
  username = "harvey";
in
{
  config = lib.mkIf (config.specialisation != {}) {
    setups = {
      config = {
        inherit username;
        extraUserOptions = {
          description = "Harvey Gream";
        };
      };
      impermanence = true;
      desktop = true;
    };

    userhome-config.${username}.extraHmConfig =
      { pkgs, ... }:
      {
        nixpkgs.allowUnfreePkgs = [
          "visual-paradigm"
          "idea-ultimate"
        ];

        home.packages = [
          pkgs.local.visual-paradigm
          pkgs.jetbrains.idea-ultimate
        ];
        persist-home = {
          directories = [
            ".config/VisualParadigm"

            # jetbrains.idea-ultimate
            ".cache/JetBrains"
            ".config/JetBrains"
            ".local/share/JetBrains"
            # I hate that this is generated
            # afaict it isn't actually required
            # but just in case :/
            ".java"
          ];
        };

        setups.jupyter.enable = true;
      };
  };
}
