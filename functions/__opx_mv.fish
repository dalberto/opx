function __opx_mv --description "Move 1Password items to another vault"
    argparse h/help 't/to=' 'f/from=' -- $argv; or return
    if set -q _flag_help; or test (count $argv) -lt 1; or not set -q _flag_to
        echo "usage: opx mv ITEM... -t VAULT [-f FROM]

Move items into VAULT. Without -f, each ITEM is located by exact title across
all vaults and must match exactly one item. Items already in VAULT are
skipped. Moving assigns a new item ID; the original goes to Recently Deleted.

  -t, --to VAULT     destination vault
  -f, --from VAULT   source vault (default: search all vaults)

examples:
  opx mv slack-webhook -t my-agents

see also: opx vault, opx agent" >&2
        set -q _flag_help; and return 0; or return 2
    end
    set -l rc 0
    for name in $argv
        set -l matches (op item list --format json \
            | jq -r --arg n $name --arg f "$_flag_from" \
                '.[] | select(.title == $n and ($f == "" or .vault.name == $f or .vault.id == $f))
                 | "\(.id)\t\(.vault.name)"')
        if test (count $matches) -ne 1
            set -l where
            test (count $matches) -gt 1; and set where " in:" (string split -f2 \t -- $matches) "(use -f VAULT)"
            echo "opx mv: '$name' matched "(count $matches)" items"(string join ' ' -- '' $where) >&2
            set rc 1
            continue
        end
        set -l id (string split -f1 \t -- $matches)
        set -l from (string split -f2 \t -- $matches)
        if test "$from" = "$_flag_to"
            echo "opx mv: $name already in $_flag_to" >&2
            continue
        end
        op item move $id --current-vault $from --destination-vault $_flag_to >/dev/null
        and echo "opx mv: $from/$name → $_flag_to/$name" >&2
        or set rc 1
    end
    return $rc
end
