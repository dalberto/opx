function __opx_get --description "Read a secret from a 1Password item field"
    # opx get NAME [-v VAULT] [-f FIELD] [-c] [--as SERVICE]
    # FIELD defaults to the item's first concealed field. -c copies instead of printing.
    argparse --max-args 1 h/help 'v/vault=' 'f/field=' c/copy 'a/as=' -- $argv; or return
    if set -q _flag_help; or test (count $argv) -ne 1
        echo "usage: opx get NAME [-v VAULT] [-f FIELD] [-c] [--as SERVICE]

Print a secret from 1Password item NAME to stdout.

  -v, --vault VAULT   vault (default: Dev)
  -f, --field FIELD   field label/id (default: item's first concealed field)
  -c, --copy          copy to clipboard (no trailing newline) instead of printing
  -a, --as SERVICE    read headlessly as the service account whose token is in
                      Keychain SERVICE (see opx token)
  -h, --help          show this help

examples:
  set -x OPENAI_API_KEY (opx get openai-api-key)
  opx get stripe -f secret-key -v Production -c
  opx get slack-webhook -v my-agents --as my-agents-op-sa

see also: opx set, opx sa, opx agent, opx snippet" >&2
        set -q _flag_help; and return 0; or return 2
    end
    set -l name $argv[1]
    set -l vault Dev
    set -q _flag_vault; and set vault $_flag_vault
    set -l field ""
    set -q _flag_field; and set field $_flag_field

    if set -q _flag_as
        set -lx OP_SERVICE_ACCOUNT_TOKEN (opx token $_flag_as); or return
    end
    set -l item (op item get $name --vault $vault --format json); or return
    set -l value (printf '%s\n' $item | jq -er --arg f "$field" '
        [.fields[]? | select(if $f == "" then .type == "CONCEALED"
                             else .id == $f or .label == $f end)]
        | first // error("no matching field")
        | .value // error("field is empty")' | string collect)
    or begin
        echo "opx get: $vault/$name: no "(test -n "$field"; and echo "field '$field'"; or echo "concealed field")" with a value" >&2
        return 1
    end

    if set -q _flag_copy
        printf %s $value | pbcopy
    else
        printf '%s\n' $value
    end
end
