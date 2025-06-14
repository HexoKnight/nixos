# Create a symbolic link at LINKPATH pointing to REALPATH:
#
# if LINKPATH is an empty dir or missing:
#     simply create a symlink as normal
# else if REALPATH is an empty dir or missing:
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

    let real_path = $REALPATH | path expand --no-symlink
    let link_path = $LINKPATH | path expand --no-symlink

    if (readlink $link_path) == $real_path {
        log $"'($link_path)' already correctly linked to '($real_path)'"
        return
    }

    if (ensure_available $link_path) {
        log $"'($link_path)' empty..."

        mkdir (
            if $create_dir {
                $real_path
            } else {
                $real_path | path dirname
            }
        )
    } else if not $real.exists {
        log $"'($link.path)' not empty but '($real.path)' is so moving the former to the latter..."

        create_parents $real.path
        # no `--no-target-directory` unfortunately
        mv $link_path $real_path
    } else {
        # even if quiet
        print $"files present at both the linked path \('($link_path)') and real path \('($real_path)')"

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
        numbered_backup $real_path
        mv $link_path $real_path
    }

    log $"linking '($link_path)' to '($real_path)'..."
    link $real_path $link_path
    log $"successfully linked '($link_path)' to '($real_path)'"
}

# check if no file exists then make parent directories
# or if it is an empty directory then delete it
def ensure_available [path: path]: nothing -> bool {
    if not ($path | path exists) {
        mkdir ($path | path dirname)
        return true
    }
    # ls output is empty only for empty directories:
    # - non-empty directories list their contents
    # - other file types are listed themselves as a 1-element list
    if (ls --all $path | is-empty) {
        # can only delete empty dirs so probably no race condition??
        rm $path
        return true
    }
    return false
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
