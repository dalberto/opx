function __opx_var_name --description "Env var name for a field: __opx_var_name VAULT TITLE FIELD FIELD_COUNT"
    # Single-field item: named after the item. Multi-field: ITEM_FIELD.
    # A leading vault name is dropped (my-agents-aws → AWS_...).
    set -l stem (string replace -r -- "^\Q$argv[1]\E[-_ ]+" '' $argv[2])
    test "$argv[4]" -gt 1; and set stem "$stem $argv[3]"
    set -l var (string upper -- $stem | string replace -r -a '[^A-Z0-9]+' _ | string trim -c _)
    string match -q -r '^[0-9]' -- $var; and set var _$var
    test -n "$var"; or set var SECRET
    echo $var
end
