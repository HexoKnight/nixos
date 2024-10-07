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
stdenvNoCC.mkDerivation rec {
  pname = "visual-paradigm";
  version = "17.2";

  src = fetchurl {
    url = "https://www.visual-paradigm.com/downloads/vp${version}/Visual_Paradigm_Linux64_InstallFree.tar.gz";
    hash = "sha256-1ifQO7TrEbumumemur5g3e7T3YShEuJUSZKvw2JgnyU=";
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
}
