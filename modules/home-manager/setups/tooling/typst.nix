{ lib, pkgs, config, ... }:

let
  cfg = config.setups.tooling.typst;

  inherit (pkgs) tinymist websocat;

  tinymistBin = lib.getExe tinymist;
  websocatBin = lib.getExe websocat;
in
{
  options.setups.tooling.typst = {
    enable = lib.mkEnableOption "typst stuff";
  };

  config = lib.mkIf cfg.enable {
    neovim.main = {
      pluginsWithConfig = [
        {
          plugin = pkgs.vimPlugins.typst-preview-nvim;
          type = "lua";
          config = /* lua */ ''
            require('typst-preview').setup({
              open_cmd = 'x-www-browser %s',

              dependencies_bin = {
                ['tinymist'] = '${tinymistBin}',
                ['websocat'] = '${websocatBin}',
              },
            })
          '';
        }
      ];

      lspServers = {
        tinymist = {
          extraPackages = [ tinymist ];
        };
      };
    };
  };
}
