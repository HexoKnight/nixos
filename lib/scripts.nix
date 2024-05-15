lib:

{
  mkScript =
    pkgs: binName: content:
    let
      script = pkgs.writeShellScriptBin binName content;
    in
    script // { outPath = "${script}/bin/${binName}"; };
}
