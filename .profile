# ~/home/<USER>/.profile
#
# This script manages my tmux sessions. 
# The Path to "tmux.sh" is dynamic.
#
# When OUTSIDE tmux:
#  "tmux" checks for existing session named 'my_session'
#  If it doesn't exist, it will create and attach to it
#
# When INSIDE tmux:
#  "exit" detaches from tmux instead of closing panes
#  'tmux quit' will actually exit the session
#  other commands pass through normally


if [ -z "$TMUX" ]; then
    tmux() {
        if ! command tmux has-session -t my_session 2>/dev/null; then
            /PATH/TO/TMUX.SH
        fi
        exec command tmux attach -t my_session
    }
else
    if [[ $- == *i* ]]; then
        exit() { tmux detach; }
    fi

    tmux() {
        if [ "$1" = "quit" ]; then
            session_name=$(tmux display-message -p '#S')
            tmux kill-session -t "$session_name"
        else
            command tmux "$@"
        fi
    }
fi
