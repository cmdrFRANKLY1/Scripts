#!/bin/bash
SESSION="my_session"

if tmux has-session -t $SESSION 2>/dev/null; then
  tmux attach -t $SESSION
  exit 0
fi

tmux new-session -d -s $SESSION

tmux set-option -t $SESSION mouse on

# Bind arrow keys with Alt to navigate panes
tmux bind -n M-Left select-pane -L
tmux bind -n M-Right select-pane -R
tmux bind -n M-Up select-pane -U
tmux bind -n M-Down select-pane -D

# Monochrome style for borders and status
tmux set-option -t $SESSION pane-border-style "fg=white,bg=black"
tmux set-option -t $SESSION pane-active-border-style "fg=white,bg=black"
tmux set-option -t $SESSION pane-border-status-style "fg=white,bg=black"
tmux set-option -t $SESSION pane-border-status top
tmux set-option -t $SESSION pane-border-format "#{pane_title}"

# Status bar with IPs
LOCAL_IP=$(ip -4 addr show scope global | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n1)
OPENVPN_IP=$(ip -4 addr show dev tun0 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n1)
TAILSCALE_IP=$(tailscale ip -4 2>/dev/null | head -n1)
STATUS_LEFT="IP: $LOCAL_IP | VPN: $OPENVPN_IP | TS: $TAILSCALE_IP"

tmux set-option -t $SESSION status-position bottom
tmux set-option -t $SESSION status-left-length 100
tmux set-option -t $SESSION status-style "fg=white,bg=black"
tmux set-option -t $SESSION status-left "$STATUS_LEFT"
tmux set-option -t $SESSION status-right '#[fg=white,bg=black]%H:%M #[default]| #[fg=white,bg=black]%d/%m/%Y'

# Create 3 vertical panes (columns)
tmux split-window -h -t $SESSION:0.0
tmux split-window -h -t $SESSION:0.0

# Now split each of the 3 panes vertically twice to get 3 rows per column

for pane in 0 1 2; do
  tmux select-pane -t $SESSION:0.$pane
  tmux split-window -v -t $SESSION:0.$pane
  tmux split-window -v -t $SESSION:0.$pane
done

# Set pane titles
for pane in $(tmux list-panes -t $SESSION -F "#{pane_id}"); do
  index=$(tmux display-message -p -t $pane "#{pane_index}")
  cmd=$(tmux display-message -p -t $pane "#{pane_current_command}")
  cwd=$(tmux display-message -p -t $pane "#{pane_current_path}")
  tmux select-pane -t $pane -T "Pane $index: $cmd - $cwd"
done

tmux attach -t $SESSION

exit 0
