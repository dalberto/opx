function __opx_token --description "Print a service account token from Keychain or a provisioned Linux file"
    argparse --name "opx token" --max-args 1 h/help -- $argv; or return 2
    set -q _flag_help; and __opx_usage token; and return 0
    set -l service $argv[1]
    if test -z "$service"
        __opx_can_pick; or begin
            __opx_usage token --error
            return 2
        end
        set service (__opx_list keychain | __opx_pick token "Keychain service" | cut -f1); or return 1
    end
    if test (uname -s) = Linux
        set -l file (__opx_token_file "$service"); or return 1
        set -l token (string collect <"$file")
        if test -z "$token"; or test (count $token) -ne 1; or string match -qr '\s' -- "$token"
            __opx_err token "empty or malformed token file '$file'"
            return 1
        end
        printf '%s\n' "$token"
        return 0
    end
    security find-generic-password -s $service -w 2>/dev/null
    or begin
        __opx_err token "no Keychain token '$service'"
        return 1
    end
end
