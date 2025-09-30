# link the appropriate file/dir in /persist/(system|home) to TARGET
# (using mklink internally)
def main [
    TARGET: path
] {
    #load-runtime

    let path = $TARGET | path expand

    # in case sudo resets PATH
    let mklink_bin = (
        which mklink
        | first
        | get path
    )

    if ($path | str starts-with '/home/') {
        exec $mklink_bin $"/persist($path)" $path
    } else {
        exec sudo $mklink_bin $"/persist/system($path)" $path
    }
}
