# both commands should fail if tofi doesn't get an input (exit code 1)
def choose [prompt: string]: list<string> -> string {
  str join "\n" |
  ^tofi --prompt-text=($prompt) |
  into string
}
def choose-index [prompt: string]: [
  list<string> -> int
] {
  str join "\n" |
  ^tofi --prompt-text=($prompt) --print-index=true |
  into int
}

def main []: nothing -> nothing {
  #load-runtime

  let types = {
    "sinks": {
      type: "sink"
    }
    "sources": {
      type: "source"
      filter: { $in.monitor_source | is-empty }
    }
    "sources (extra)": {
      type: "source"
    }
  }

  let selection = $types | columns | choose "type: "

  let result = $types | get $selection
  let type = $result.type
  let filter = $result.filter? | default {|| { true } }

  let default_device = pactl $"get-default-($type)"

  let devices = pactl --format json list $"($type)s" |
    from json |
    where $filter

  # 1-based index
  let index = $devices |
    each {
      let prefix = if $in.name == $default_device { "* " } else { "" }
      $prefix + $in.description
    } |
    choose-index "device: "

  let device = $devices | get ($index - 1)

  pactl $"set-default-($type)" $device.name
}
