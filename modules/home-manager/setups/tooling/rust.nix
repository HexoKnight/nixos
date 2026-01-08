{ lib, pkgs, config, ... }:

let
  cfg = config.setups.tooling.rust;
in
{
  options.setups.tooling.rust = {
    enable = lib.mkEnableOption "rust dev stuff";

    rustupDir = lib.mkOption {
      description = "the location (relative to $HOME) of rustup's home ($RUSTUP_HOME)";
      type = lib.types.pathWith {
        absolute = false;
        inStore = false;
      };
      default = ".local/share/rustup";
    };
    cargoDir = lib.mkOption {
      description = "the location (relative to $HOME) of cargo's home ($CARGO_HOME)";
      type = lib.types.pathWith {
        absolute = false;
        inStore = false;
      };
      default = ".local/share/cargo";
    };
  };

  config = lib.mkIf cfg.enable {
    persist-home = {
      directories = [
        cfg.rustupDir
        cfg.cargoDir
      ];
    };

    home.sessionVariables = {
      RUSTUP_HOME = "$HOME/${cfg.rustupDir}";
      CARGO_HOME = "$HOME/${cfg.cargoDir}";
    };

    home.sessionPath = [
      "$HOME/${cfg.cargoDir}/bin"
    ];

    home.packages = [
      # patch rustup to dynamically find the ld-wrapper (falling back to hard-coding for an attempt at back compat)
      # prevents breakage when the rustup version is changed and the old ld-wrapper store path is removed
      (pkgs.rustup.overrideAttrs (finalAttrs: prevAttrs: {
        postPatch = prevAttrs.postPatch or "" + ''
          substituteInPlace src/toolchain.rs \
            --replace-fail \
              'pub fn set_env(&self, cmd: &mut Command) {' \
              'pub fn set_env(&self, cmd: &mut Command) {
                   cmd.env("RUSTUP_EXE", &crate::utils::current_exe().unwrap());
              '
        '' +
        # patching after a patch:
        # https://github.com/NixOS/nixpkgs/blob/d351d0653aeb7877273920cd3e823994e7579b0b/pkgs/development/tools/rust/rustup/0001-dynamically-patchelf-binaries.patch
        # 4 levels of quoting D: (nix, bash, rust, bash)
        ''
          substituteInPlace src/dist/component/package.rs \
            --replace-fail \
              '\"{}\" $@' \
              '
                if [ -n \"${"$"}{{RUSTUP_EXE-}}\" ]; then
                  \"${"$"}{{RUSTUP_EXE%/*/*}}/nix-support/ld-wrapper.sh\" \"$@\"
                else
                  \"{}\" \"$@\"
                fi
              '
        '';

        # test binary is compiled single threaded for some reason
        # and the tests themselves take ages to run
        doCheck = false;
      }))

      # a cc is necessary for building rust programs
      pkgs.gcc
    ];

    programs.bacon = {
      enable = true;
      settings = {
        default_job = "clippy";
        keybindings = {
          j = "scroll-lines(1)";
          k = "scroll-lines(-1)";
          ctrl-d = "scroll-pages(0.5)";
          ctrl-u = "scroll-pages(-0.5)";
          g = "scroll-to-top";
          shift-g = "scroll-to-bottom";
        };
      };
    };

    neovim.main.lspServers = {
      rust_analyzer = {
        config.settings.rust-analyzer = {
          check.command = "clippy";
        };
      };
    };
  };
}
