#!/bin/bash
# Basic Setup
SESSION="cmdrFRANKLYsSession"

# Exit if session already exists
tmux has-session -t $SESSION 2>/dev/null && exit 0

# Create new detached session with one window
tmux new-session -d -s $SESSION

# Enable Mouse Mode
tmux set-option -t $SESSION mouse on

# Bind Keys
tmux bind -n M-Left  select-pane -L
tmux bind -n M-Right select-pane -R
tmux bind -n M-Up    select-pane -U
tmux bind -n M-Down  select-pane -D

# Monochrome Colors
tmux set-option -t $SESSION pane-border-style "fg=white,bg=black"
tmux set-option -t $SESSION pane-active-border-style "fg=white,bg=black"
tmux set-option -t $SESSION pane-border-status-style "fg=white,bg=black"
tmux set-option -t $SESSION pane-border-status top
tmux set-option -t $SESSION pane-border-format "#{pane_title}"

# Get Statusbar Info
LOCAL_IP=$(ip -4 addr show scope global | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n1)
OPENVPN_IP=$(ip -4 addr show dev tun0 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n1)
TAILSCALE_IP=$(tailscale ip -4 2>/dev/null | head -n1)
STATUS_LEFT="IP: $LOCAL_IP | VPN: $OPENVPN_IP | TS: $TAILSCALE_IP"

# Set Statusbar Info
tmux set-option -t $SESSION status-position bottom
tmux set-option -t $SESSION status-left-length 100
tmux set-option -t $SESSION status-style "fg=white,bg=black"
tmux set-option -t $SESSION status-left "$STATUS_LEFT"
tmux set-option -t $SESSION status-right '#[fg=white,bg=black]%H:%M #[default]| #[fg=white,bg=black]%d/%m/%Y'

# Split Panes (3x3)
tmux split-window -h -t $SESSION:0.0
tmux select-pane -t $SESSION:0.0
tmux split-window -v -t $SESSION:0.0
tmux split-window -v -t $SESSION:0.0
tmux select-pane -t $SESSION:0.3
tmux split-window -v -t $SESSION:0.3
tmux split-window -v -t $SESSION:0.3

# Exit
exit 0
