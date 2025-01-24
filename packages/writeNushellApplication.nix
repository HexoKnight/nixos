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
     The `checkPhase` to run. Defaults to `shellcheck` on supported
     platforms and `bash -n`.

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
writeTextFile {
  inherit name meta passthru derivationArgs;
  executable = true;
  destination = "/bin/${name}";
  allowSubstitutes = true;
  preferLocalBuild = false;
  text = ''
    #!${nuBin}
  '' + lib.optionalString (runtimeEnv != null) ''
    load-env ${builtins.toJSON runtimeEnv}
  '' + lib.optionalString (runtimeInputs != [ ]) ''
    $env.PATH = ($env.PATH | prepend ${builtins.toJSON (getBinPaths runtimeInputs)})
  '' + ''

    ${text}
  '';

  checkPhase =
    if checkPhase == null then ''
      runHook preCheck
      ${nuBin} --commands "nu-check $target"
      runHook postCheck
    ''
    else checkPhase;
}
