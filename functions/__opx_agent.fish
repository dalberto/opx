function __opx_agent --description "Set up a vault + read-only service account (token in Keychain) for agents"
    argparse --max-args 1 h/help 'm/move=+' 'e/expires=' 'k/keychain=' r/replace y/yes n/dry-run -- $argv
    or return
    if set -q _flag_help; or test (count $argv) -ne 1
        echo "usage: opx agent VAULT [-m ITEM]... [-e DURATION] [options]

One step agent-secrets setup, composed from the op* helpers:
  1. opx vault VAULT                 create the vault if missing
  2. opx mv ITEM... -t VAULT         move -m items into it
  3. opx sa VAULT-op-sa -v VAULT:read -S both
                                   mint a read-only service account; token
                                   saved to Keychain + 1Password (Dev)
  4. opx get ... --as SERVICE        verify a headless read works
  5. opx snippet VAULT               print instructions to hand an agent

  -m, --move ITEM          item to move into VAULT (repeatable)
  -e, --expires DURATION   token lifetime (default: 30d)
  -k, --keychain SERVICE   Keychain service / account name (default: VAULT-op-sa)
  -r, --replace            rotate: mint a new token, overwrite stored copies
  -y, --yes                skip confirmation
  -n, --dry-run            show the plan; change nothing
  -h, --help               show this help

Rotation: rerun with -r before expiry; revoke the old service account in the
1Password web app (Developer > Service Accounts).

examples:
  opx agent my-agents -m slack-webhook
  opx agent my-agents -r          # rotate

see also: opx snippet, opx run, opx token, opx sa" >&2
        set -q _flag_help; and return 0; or return 2
    end
    set -l vault $argv[1]
    set -l service $vault-op-sa
    set -q _flag_keychain; and set service $_flag_keychain
    set -l expires 30d
    set -q _flag_expires; and set expires $_flag_expires

    set -l pass
    set -q _flag_yes; and set -a pass -y
    set -q _flag_dry_run; and set -a pass -n
    set -q _flag_replace; and set -a pass -r

    if set -q _flag_dry_run
        echo "dry run:" >&2
        op vault get $vault >/dev/null 2>&1; and echo "  vault $vault exists" >&2; or echo "  would create vault $vault" >&2
        test (count $_flag_move) -gt 0; and echo "  would move: "(string join ', ' $_flag_move) >&2
    else
        opx vault $vault; or return
        if test (count $_flag_move) -gt 0
            opx mv $_flag_move -t $vault; or return
        end
    end

    opx sa $service -v "$vault:read" -e $expires -S both -k $service $pass; or return
    set -q _flag_dry_run; and return 0

    set -l first (op item list --vault $vault --format json | jq -r '.[0].title // empty')
    if test -z "$first"
        echo "opx agent: $vault is empty; skipping verification" >&2
    else if opx get $first -v $vault --as $service >/dev/null
        echo "opx agent: verified headless read of $vault/$first as $service" >&2
    else
        echo "opx agent: VERIFY FAILED reading $vault/$first as $service" >&2
        return 1
    end

    echo >&2
    opx snippet $vault -k $service
end
