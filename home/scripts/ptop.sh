# ps -eo pid=,%cpu=,comm= --sort=-%cpu | awk '$3 != "ps"' | head -n 5 | while read p c n; do printf "\n\033[1;31m[ %s%% CPU ]\033[0m \033[1m%s\033[0m (PID: %s)\n" "$c" "$n" "$p"; pstree -g 3 -w -p "$p" | sed -E 's#/nix/store/[a-z0-9]{32}-##g; s#/etc/profiles/per-user/synchronous/bin/##g; s#/run/current-system/systemd/lib/##g' | cut -c 1-$COLUMNS; done
# ps -eo pid=,%cpu=,comm= --sort=-%cpu | awk '$3 != "ps" && $3 != "ptop"' | head -n 5 | while read p c n; do printf "\n\033[1;31m[ %s%% CPU ]\033[0m \033[1m%s\033[0m (PID: %s)\n" "$c" "$n" "$p"; pstree -g 3 -w -p "$p" | sed -E 's#/nix/store/[a-z0-9]{32}-##g; s#/etc/profiles/per-user/synchronous/bin/##g; s#/run/current-system/systemd/lib/##g' | cut -c 1-$COLUMNS; done
# ps -eo pid=,%cpu=,comm= --sort=-%cpu | awk '$3 !~ /^(ps|ptop|zsh|alacritty|sh|cut|sed|pstree)$/' | head -n 5 | while read p c n; do printf "\n\033[1;31m[ %s%% CPU ]\033[0m \033[1m%s\033[0m (PID: %s)\n" "$c" "$n" "$p"; pstree -g 3 -w -p "$p" | sed -E 's#/nix/store/[a-z0-9]{32}-##g; s#/etc/profiles/per-user/synchronous/bin/##g; s#/run/current-system/systemd/lib/##g' | cut -c 1-$COLUMNS; done
#!/usr/bin/env bash
# ptop — top CPU consumers, grouped by app (one tree per application)
# usage: ptop [N]   N = number of apps to show (default 5)

N=${1:-5}
W=$(tput cols 2>/dev/null || echo 120)   # truncate width (live terminal, else 120)
NCPU=$(nproc)                            # for normalizing per-core %CPU to machine %

ps -eo pid=,ppid=,%cpu=,comm= \
  | awk -v ncpu="$NCPU" '
      # index every process by pid; rebuild comm (may contain spaces)
      { ppid[$1]=$2; cpu[$1]=$3+0
        c=$4; for (i=5;i<=NF;i++) c=c" "$i; comm[$1]=c }
      END {
        for (p in ppid) {
          # walk up to the app root: highest ancestor still under systemd (pid1 or --user)
          r=p
          while ((ppid[r]+0)>1 && (ppid[r] in ppid) && comm[ppid[r]]!="systemd") r=ppid[r]
          total[r]+=cpu[p]                       # sum CPU across the whole app
          if (hotpid[r]=="" || cpu[p]>hot[r]) { hot[r]=cpu[p]; hotpid[r]=p }  # hottest proc
        }
        for (r in total) if (total[r]>0)       # skip apps using no CPU
          printf "%.1f\t%s\t%s\n", total[r]/ncpu, hotpid[r], comm[r]
      }' \
  | awk -F'\t' '$3 !~ /^(ps|ptop|zsh|alacritty|sh|cut|sed|pstree|awk|kthreadd)$/' \
  | sort -rn \
  | head -n "$N" \
  | while IFS=$'\t' read -r tot hp name; do
      printf "\n\033[1;31m[ %s%% CPU ]\033[0m \033[1m%s\033[0m (PID: %s)\n" "$tot" "$name" "$hp"
      pstree -g 3 -w -p "$hp" \
        | sed -E '
            s#/nix/store/[a-z0-9]{32}-##g
            s#/etc/profiles/per-user/synchronous/bin/##g
            s#/run/current-system/systemd/lib/##g
            s#([0-9]+ [a-z][a-z0-9_-]* )[^ ]*/#\1#
          ' \
        | awk -v w="$W" '{ if (length($0)>w) print substr($0,1,w-1) "…"; else print }'
    done
