{ lib, pkgs, ... }:

let
  inherit (lib) mkOption types;

  neovimPackageModule = {config, ...}: {
    imports = [
      ./lspconfig.nix
      ./plugins.nix
    ];
    options = {
      name = mkOption {
        description = "The name of the binary (defaults to the submodule attr name or 'nvim')";
        type = types.nonEmptyStr;
        default = config._module.args.name or "nvim";
      };

      env = mkOption {
        description = "Extra environment variables to set in the neovim wrapper.";
        type = types.attrsOf types.str;
        default = {};
      };

      extraWrapperArgs = mkOption {
        description = "Extra `makeWrapper` args.";
        type = types.listOf types.str;
        default = [];
      };

      vimlConfig = mkOption {
        description = "Main viml config (loaded after lua config).";
        type = types.lines;
        default = "";
      };
      luaConfig = mkOption {
        description = "Main lua config (loaded before vim config).";
        type = types.lines;
        default = "";
      };

      pluginPackages = mkOption {
        description = "Plugin packages.";
        type = types.listOf types.package;
        default = [];
      };
      extraPackages = mkOption {
        description = "Extra packages made available to neovim.";
        type = types.listOf types.package;
        default = [];
      };
      extraPython3Packages = mkOption {
        description = "Extra packages provided to neovim's python3.";
        type = types.functionTo (types.listOf types.package);
        default = _: [];
      };

      package = mkOption {
        description = "The package to use for the neovim binary.";
        type = types.package;
        default = pkgs.neovim-unwrapped;
      };
      finalPackage = mkOption {
        description = "Resulting configured neovim package.";
        type = types.package;
        readOnly = true;
      };
    };
    config =
    let
      isCustomName = config.name != "nvim";

      neovimConfig = pkgs.unstable.neovimUtils.makeNeovimConfig {
        customRC = config.vimlConfig;
        plugins = config.pluginPackages;
        inherit (config) extraPython3Packages;
      };
      neovimPackage = pkgs.unstable.wrapNeovimUnstable config.package (neovimConfig // {
        extraName = "-wrapped-" + config.name;
        luaRcContent = config.luaConfig;
        wrapperArgs = lib.concatLists ([
          neovimConfig.wrapperArgs
          [ "--prefix" "PATH" ":" (lib.makeBinPath config.extraPackages) ]
        ] ++ lib.mapAttrsToList (name: value: [ "--set" name value ] ) config.env ++ [
          config.extraWrapperArgs
        ]);
      });

      finalNeovimPackage = neovimPackage.overrideAttrs (final: prev: {
        # vi(m)Alias are not currently possible but
        # make sure to fix the symlinks if they do
        postBuild = prev.postBuild +
          lib.optionalString isCustomName ''
            mv $out/bin/nvim $out/bin/${lib.escapeShellArg config.name}
          '';

        meta = prev.meta // {
          mainProgram = config.name;
        };
      });
    in
    {
      _module.args = { inherit lib pkgs; };

      finalPackage = finalNeovimPackage;
    };
  };
in
{
  options.neovim = mkOption {
    description = "Neovim package configurations.";
    type = types.attrsOf (types.submodule neovimPackageModule);
  };
}
