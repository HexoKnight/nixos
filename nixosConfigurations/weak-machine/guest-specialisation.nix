{ lib, ... }:

let
  username = "guest";
in
{
  specialisation.guest.configuration = {
    setups = {
      config = {
        inherit username;
      };
      impermanence = true;
      desktop = true;
      desktop-type = "plasma";
      flatpak = true;
    };

    services.displayManager.autoLogin = {
      enable = true;
      user = username;
    };
  };
}
