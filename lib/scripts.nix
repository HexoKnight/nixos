lib:

{
  mkScript =
    pkgs: binName: content:
    (pkgs.writeShellScriptBin binName content) + "/bin/" + binName;
}
