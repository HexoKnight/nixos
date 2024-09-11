{ lib }:

let
  # inherit (lib) mkOption;
  inherit (lib.types)
    path
    str
    bool
    listOf
    coercedTo
    submodule
    attrsOf
  ;

  mkOption = attrs:
    lib.mkOption (
      if attrs ? default then attrs else
      attrs // {
        default = null;
      } // lib.optionalAttrs (attrs ? type && ! attrs.type.check null) {
        type = lib.types.nullOr attrs.type;
      }
    );

  # copy of upstream's public interface
  original-options = lib.makeExtensibleWithCustomName "override" (final:
  let
    coercedToSubmoduleOpts = attrName: options:
      listOf (coercedTo str (f: { ${attrName} = f; }) (final.submoduleOpts options));
  in
  {
    submoduleOpts = options: submodule { inherit options; };

    commonOpts = {
      persistentStoragePath = mkOption {
        type = path;
        description = ''
          The path to persistent storage where the real
          file or directory should be stored.
        '';
      };
    };

    hideMounts = mkOption {
      type = bool;
      description = ''
        Whether to hide bind mounts from showing up as
        mounted drives.
      '';
    };

    fileOpts = final.commonOpts // {
      file = mkOption {
        type = str;
        description = ''
          The path to the file.
        '';
      };
    };

    dirOpts = final.commonOpts // {
      directory = mkOption {
        type = str;
        description = ''
          The path to the directory.
        '';
      };

      hideMount = final.hideMounts;

      user = mkOption {
        type = str;
        description = ''
          If the directory doesn't exist in persistent
          storage it will be created and owned by the user
          specified by this option.
        '';
      };
      group = mkOption {
        type = str;
        description = ''
          If the directory doesn't exist in persistent
          storage it will be created and owned by the
          group specified by this option.
        '';
      };
      mode = mkOption {
        type = str;
        example = "0700";
        description = ''
          If the directory doesn't exist in persistent
          storage it will be created with the mode
          specified by this option.
        '';
      };
    };

    files = mkOption {
      type = coercedToSubmoduleOpts "file" final.fileOpts;
      description = ''
        Files that should be stored in persistent storage.
      '';
    };
    directories = mkOption {
      type = coercedToSubmoduleOpts "directory" final.dirOpts;
      description = ''
        Directories to bind mount to persistent storage.
      '';
    };

    userOpts = {
      home = mkOption {
        type = path;
        description = ''
          The user's home directory. Only
          useful for users with a custom home
          directory path.

          Cannot currently be automatically
          deduced due to a limitation in
          nixpkgs.
        '';
      };

      inherit (final) files directories;
    };

    users = mkOption {
      type = attrsOf (final.submoduleOpts final.userOpts);
      description = ''
        A set of user submodules listing the files and
        directories to link to their respective user's
        home directories.

        Each attribute name should be the name of the
        user.

        For detailed usage, check the <link
        xlink:href="https://github.com/nix-community/impermanence">documentation</link>.
      '';
    };

    options = {
      inherit (final.commonOpts) persistentStoragePath;
      inherit (final) files directories users hideMounts;

      enableWarnings = mkOption {
        type = bool;
        description = ''
          Enable non-critical warnings.
        '';
      };
    };

    persistence = mkOption {
      type = final.submoduleOpts final.options;
      description = ''
        A persistent storage location submodule listing the
        files and directories to link to their respective persistent
        storage location.

        For detailed usage, check the <link
        xlink:href="https://github.com/nix-community/impermanence">documentation</link>.
      '';
    };
  });

  options = original-options.override (final: prev: {
    # TODO: add extensions
  });
in
options
