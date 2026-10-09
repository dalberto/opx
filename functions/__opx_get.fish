function __opx_get --description "Read a secret from a 1Password item field"
    # Split off `-- CMD...` for --env before argparse sees it.
    set -l cmdline
    if set -l i (contains -i -- -- $argv)
        set cmdline $argv[(math $i + 1)..-1]
        test $i -gt 1; and set argv $argv[1..(math $i - 1)]; or set argv
    end
    argparse --name "opx get" --max-args 1 h/help 'v/vault=' 'f/field=' c/copy p/print 'a/as=' env -- $argv
    or return 2
    set -q _flag_help; and __opx_usage get; and return 0

    if set -q _flag_as
        set -lx OP_SERVICE_ACCOUNT_TOKEN (security find-generic-password -s $_flag_as -w 2>/dev/null)
        if test -z "$OP_SERVICE_ACCOUNT_TOKEN"
            __opx_err get "no Keychain token '$_flag_as'"
            return 1
        end
    end

    set -l scope
    set -q _flag_vault; and set scope --scope $_flag_vault
    if test -z "$argv[1]"; and not __opx_can_pick
        __opx_usage get --error
        return 2
    end
    set -l ref (__opx_resolve get $scope --default (__opx_default_vault) $argv[1]); or return
    set -l r (string split \t -- $ref)
    set -l vault $r[3]
    set -l field "$_flag_field"
    test -z "$field"; and set field $r[4]

    set -l item (op item get $r[1] --vault $vault --format json | string collect); or return 1
    set -l jq (__opx_jq)

    # --env: run CMD with every exported field as an environment variable.
    if set -q _flag_env
        set -l rows (printf '%s' $item | jq -r "$jq"'exported as $e | $e[] | "\(.label)\t\($e | length)"')
        if test (count $rows) -eq 0
            __opx_err get "$vault/$r[2] has no fields with a value"
            return 1
        end
        set -l vars
        for row in $rows
            set -l c (string split \t -- $row)
            set -l var (__opx_var_name $vault $r[2] $c[1] $c[2])
            set -a vars $var
            if test (count $cmdline) -gt 0
                # set -lx: values reach CMD's environment, never its argv
                set -lx $var (printf '%s' $item | jq -r --arg f $c[1] "$jq"'field($f).value' | string collect)
            end
        end
        if test (count $cmdline) -eq 0
            __opx_err get "--env would set: "(string join ' ' $vars)" (add -- CMD to run)"
            return 0
        end
        $cmdline
        return
    end

    if test -z "$field"; and __opx_can_pick
        set -l fields (printf '%s' $item | jq -r "$jq"'readable[] | "\(.label)\t\(.type | ascii_downcase)"')
        if test (count $fields) -gt 1
            set -l pick (printf '%s\n' $fields | __opx_pick field "several concealed fields"); or return 1
            set field (string split \t -- $pick[1])[1]
        end
    end

    set -l value (printf '%s' $item | jq -er --arg f "$field" "$jq"'field($f) | .value // empty' | string collect)
    or begin
        __opx_err get "$vault/$r[2]: no "(test -n "$field"; and echo "field '$field'"; or echo "concealed field")" with a value"
        return 1
    end

    # In a terminal, copy instead of printing (keeps secrets out of scrollback).
    if set -q _flag_copy; or begin; isatty stdout; and not set -q _flag_print; end
        set -l secs (printf %s $value | __opx_copy_secret); or return 1
        __opx_err get "copied $vault/$r[2]"(test -n "$field"; and echo "/$field"; or echo "")(test -n "$secs"; and echo " (clears in $secs""s)"; or echo "")
    else
        printf '%s\n' $value
    end
end
