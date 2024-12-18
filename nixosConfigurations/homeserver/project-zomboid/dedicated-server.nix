{
  lib,
  runCommand,
  fetchSteam,

  autoPatchelfHook,
  makeWrapper,

  steamworks-sdk-redist,
  libgcc,

  jdk17,
}:

# TODO?: use bwrap to create overlayed fs
runCommand "project-zomboid-server" {
  env = {
    content = fetchSteam {
      name = "project-zomboid-server-content";
      appId = "380870";
      depotId = "380871";
      manifestId = "7269353596609305518";
      hash = "sha256-dr0ULXui58/Bacnt3a090mWwWechhV3BRnmL2SFEkD4=";
    };
    content_linux = fetchSteam {
      name = "project-zomboid-server-linux-content";
      appId = "380870";
      depotId = "380873";
      manifestId = "4853909597474362594";
      hash = "sha256-HBzRhaX51O5urSDyb3f/8EiU3WNMd9SpzKIhHJ4sOR4=";
    };
  };

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
  ];

  buildInputs = [
    libgcc.lib
  ];

  # to avoid patching unnecessary stuff
  env.dontAutoPatchelf = 1;

  meta = {
    description = "Prject Zomboid Dedicated Server";
    homepage = "https://steamdb.info/app/380870/depots";
    license = lib.licenses.unfree;
    platforms = [ "x86_64-linux" ];
    mainProgram = "start-zomboid-server";
  };
} ''
  mkdir -p $out
  chmod u+w $out

  # goddamn CRLF is gonna be the death of me
  MODULES=$(sed $content_linux/jre64/release -e '
    /^MODULES="\(.*\)"\r\?$/!d
    s//\1/
    s/ /,/g
  ')
  ${lib.getExe' jdk17 "jlink"} \
    --module-path ${jdk17}/lib/openjdk/jmods \
    --add-modules $MODULES \
    --output $out/jre64

  # would prefer to symlink, especially media (5G!!), but it doesn't like that
  for path in $content_linux/* $content/*; do
    case "$(basename "$path")" in
      jre64|java| \
      ProjectZomboid32.json|start-server.sh) # if these end up being required, it's probably an error
        continue ;;
    esac
    cp -r --no-preserve=all -t $out "$path"
  done

  # hardcode java classpaths
  for jar in $content_linux/java/*; do
    sed -i $out/ProjectZomboid64.json -e "s|java/$(basename "$jar")|$content_linux/\0|"
  done
  sed -i $out/ProjectZomboid64.json -e 's|"java/|"'$content'/java/|g'

  chmod +x $out/ProjectZomboid64

  # mimics 64-bit branch of start-server.sh:
  # - linux64 is statically resolved by patchelf
  # - jre64/lib/amd64 doesn't exist anywhere (original or custom jre)
  # - looks like natives and . aren't required
  # - should generally be run in $out but left out to allow for overlay stuff
  makeWrapper $out/ProjectZomboid64 $out/bin/start-zomboid-server \
    --prefix PATH : $out/jre64/bin \
    --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [ steamworks-sdk-redist ]} \
    --suffix LD_PRELOAD libjsig.so # not sure if this is necessary

  addAutoPatchelfSearchPath $content_linux/linux64
  autoPatchelf -- $out/ProjectZomboid64
''
