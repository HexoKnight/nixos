# NixOS Config

This is my personal NixOS configuration and is not designed to be used directly by others (though that should be possible if you want to try :).
Though feel free to take inspiration from any relevant modules.

See [Use it yourself](#use-it-yourself) to well...

## Overview

Lots of these could be switched out with relative ease, some... not so much :/

### Essentially embedded

- Distro: [🤔...](https://nixos.org)
- Window Manager: [Hyprland](https://hyprland.org)

### Quite configured but could be switched out easily

- Bar: [eww](https://github.com/elkowar/eww) (very eh atm)
- Launcher: [rofi](https://github.com/davatorium/rofi)
- Editor: [Neovim](https://neovim.io)

### minimal to no configuration and could/should be switched out at a moment's notice

- Terminal: [kitty](https://sw.kovidgoyal.net/kitty)
- Display Manager: [sddm](https://github.com/sddm/sddm) (very [minimal](https://github.com/stepanzubkov/where-is-my-sddm-theme))
- Notification Daemon: [mako](https://github.com/emersion/mako)

## Other things of note

- optional [impermanence](https://github.com/nix-community/impermanence) setup (tldr: / go BOOM on boot) which really displays the power of NixOS.
- [nice scripts](scripts/) (that can be run outside of this config easily: `github:HexoKnight/nixos#<script-name>` for use in `nix shell/run/etc.`) including:
    - [nixos](scripts/nixos.sh) -
        essentially a more ergonomic `nixos-rebuild`, centred around flakes, I've tried my best to keep it general so that it works for managing any nixos flake, not just this one

### Some nice modules

- [hyprbinds](modules/home-manager/setups/hyprland/hyprbinds.nix) -
    a nixy?? interface to declare hyprland binds (submap support is missing but to be added eventually hopefully)
- [fzf](modules/home-manager/fzf.nix) -
    a few functions for generating complex fzf commands
- [neovim plugin stuff](modules/home-manager/setups/neovim/plugins/default.nix) -
    not entirely standalone but provides a few functions for concisely importing and configuring plugins
- [declarative cloudflare dns](modules/nixos/cloudflare-dns/default.nix) -
    a module for managing cloudflare dns records declaratively from a nixos config

## Use it yourself

Create your own configuration in `configurations/`.
See the other configurations in that directory for examples.
(you can generate most of the hardware boilerplate with `nixos-generate-config --show-hardware-config`)

You will want to use the following to set your own password if you want to use sops to manage the password
(you need a `--` before any arguments to stop them being passed to `nix run`)
```bash
nix run github:HexoKnight/nixos#gen-sops-secrets -- --help
...
nix run github:HexoKnight/nixos#gen-sops-secrets -- [whatever args] >path/to/local/nixos/secrets.json
```

You probably want to disable impermanence, at least at first, because otherwise that
requires reformatting your disk (unless you happen to have the exact setup already),
which you can do with [disko](https://github.com/nix-community/disko) or manually.
