def main [
    FILE: path
    LINKPATH: path
    REALPATH?: string

    --quiet (-q) # Suppress less important output
    --no-run-multilink (-n) # Don't run multilink after this command finishes
] {
    let parsed = multilink parse-file $FILE
    let default = $parsed.default

    let file = $FILE | path expand --no-symlink

    let default_link = $parsed.default.link
        # append trailing slash if not present
        | str replace -r '/?$' '/'

    let link_path = $LINKPATH | remove-default-root $parsed.default.link

    let real_path = (
        if $REALPATH == null {
            # default to a child of the default link dir with the same basename
            $LINKPATH | path basename
        } else {
            join_paths $parsed.default.real $REALPATH
                | remove-default-root $parsed.default.real
        }
    )

    # TODO: options
    # but the UI is not obvious bc ideally there would be
    # 3 states for each option: true, false, default
    # which nushell boolean switches do not support
    let record = {
        link: $link_path,
        real: $real_path,
    }

    if not $quiet {
        print $"The following record will be added to links in '($FILE)':"
        print $record
    }

    # due to toml format, we could just append the new record without touching
    # the existing file/format, but easier to do this

    open $FILE --raw
    | from toml
    | default [] links
    | update links { append $record }
    | to toml
    | save $FILE --raw --force

    if not $no_run_multilink {
        multilink $FILE --quiet=$quiet
    }
}

def remove-default-root [
    default: string
]: string -> string {
    path expand --no-symlink
    # remove trailing slash if present
    | str replace -r '/$' ''
    | str remove-prefix (
        # append trailing slash if not present
        $default | str replace -r '/?$' '/'
    )
}

def "str remove-prefix" [
    prefix: string
]: string -> string {
    if ($in | str starts-with $prefix) {
        $in | str substring ($prefix | str length)..
    } else {
        $in
    }
}

# see multilink.nu
# I would like to take these out into a separate shared lib in the future
def join_paths [...paths: path]: nothing -> path {
    $paths | where $it != null | each {path expand-tilde} | path join
}
def "path expand-tilde" []: path -> path {
    let path = $in
    if not ($path | str starts-with '~') {
        return $path
    }
    $path
    | path split
    | update 0 { path expand --no-symlink }
    | path join
}
