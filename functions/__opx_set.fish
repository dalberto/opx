function __opx_set --description "Store a masked secret in a 1Password item field"
    argparse --name "opx set" --max-args 1 h/help 'v/vault=' 'f/field=+' 'category=' -- $argv; or return 2
    set -q _flag_help; and __opx_usage set; and return 0

    set -l name $argv[1]
    set -l vault (__opx_default_vault)
    set -q _flag_vault; and set vault $_flag_vault
    # -f NAME prompts for a masked value; -f NAME=VALUE stores plain text.
    # No -f: the item's first concealed field.
    set -l specs $_flag_field
    test (count $specs) -gt 0; or set specs ''
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

    set -l spec_args
    set -l secrets
    for sp in $specs
        if string match -q '*=*' -- $sp
            set -l kv (string split -m1 = -- $sp)
            if test -z "$kv[1]"
                __opx_err set "bad field '$sp' (use NAME or NAME=VALUE)"
                return 2
            end
            set -a spec_args $kv[1] STRING $kv[2]
        else
            read --silent --prompt-str "$vault/$label/"(test -n "$sp"; and echo $sp; or echo '<default>')": " secret
            or return 1
            if test -z "$secret"
                __opx_err set "empty secret for "(test -n "$sp"; and echo $sp; or echo '<default>')", aborting"
                return 1
            end
            set -a spec_args "$sp" CONCEALED ''
            set -a secrets $secret
        end
    end
    set -l spec (jq -nc --args '[$ARGS.positional as $p | range(0; $p | length; 3) as $i
        | {label: $p[$i], type: $p[$i + 1], value: $p[$i + 2]}]' $spec_args)

    # Concealed values arrive as JSON strings through a fifo, in prompt order.
    # Each update sets the matching field (by id or label), else the first
    # concealed field for the default '', else appends a new field.
    set -l prog '
        (reduce range(0; $spec | length) as $k ({u: [], n: 0};
            if $spec[$k].type == "CONCEALED"
            then .u += [$spec[$k] + {value: $S[.n]}] | .n += 1
            else .u += [$spec[$k]] end) | .u) as $updates
        | reduce $updates[] as $x (.;
            (.fields // []) as $fs
            | ([$fs | to_entries[]
                 | select(if $x.label == "" then .value.type == "CONCEALED"
                          else .value.id == $x.label or .value.label == $x.label end)
                 | .key] | first) as $i
            | if $i != null then .fields[$i].value = $x.value
              elif $x.label == "" then error("no concealed field; pass -f FIELD")
              else .fields = $fs + [{label: $x.label, type: $x.type, value: $x.value}] end)'
    set -l secret_json (begin
        for sec in $secrets
            printf %s $sec | jq -Rs .
        end
    end | string collect)

    if test -n "$item"
        printf '%s' $item \
            | jq --argjson spec $spec --slurpfile S (printf '%s\n' $secret_json | psub -F) $prog \
            | op item edit (printf '%s' $item | jq -r .id) --vault $vault >/dev/null
    else
        # New item: fill fields, then drop the template's empty ones.
        op item template get $category \
            | jq --arg t $name --argjson spec $spec --slurpfile S (printf '%s\n' $secret_json | psub -F) \
                ".title = \$t | $prog | .fields |= map(select((.value // \"\") != \"\"))" \
            | op item create --vault $vault - >/dev/null
    end
    or begin
        __opx_err set "failed to write $vault/$label"
        return 1
    end
    __opx_list --flush
    __opx_err set "saved $vault/$label"
end
