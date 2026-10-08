function opx --description "1Password helpers for humans and headless agents"
    set -l cmd $argv[1]
    set -e argv[1]
    switch "$cmd"
        case '' help -h --help
            __opx_usage $argv
        case set get mv vault sa token run agent snippet
            __opx_$cmd $argv
        case '*'
            __opx_err $cmd "unknown command (see: opx help)"
            return 2
    end
end
