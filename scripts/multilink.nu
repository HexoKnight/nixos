# Run mklink multiple times according to the toml spec in FILE.
#
# The toplevel `links` list contains a record for each link where:
# - `real` and `link` specify REALPATH and LINKPATH in mklink respectively
# - `options` specifies the options to be passed to mklink
# A toplevel `default` record provides defaults for each `links` record.
# Relative paths are relative to their otherwise default value.
# The built-in defaults for `link` and `real` are the parent directory of FILE.
#
# For example:
# ```toml
# [default]
# # real would default to: '<FILE>/..'
# link = "/links"
#
# [default.options]
# no_backup = true
#
# [[links]]
# real = "/this/far/away/dir"
# # this would end up being: '/links/link_here'
# link = "link_here"
#
# [links.options]
# create_dir = true
#
# [[links]]
# # this would end up being: '<FILE>/../path/relative/to/FILE/hello.txt'
# real = "path/relative/to/FILE/hello.txt"
# link = "/ignore/defaults/and/link/here/hello.txt"
# ```
def main [
    FILE: path
    --quiet (-q) # Suppress less important output
] {
    # only time where we want full (ie. absolute) expansion
    let file = $FILE | path expand --no-symlink

    let config = open $file --raw | from toml

    # if FILE is a symlink, this is the parent of the link not the real file
    let file_dir = $file | path dirname

    mut default = $config.default? | default {}
    $default.real = join_paths $file_dir $default.real?
    $default.link = join_paths $file_dir $default.link?

    let links = $config.links? | default [] | default {} options

    $links | multilink direct $default --quiet=$quiet
}

# Bypass specifying FILE and directly pass in required info.
#
# Situations where the parent dir of FILE would be used, will instead use the
# current directory.
#
# every record in the signature refers to:
# record<real: path, link: path, options: record<mklink options>>
# with all optional except `real` and `link` in the input
export def "multilink direct" [
    default: record
    --quiet (-q) # Suppress less important output
]: table<real: path, link: path> -> nothing {
    each {|entry|
        let real_path = join_paths $default.real? $entry.real
        let link_path = join_paths $default.link? $entry.link

        let quiet = $quiet
        let no_backup = $entry.options.no_backup? | default $default.options.no_backup? | default false
        let create_dir = $entry.options.create_dir? | default $default.options.create_dir? | default false

        (mklink $real_path $link_path
            --quiet=$quiet
            --no-backup=$no_backup
            --create-dir=$create_dir
        )
    }
    ignore
}

def join_paths [...paths: path]: nothing -> path {
    $paths | where $it != null | each {path expand-tilde} | path join
}

# exists to ensure that all absolute paths (such as ~/<...>)
# are properly treated as such
# `[default ~/other] | path join` -> `default/~/other`
# `[default ~/other] | each {path expand-tilde} | path join` -> `<$HOME>/other`
#
# can't use `path expand` because that expands relative paths into absolute ones
# but I'd rather a `path expand --relative` or similar
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
