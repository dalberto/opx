function __opx_token --description "Print a service account token stored in the macOS Keychain"
    argparse --max-args 1 h/help -- $argv; or return
    if set -q _flag_help; or test (count $argv) -ne 1
        echo "usage: opx token SERVICE

Print the 1Password service account token stored in Keychain SERVICE
(as stored by opx sa --keychain / opx agent). First read from a new binary
prompts once (\"Always Allow\").

examples:
  set -x OP_SERVICE_ACCOUNT_TOKEN (opx token my-agents-op-sa)

see also: opx run, opx sa, opx agent, opx snippet" >&2
        set -q _flag_help; and return 0; or return 2
    end
    security find-generic-password -s $argv[1] -w
    or begin
        echo "opx token: no Keychain item '$argv[1]'" >&2
        return 1
    end
end
