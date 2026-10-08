function __opx_pick --description "fzf picker over TSV on stdin; prints chosen lines"
    # __opx_pick [--multi] [--new] [--hide-key] PROMPT HEADER
    #   --multi     Tab to select several
    #   --new       Enter on a query with no match prints "<TAB><query>" (new value)
    #   --hide-key  don't display the first column (e.g. item ids)
    # Callers must check `__opx_can_pick` first; this never runs headless.
    argparse multi new hide-key -- $argv; or return 2
    set -l opts --height=40% --reverse --delimiter=\t --tabstop=4 \
        --prompt="$argv[1]> " --header="$argv[2]"
    set -q _flag_multi; and set -a opts --multi
    set -q _flag_hide_key; and set -a opts --with-nth=2..
    set -q _flag_new; and set -a opts --print-query
    # Read candidates here: inside (…) fzf would not see this function's stdin
    # and would fall back to listing files.
    set -l lines
    while read -l line
        set -a lines $line
    end
    test (count $lines) -gt 0; or return 1
    set -l out (printf '%s\n' $lines | fzf $opts)
    set -l rc $status
    test $rc -eq 130; and return 1  # Esc / Ctrl-C
    if set -q _flag_new
        # line 1 is the query; the rest are selections
        if test (count $out) -ge 2
            printf '%s\n' $out[2..]
        else if test -n "$out[1]"
            printf '\t%s\n' $out[1]
        else
            return 1
        end
        return 0
    end
    test $rc -eq 0; or return 1
    printf '%s\n' $out
end
