{ pkgs, config, ...}:

{
  home.packages = [ pkgs.trash-cli ];

  persist-home.directories = [ ".local/share/Trash" ];

  programs.bash.initExtra = /* bash */ ''
    # otherwise it creates tons of .Trash-1000 dirs bc it thinks each fuse
    # mount in my home dir (and then each btrfs subvolume) is a separate volume
    # that can't easily be copied across
    test -z "$TRASH_VOLUME" && TRASH_VOLUME=$(df --output=target "''${XDG_DATA_HOME:-$HOME/.local/share}/Trash" | sed 1d)
    alias trash='trash-put --force-volume "$TRASH_VOLUME"'

    trash-restore() {
      ${config.lib.fzf.genFzfCommand {
        defaultCommand = "trash-restore </dev/null 2>/dev/null | sed -e '/^\s*[0-9]/b; d'";
        options = {
          multi = true;
          delimiter = "\\s+";
          exit-0 = true;
        };
      }} |
      awk '
        BEGIN { all = "" }
        {
          if (all == "") all = $1
          else all = all "," $1
        }
        END { print all }
      ' |
      trash-restore >/dev/null
    }
  '';
}
