{
  lib,
  writeTextFile,

  nushell,
}:

let
  nuBin = lib.getExe nushell;

  getBinPaths = pkgs: map (pkg: (lib.getOutput "bin" pkg) + "/bin") (lib.filter (x: x != null) pkgs);
in
# largely copied from upstream writeShellApplication
{
  /*
     The name of the script to write.

     Type: String
   */
  name,
  /*
     The shell script's text, not including a shebang.

     Type: String
   */
  text,
  /*
     Whether to treat the script as if it were a nushell module rather than a nushell 'script'.

     Makes an equivalent nushell module available at a `nuModule` drv attr.
     The script can then be used as module to get a nushell custom command that acts just
     like the script. For example: `use ${drv.nuModule} *; ${drv.name} --help`. However,
     due to how the module conversion is implemented, main functions cannot be called as
     their definitions are renamed later on.

     This gives better error messages so prefer simply wrapping the script in a
     `def main [] {...}`, to turn it into a module over leaving this option off.

     # Important

     Enabling this option requires that a `#load-runtime` 'directive' be placed at every
     entrypoint, which will be replaced with a command to load the runtime env. This is
     required because modules can only change the global env if such a change is exported,
     eg. via `export-env`.

     Type: Boolean
   */
  isModule ? false,
  /*
     Inputs to add to the shell script's `$PATH` at runtime.

     Type: [String|Derivation]
   */
  runtimeInputs ? [ ],
  /*
     Extra environment variables to set at runtime.

     Type: AttrSet
   */
  runtimeEnv ? null,
  /*
     `stdenv.mkDerivation`'s `meta` argument.

     Type: AttrSet
   */
  meta ? { },
  /*
     `stdenv.mkDerivation`'s `passthru` argument.

     Type: AttrSet
   */
  passthru ? { },
  /*
     The `checkPhase` to run.

     If `isModule` is true, `checkPhase` defaults to importing the script with `use`.
     Otherwise, `checkPhase` defaults to running `nu-check`.

     The script path will be given as `$target` in the `checkPhase`.

     Type: String
   */
  checkPhase ? null,
  /* Extra arguments to pass to `stdenv.mkDerivation`.

     :::{.caution}
     Certain derivation attributes are used internally,
     overriding those could cause problems.
     :::

     Type: AttrSet
   */
  derivationArgs ? { },
}:
let
  runtimeChanges = runtimeEnv != null || runtimeInputs != [];

  scriptText = lib.optionalString (runtimeEnv != null) ''
    load-env ${builtins.toJSON runtimeEnv}
  '' + lib.optionalString (runtimeInputs != []) ''
    $env.PATH = ($env.PATH | prepend ${builtins.toJSON (getBinPaths runtimeInputs)})
  '' + ''

    ${text}
  '';

  patchPhase = lib.optionalString (isModule && runtimeChanges) ''
    substituteInPlace $target --replace-fail \
      '#load-runtime' '__load_runtime'
  '';

  # *should*:    on lines matching: (export)? def ... "? main .* [ ...
  # - prepend `export` (if not present)
  # - replace `main` with ${name}
  # requires:
  # - `def` to be the first word on the line
  # - `def` up to argument list `[` to be on one line (I think this is required by nushell as well?)
  # - no other `[`s between `def` and argument list `[`:
  # - no `"`s before the one immediately preceding main
  replaceMain = ''
    sed -i $target -Ee 's/^(\s*export\s)?(\s*def\s[^["]*"?)main(\s[^]]*\[)/export \2${name}\3/'
  '';

  moduleText = if !runtimeChanges then text else ''
    ${text}

    def --env __load_runtime [] {
    '' + lib.optionalString (runtimeEnv != null) ''
      load-env ${builtins.toJSON runtimeEnv}
    '' + lib.optionalString (runtimeInputs != []) ''
      $env.PATH = ($env.PATH | prepend ${builtins.toJSON (getBinPaths runtimeInputs)})
    '' + ''
    }
  '';

  nuModName = name + "-mod";
  nuModPath = "/${nuModName}.nu";
  nuModule = writeTextFile {
    name = nuModName;
    destination = nuModPath;
    allowSubstitutes = true;
    preferLocalBuild = false;
    text = moduleText;

    derivationArgs.passAsFile = [
      "nuCheckScript"
    ];

    derivationArgs.nuCheckScript = /* nu */ ''
      let module_exports = (
        help modules |
        where name == "${nuModName}" |
        get commands |
        flatten |
        get name
      )

      if "${name}" in $module_exports { return }
      error make { msg: "'${name}' command not exported by module (did you define a main function?)" }
    '';

    checkPhase = ''
      ${replaceMain}
      ${patchPhase}

      runHook preCheck
      FORCE_COLOR=1 ${nuBin} --commands "use '$target' *; source '$nuCheckScriptPath'"
      runHook postCheck
    '';

    passthru.modFile = "${nuModule}${nuModPath}";
  };
in
writeTextFile {
  inherit name meta derivationArgs;
  executable = true;
  destination = "/bin/${name}";
  allowSubstitutes = true;
  preferLocalBuild = false;
  text = ''
    #!${nuBin}

    ${if isModule then moduleText else scriptText}
  '';

  # hijack checkPhase to do some patching
  checkPhase = patchPhase +
    (if checkPhase == null then ''
      runHook preCheck
      ${
        if isModule then ''
          FORCE_COLOR=1 ${nuBin} --commands "use $target"
        '' else ''
          FORCE_COLOR=1 ${nuBin} --commands "nu-check --debug $target"
        ''
      }
      runHook postCheck
    ''
    else checkPhase);

  passthru = passthru // lib.optionalAttrs isModule {
    inherit nuModule;
  };
}
