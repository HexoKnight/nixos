{ lib, pkgs, config, ... }:

# https://www.reddit.com/r/NixOS/comments/17ilg97/comment/k6vjqj3/
with lib; {
  options = {
    boot.loader.grub.timestampFormat = mkOption {
      default = "%F";
      example = "%F %H:%M";
      type = types.str;
      description = "How to display timestamps in the boot menu";
    };

    system.build.installBootLoader = mkOption {
      internal = true;
      visible = false;
      apply = old_sh:
        pkgs.writeShellScript "wrap-boot-loader-install" ''
          old_pl=$(${pkgs.gawk}/bin/awk '/-install-grub.pl/ { print $2 }' ${old_sh})
          new_pl=$(${pkgs.coreutils}/bin/mktemp --suffix=.pl)
          ${pkgs.gnused}/bin/sed 's/%F/${config.boot.loader.grub.timestampFormat}/' "$old_pl" > "$new_pl"
          new_sh=$(${pkgs.coreutils}/bin/mktemp --suffix=.sh)
          ${pkgs.gawk}/bin/awk -v new_pl="$new_pl" '/-install-grub.pl/ { $2 = new_pl } 1' ${old_sh} > "$new_sh"
          ${pkgs.coreutils}/bin/chmod +x "$new_sh"
          "$new_sh" "$@"
        '';
    };
  };
}
