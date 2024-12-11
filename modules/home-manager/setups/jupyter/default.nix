{ lib, pkgs, config, inputs, ... }:

let
  inherit (lib) mkOption types;

  cfg = config.setups.jupyter;

  kernelType = types.submodule (import (inputs.nixpkgs + /nixos/modules/services/development/jupyter/kernel-options.nix) {
    inherit lib pkgs;
  });

  kernels = pkgs.jupyter-kernel.create  {
    definitions = cfg.kernels;
  };
in
{
  options.setups.jupyter = {
    enable = lib.mkEnableOption "jupyter notebook stuff";

    kernels = mkOption {
      description = "Declarative kernel config (see [services.jupyter.kernels](https://search.nixos.org/options?query=services.jupyter.kernels)).";
      type = types.attrsOf kernelType;
      default = {};
    };
    pythonKernels = mkOption {
      description = "Python kernel config.";
      type = types.attrsOf (types.submodule ({ config, name, ...}: {
        freeformType = (pkgs.formats.json { }).type;

        options = {
          displayName = lib.mkOption {
            type = lib.types.str;
            description = "Name that will be shown to the user.";
            default = "";
          };
          extraPythonPackages = mkOption {
            description = "Extra packages provided ti the python env.";
            type = types.functionTo (types.listOf types.package);
          };

          package = mkOption {
            description = "The python package to use.";
            type = types.package;
            default = pkgs.python3;
          };
          finalPythonEnv = mkOption {
            description = "Resulting python env.";
            type = types.package;
            readOnly = true;
          };
          finalKernel = mkOption {
            description = "Resulting kernel.";
            type = kernelType;
            readOnly = true;
          };
        };

        config = {
          extraPythonPackages = ps: [ ps.ipykernel ];
          finalPythonEnv = config.package.withPackages config.extraPythonPackages;
          finalKernel = {
            language = "python";
            argv = [
              config.finalPythonEnv.interpreter
              "-m" "ipykernel_launcher"
              "-f" "{connection_file}"
            ];
          } // lib.attrsets.removeAttrs config [
            "_module" "freeformType"
            "extraPythonPackages" "package" "finalPythonEnv" "finalKernel"
          ];
        };
      }));
      default = {
        default = {};
      };
    };
  };

  config = lib.mkIf cfg.enable {
    setups.jupyter.kernels = lib.mapAttrs (name: config: config.finalKernel) cfg.pythonKernels;

    neovim.main = {
      env.JUPYTER_PATH = toString kernels;

      pluginsWithConfig = [
        { plugin = pkgs.vimPlugins.molten-nvim;
          type = "viml";
          config = builtins.readFile ./molten-nvim.vim;
        }
        { plugin = pkgs.vimPlugins.jupytext-nvim;
          type = "lua";
          config = /* lua */ ''
            require('jupytext').setup({
              style = "markdown",
              output_extension = "md",
              force_ft = "markdown",
            })
          '';
        }
        { plugin = pkgs.vimPlugins.quarto-nvim;
          type = "lua";
          config = builtins.readFile ./quarto-nvim.lua;
        }
        { plugin = pkgs.vimPlugins.otter-nvim;
          type = "lua";
        }
      ];

      extraPython3Packages = ps: with ps; [
        pynvim
        jupyter-client

        pyperclip
        nbformat
      ];

      extraPackages = [
        pkgs.python311Packages.jupytext
      ];
      
      lspServers.pyright = {
        extraPackages = [ pkgs.pyright ];
        config = ''{}'';
      };

      # vimlConfig = builtins.readFile ./jupyter.vim;
    };
  };
}
