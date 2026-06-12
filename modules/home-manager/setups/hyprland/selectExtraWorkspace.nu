# command should fail if tofi doesn't get an input (exit code 1)
def choose-or-new [
  --prompt: string
  --history-file: path
]: list<string> -> string {
  str join "\n" |
  ^tofi --prompt-text=($prompt) --require-match=false --history-file=($history_file) |
  into string
}

const prefix = "__"
const prefix_len = $prefix | str length

const history_state_path = "tofi-selectExtraWorkspace-history"

def main [--prompt: string]: nothing -> string {
  #load-runtime

  let history_path = $env.XDG_STATE_HOME? |
    default ($nu.home-dir | path join ".local/state") |
    path join $history_state_path

  let extra_workspaces = ^hyprctl workspaces -j |
    from json |
    get name |
    where (str starts-with $prefix) |
    each {str substring $prefix_len..}

  let workspace = $extra_workspaces |
    choose-or-new --prompt=$prompt --history-file $history_path

  $"__($workspace)"
}

def "main goto" []: nothing -> nothing {
  let workspace: string = main --prompt "goto: "

  let dispatcher = [ 'hl.dsp.focus({ workspace = [[name:' $workspace ']] })' ] | str join

  hyprctl dispatch $dispatcher
}

def "main move" []: nothing -> nothing {
  let workspace: string = main --prompt "move to: "

  let dispatcher = [ 'hl.dsp.window.move({ workspace = [[name:' $workspace ']] })' ] | str join

  hyprctl dispatch $dispatcher
}
