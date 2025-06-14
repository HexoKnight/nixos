# Create a symbolic link at LINKPATH pointing to REALPATH:
#
# if both LINKPATH and REALPATH are empty dirs:
#     remove LINKPATH
# else if one *PATH is an empty dir while the other exists and isn't empty:
#     remove the empty dir
#
# if LINKPATH doesn't exist:
#     simply create a symlink as normal
# else if REALPATH doesn't exist:
#     move LINKPATH to REALPATH and symlink as normal
# else if `--no-backup` is not passed:
#     backup REALPATH, move LINKPATH to REALPATH and symlink as normal
# else:
#     fail with a non-zero exit code
def main [
    REALPATH: path,
    LINKPATH: path,
    --quiet (-q) # Suppress less important output
    --no-backup # Disable backup (will fail instead)
    --create-dir (-d) # When neither path exists, create an empty dir at REALPATH
]: nothing -> nothing {
    #load-runtime
    # external commands should only be called from `run`
    $env.OLDPATH = $env.PATH
    $env.PATH = []

    def log [msg: string] {
        if not $quiet {
            print $msg
        }
    }

    mut real = get_info $REALPATH
    mut link = get_info $LINKPATH

    if $link.path == $real.path {
        log $"both paths are the same: '($link.path)'"
        return
    }
    if ($link.path | path type) == 'symlink' and (readlink $link.path) == $real.path {
        log $"'($link.path)' already correctly linked to '($real.path)'"
        return
    }

    if ($link.empty_dir) and ($real.empty_dir) {
        rm $link.path
        $link.exists = false
    } else if ($link.empty_dir) and ($real.exists) {
        rm $link.path
        $link.exists = false
    } else if ($real.empty_dir) and ($link.exists) {
        rm $real.path
        $real.exists = false
    }
    # after this, empty_dir doesn't matter

    if not $link.exists {
        log $"'($link.path)' empty..."

        mkdir (
            if $create_dir {
                $real.path
            } else {
                $real.path | path dirname
            }
        )
        create_parents $link.path
    } else if not $real.exists {
        log $"'($link.path)' not empty but '($real.path)' is so moving the former to the latter..."

        create_parents $real.path
        # no `--no-target-directory` unfortunately
        mv $link.path $real.path
    } else {
        # even if quiet
        print $"files present at both the linked path \('($link.path)') and real path \('($real.path)')"

        if $no_backup {
            error make {
                msg: "Enable backup or remove one of the sets of files",
                label: {
                    text: "backing up disabled",
                    span: (metadata $no_backup).span,
                },
            }
        }

        print "backing up the real path and using files from the linked path"
        numbered_backup $real.path
        mv $link.path $real.path
    }

    log $"linking '($link.path)' to '($real.path)'..."
    link $real.path $link.path
    log $"successfully linked '($link.path)' to '($real.path)'"
}

def get_info [path: path]: nothing -> record<path: path, exists: bool, empty_dir: bool> {
    let path = $path | path expand --no-symlink
    let exists = $path | path exists --no-symlink
    {
        path: $path,
        exists: $exists,
        empty_dir: ($exists and (is_empty_dir $path)),
    }
}

def create_parents [path: path]: nothing -> nothing {
    let $parent_path = $path | path dirname
    if not ($parent_path | path exists) {
        mkdir $parent_path
    }
}

def is_empty_dir [path: path]: nothing -> bool {
    # ls output is empty only for empty directories:
    # - non-empty directories list their contents
    # - other file types are listed themselves as a 1-element list
    ls --all $path | is-empty
}

def numbered_backup [path: path, --suffix: string = '~']: nothing -> nothing {
    let backup_path: path = 1..
        | into string
        | prepend ""
        | each { $path + $suffix + $in }
        | where not ($it | path exists)
        | first

    mv $path $backup_path
}


# cannot stream output
def --wrapped run [cmd: string, ...args: string]: any -> string {
    let output = do {
        $env.PATH = $env.OLDPATH
        run-external $cmd ...$args
    } | complete

    if $output.exit_code != 0 {
        error make --unspanned {
            msg: ([
                "External command failed:"
                ($args | each { $"'($in)'" } | prepend $cmd | str join ' ')
                $"failed with an exit code of ($output.exit_code) and output:"
                ($output.stdout | str trim)
                ($output.stderr | str trim)
            ] | where $it != "" | str join "\n")
        }
    }

    print --stderr --no-newline --raw $output.stderr
    return $output.stdout
}

def link [target: path, link_name: path] {
    run ln -s -T $target $link_name
}

def readlink [link: path] {
    run readlink --verbose --no-newline $link
}
