function __opx_keychain_set --description "Store stdin as a macOS Keychain generic password: __opx_keychain_set SERVICE [--replace]"
    # Fed to `security -i` on stdin so the secret never appears in argv.
    set -l service $argv[1]
    if not string match -q -r '^[A-Za-z0-9._-]+$' -- $service
        echo "__opx_keychain_set: service must match [A-Za-z0-9._-]+: $service" >&2
        return 1
    end
    read -l -z secret
    if not string match -q -r '^\S+$' -- $secret
        echo "__opx_keychain_set: refusing empty or whitespace-containing secret" >&2
        return 1
    end
    set -l update
    contains -- --replace $argv; and set update -U
    printf 'add-generic-password %s -s %s -a %s -l %s -w %s\n' "$update" $service $USER $service $secret \
        | security -i >/dev/null
end
