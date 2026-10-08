function __opx_set --description "Store a masked secret in a 1Password item field"
    # opx set NAME [-v VAULT] [-f FIELD] [-t CATEGORY]
    # Creates the item if missing, otherwise sets FIELD (adding it if absent).
    # FIELD defaults to the item's first concealed field (e.g. credential, password).
    # The secret travels via pipes as JSON — never argv or shell history.
    argparse --max-args 1 h/help 'v/vault=' 'f/field=' 't/type=' -- $argv; or return
    if set -q _flag_help; or test (count $argv) -ne 1
        echo "usage: opx set NAME [-v VAULT] [-f FIELD] [-t CATEGORY]

Prompt (masked) for a secret and store it in 1Password item NAME.
Creates the item if missing; otherwise sets FIELD, adding it if absent.

  -v, --vault VAULT     vault (default: Dev)
  -f, --field FIELD     field label/id (default: item's first concealed field,
                        e.g. credential, password)
  -t, --type CATEGORY   category for new items (default: API Credential)
  -h, --help            show this help

examples:
  opx set openai-api-key
  opx set stripe -f secret-key -v Production

see also: opx get, opx sa, opx agent, opx snippet" >&2
        set -q _flag_help; and return 0; or return 2
    end
    set -l name $argv[1]
    set -l vault Dev
    set -q _flag_vault; and set vault $_flag_vault
    set -l category "API Credential"
    set -q _flag_type; and set category $_flag_type
    set -l field ""
    set -q _flag_field; and set field $_flag_field

    set -l item (op item get $name --vault $vault --format json 2>/dev/null)
    set -l exists $status

    read --silent --prompt-str "$vault/$name/"(test -n "$field"; and echo $field; or echo '<default>')": " secret
    or return
    if test -z "$secret"
        echo "opx set: empty secret, aborting" >&2
        return 1
    end

    # Set the matching field (by id or label), else the first concealed one when
    # no FIELD was given, else append a new concealed field labeled FIELD.
    set -l prog '
        ($s) as $v
        | (.fields // []) as $fs
        | ([$fs | to_entries[]
             | select(if $f == "" then .value.type == "CONCEALED"
                      else .value.id == $f or .value.label == $f end)
             | .key] | first) as $i
        | if $i != null then .fields[$i].value = $v
          elif $f == "" then error("no concealed field; pass -f FIELD")
          else .fields = $fs + [{label: $f, type: "CONCEALED", value: $v}] end'

    if test $exists -eq 0
        printf '%s\n' $item \
            | jq --arg f "$field" --rawfile s (printf %s $secret | psub -F) $prog \
            | op item edit (printf '%s\n' $item | jq -r .id) --vault $vault >/dev/null
    else
        op item template get $category \
            | jq --arg t $name --arg f "$field" --rawfile s (printf %s $secret | psub -F) ".title = \$t | .fields |= map(select(.type == \"CONCEALED\" or .value != \"\")) | $prog" \
            | op item create --vault $vault - >/dev/null
    end
    or begin
        echo "opx set: failed to write $vault/$name" >&2
        return 1
    end
    echo "opx set: saved $vault/$name" >&2
end
