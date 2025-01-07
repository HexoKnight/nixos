{
  lib, stdenvNoCC,
  fetchurl,
  autoPatchelfHook,

  jdk,
}:

let
  jdk_javafx = jdk.override {
    enableJavaFX = true;
  };
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "visual-paradigm";
  version = "17.2";
  # visual paradigm does not keep old builds so this has to be updated occasionally
  build = "20250101";

  src = fetchurl {
    # use the following to get the build number:
    # curl -v "https://www.visual-paradigm.com/downloads/vp${version}/Visual_Paradigm_Linux64_InstallFree.tar.gz" 2>&1 | grep '< location'
    url =
      let
        underscore_version = builtins.replaceStrings [ "." ] [ "_" ] finalAttrs.version;
      in
      "https://eu8.dl.visual-paradigm.com/visual-paradigm/vp${finalAttrs.version}/${finalAttrs.build}/Visual_Paradigm_${underscore_version}_${finalAttrs.build}_Linux64_InstallFree.tar.gz";
    hash = "sha256-LBG2toVVKyUbVGauCd9fOt5iVsJJUl558iWi3d9xEds=";
  };

  nativeBuildInputs = [
    autoPatchelfHook
  ];

  stripDebugList = [ "jre/lib" ];
  stripDebugFlags = [ "--strip-unneeded" ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out

    mv -t $out Application .install4j
    
    MODULES=$(source jre/release; printf %s "$MODULES")
    ${lib.getExe' jdk_javafx "jlink"} \
      --module-path ${jdk_javafx}/lib/openjdk/jmods \
      --add-modules ''${MODULES// /,} \
      --compress=2 \
      --output $out/jre

    substituteInPlace $out/Application/bin/Visual_Paradigm \
      --replace-fail \
        '\'"$"'{installer:sys.userHome}' \
        '$HOME'

    mkdir $out/bin
    ln -s -t $out/bin ../Application/bin/Visual_Paradigm
    ln -s Visual_Paradigm $out/bin/visual-paradigm

    runHook postInstall
  '';

  # to avoid patching $out/jre
  env.dontAutoPatchelf = 1;
  postFixup = ''
    autoPatchelf -- $out/Application
  '';

  meta = {
    description = "A suite of design, analysis and management tools to drive your IT project development and digital transformation.";
    homepage = "https://www.visual-paradigm.com";
    license = lib.licenses.unfree;
    platforms = [ "x86_64-linux" ];
    mainProgram = "visual-paradigm";
  };
})
