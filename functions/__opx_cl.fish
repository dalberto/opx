function __opx_cl --description "Parse the opx commandline for completions: __opx_cl pos | opt FLAG..."
    # pos       print positional args after `opx SUBCOMMAND`
    # opt F...  print the value of the last of the given flags (e.g. -v --vault)
    # The single list of value-taking flags lives here.
    set -l value_flags -v --vault -f --field --category -a --as -k --keychain \
        -s --save-vault -e --expires -i --item -m --move -S --store --to --from
    set -l tokens (commandline -xpc)[3..]
    set -l mode $argv[1]
    set -l want $argv[2..]
    set -l pos
    set -l val
    set -l i 1
    while test $i -le (count $tokens)
        set -l t $tokens[$i]
        if contains -- $t $value_flags
            set i (math $i + 1)
            contains -- $t $want; and set -q tokens[$i]; and set val $tokens[$i]
        else if string match -q -r -- '^--[^=]+=' $t
            set -l kv (string split -m1 = -- $t)
            contains -- $kv[1] $want; and set val $kv[2]
        else if not string match -q -- '-*' $t
            set -a pos $t
        end
        set i (math $i + 1)
    end
    switch $mode
        case pos
            test (count $pos) -gt 0; and printf '%s\n' $pos
        case opt
            test -n "$val"; and echo $val
    end
end
