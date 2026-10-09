function __opx_set --description "Store a masked secret in a 1Password item field"
    argparse --name "opx set" --max-args 1 h/help 'v/vault=' 'f/field=+' 'category=' \
        P/paste g/generate 'length=' -- $argv; or return 2
    set -q _flag_help; and __opx_usage set; and return 0

    set -l vault (__opx_default_vault)
    set -q _flag_vault; and set vault $_flag_vault
    # -f NAME prompts for a masked value; -f NAME=VALUE stores plain text.
    # No -f: the item's first concealed field.
    set -l specs $_flag_field
    test (count $specs) -gt 0; or set specs ''
    set -l category "API Credential"
    set -q _flag_category; and set category $_flag_category
    set -l masked (string match -v -- '*=*' $specs)
    if set -q _flag_paste; and set -q _flag_generate
        __opx_err set "--paste and --generate don't mix"
        return 2
    end
    if set -q _flag_paste; and test (count $masked) -ne 1
        __opx_err set "--paste fills exactly one masked field; got "(count $masked)
        return 2
    end
    set -l genlen 32
    if set -q _flag_length
        set genlen $_flag_length
        string match -q -r '^[1-9][0-9]*$' -- $genlen; or begin
            __opx_err set "--length must be a number"
            return 2
        end
    end

    if test -z "$argv[1]"; and not __opx_can_pick
        __opx_usage set --error
        return 2
    end
    set -l scope
    set -q _flag_vault; and set scope --scope $_flag_vault
    set -l ref (__opx_resolve set --new $scope --default $vault $argv[1]); or return
    set -l r (string split \t -- $ref)
    set vault $r[3]
    set -l name (test -n "$r[1]"; and echo $r[1]; or echo $r[2])  # id, or new title
    set -l label $r[2]
    if test -n "$r[4]"; and not set -q _flag_field
        set specs $r[4]                                          # field from op://
        set masked $specs
    end

    set -l item
    test -n "$r[1]"; and set item (op item get $r[1] --vault $vault --format json | string collect)
    set -l verbose (isatty stderr; and echo 1)

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
            set -l shown (test -n "$sp"; and echo $sp; or echo '<default>')
            set -l secret
            if set -q _flag_paste
                set secret (pbpaste | string collect)
                printf '' | pbcopy                      # don't leave it on the clipboard
            else if set -q _flag_generate
                set secret (LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c $genlen | string collect)
            else
                read --silent --prompt-str "$vault/$label/$shown: " secret; or return 1
            end
            if test -z "$secret"
                __opx_err set "empty secret for $shown, aborting"
                return 1
            end
            if test -n "$verbose"
                # Last 4 characters, to catch a wrong paste; and what it replaces.
                set -l old (printf '%s' "$item" | jq -r --arg f "$sp" (__opx_jq)'
                    (if $f == "" then concealed | first else field($f) end) | .value // empty' 2>/dev/null)
                set -l note "$shown: "(__opx_tail $secret)
                test -n "$old"; and set note "$note (was "(__opx_tail $old)")"
                set -q _flag_generate; and set note "$shown: generated $genlen chars"
                __opx_err set $note
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
