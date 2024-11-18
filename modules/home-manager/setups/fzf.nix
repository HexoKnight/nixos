{ lib, pkgs, config, ... }:

let
  cfg = config.setups.fzf;

  fzf-tab-completion = pkgs.fetchFromGitHub {
    owner = "lincheney";
    repo = "fzf-tab-completion";
    rev = "ae8462e19035af84586ac6871809e911d641a50c";
    hash = "sha256-0HAAHJqsX78QGDQ+ltUtM64RL4M1DCWzwc3kNHjoRFM=";
  };

  fdBin = lib.getExe pkgs.fd;

  inherit (config.lib.fzf) genFzfCommand genFzfbinds fzf-data;
in
{
  options.setups.fzf = {
    enable = lib.mkEnableOption "fzf stuff";
  };

  config = lib.mkIf cfg.enable {
    programs.fzf = {
      enable = true;
      defaultCommand = fdBin;
      defaultOptions = [
        (lib.cli.toGNUCommandLineShell {} {
          bind = genFzfbinds {
            ctrl-y = "preview-up";
            ctrl-e = "preview-down";
            ctrl-b = "preview-page-up";
            ctrl-f = "preview-page-down";
            ctrl-u = "preview-half-page-up";
            ctrl-d = "preview-half-page-down";
            tab = "down";
            shift-tab = "up";
            ctrl-space = "select";
          };
          no-mouse = true;
          reverse = true;
          height = "~10";
        })
      ];
    };

    programs.bash.initExtra =
    let
      fileBin = lib.getExe pkgs.file;
      batBin = lib.getExe pkgs.bat;
      ezaBin = lib.getExe pkgs.eza;
    in /* bash */ ''
      __fzf_select__() {
        ${genFzfCommand rec {
          defaultCommand = "fd -HE '.git'";
          withData = true;
          binds =
          let
            toggle-flag = fzf-data.toggle-flag-update-prompt defaultCommand;
          in
          {
            focus.transform-header = "${fileBin} -Lb {}";
            alt-l.transform = toggle-flag "-L";
            alt-d.transform = toggle-flag "-td";
            alt-f.transform = toggle-flag "-tf";
            alt-x.transform = toggle-flag "-tx";
            alt-e.transform = toggle-flag "-te";
            enter.become = "printf '%q' {}";
          };
          options = {
            preview = "${batBin} -n --color=always {} | head -200";
            scheme = "path";
            multi = true;
          };
        }}
      }
      __fzf_cd__() {
        ${genFzfCommand rec {
          defaultCommand = "fd -td -HE '.git'";
          withData = true;
          binds = {
            alt-l.transform = fzf-data.toggle-flag-update-prompt defaultCommand "-L";
            enter.become = "printf 'cd -- %q' {}";
          };
          options = {
            preview = "${ezaBin} --tree --colour=always {} | head -200";
            scheme = "path";
            no-multi = true;
          };
        }}
      }

      source ${fzf-tab-completion}/bash/fzf-bash-completion.sh
      bind -x '"\t": fzf_bash_completion'
      FZF_COMPLETION_AUTO_COMMON_PREFIX=true
      FZF_COMPLETION_AUTO_COMMON_PREFIX_PART=true
    '';
  };
}
