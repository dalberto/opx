function __opx_tail --description "Show only the last 4 characters of a secret (…f3Qa)"
    set -l n (string length -- "$argv[1]")
    if test $n -ge 12
        echo "…"(string sub -s -4 -- $argv[1])" ($n chars)"
    else
        echo "($n chars)"
    end
end
