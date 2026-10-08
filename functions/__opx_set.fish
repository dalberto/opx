function __opx_set --description "Store a masked secret in a 1Password item field"
    argparse --name "opx set" --max-args 1 h/help 'v/vault=' 'f/field=' 'category=' -- $argv; or return 2
    set -q _flag_help; and __opx_usage set; and return 0

    set -l name $argv[1]
    set -l vault (__opx_default_vault)
    set -q _flag_vault; and set vault $_flag_vault
    set -l field "$_flag_field"
    set -l category "API Credential"
    set -q _flag_category; and set category $_flag_category

    if test -z "$name"
        __opx_can_pick; or begin; __opx_usage set --error; return 2; end
        set -l pick (__opx_list items $_flag_vault \
            | __opx_pick --new --hide-key item "Enter: update · type a new name to create in $vault")
        or return 1
        set -l cols (string split \t -- $pick[1])
        if test -z "$cols[1]"
            set name $cols[2]                  # new item, in $vault
        else
            set name $cols[1]; set vault $cols[3]  # existing: id + its vault
        end
    end

    set -l item (op item get $name --vault $vault --format json 2>/dev/null | string collect)
    set -l label (test -n "$item"; and echo (printf '%s' $item | jq -r .title); or echo $name)

    read --silent --prompt-str "$vault/$label/"(test -n "$field"; and echo $field; or echo '<default>')": " secret
    or return 1
    if test -z "$secret"
        __opx_err set "empty secret, aborting"
        return 1
    end

    # Set the matching field, else the first concealed one when no FIELD was
    # given, else append a new concealed field labeled FIELD.
    set -l prog (__opx_jq)'
        ($s) as $v
        | (.fields // []) as $fs
        | ([$fs | to_entries[]
             | select(if $f == "" then .value.type == "CONCEALED"
                      else .value.id == $f or .value.label == $f end)
             | .key] | first) as $i
        | if $i != null then .fields[$i].value = $v
          elif $f == "" then error("no concealed field; pass -f FIELD")
          else .fields = $fs + [{label: $f, type: "CONCEALED", value: $v}] end'

    if test -n "$item"
        printf '%s' $item \
            | jq --arg f "$field" --rawfile s (printf %s $secret | psub -F) $prog \
            | op item edit (printf '%s' $item | jq -r .id) --vault $vault >/dev/null
    else
        op item template get $category \
            | jq --arg t $name --arg f "$field" --rawfile s (printf %s $secret | psub -F) \
                ".title = \$t | .fields |= map(select(.type == \"CONCEALED\" or (.value // \"\") != \"\")) | $prog" \
            | op item create --vault $vault - >/dev/null
    end
    or begin
        __opx_err set "failed to write $vault/$label"
        return 1
    end
    __opx_list --flush
    __opx_err set "saved $vault/$label"
end
