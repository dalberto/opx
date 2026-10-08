set -l cmds set get mv vault sa token run agent snippet help
complete -c opx -f
complete -c opx -n "not __fish_seen_subcommand_from $cmds" -a set -d 'Store a masked secret'
complete -c opx -n "not __fish_seen_subcommand_from $cmds" -a get -d 'Read a secret'
complete -c opx -n "not __fish_seen_subcommand_from $cmds" -a mv -d 'Move items between vaults'
complete -c opx -n "not __fish_seen_subcommand_from $cmds" -a vault -d 'Create a vault if missing'
complete -c opx -n "not __fish_seen_subcommand_from $cmds" -a agent -d 'Vault + read-only SA + Keychain token'
complete -c opx -n "not __fish_seen_subcommand_from $cmds" -a snippet -d 'Print agent instructions'
complete -c opx -n "not __fish_seen_subcommand_from $cmds" -a sa -d 'Mint a service account token'
complete -c opx -n "not __fish_seen_subcommand_from $cmds" -a token -d 'Print SA token from Keychain'
complete -c opx -n "not __fish_seen_subcommand_from $cmds" -a run -d 'Run a command as an SA'
complete -c opx -n "not __fish_seen_subcommand_from $cmds" -a help -d 'Show help'
complete -c opx -n "__fish_seen_subcommand_from help" -a "$cmds"

# Positional args by position after the subcommand.
function __opx_pos -a n --description "True if completing positional #n after the opx subcommand"
    set -l pos (commandline -xpc)[3..]
    # drop flags and the values of value-taking flags
    set -l count 0
    set -l skip 0
    for t in $pos
        if test $skip -eq 1
            set skip 0
            continue
        end
        switch $t
            case -v --vault -f --field -t --type -a --as -k --keychain -s --save-vault \
                    -e --expires -i --item -m --move -S --store --to --from
                set skip 1
            case '-*'
            case '*'
                set count (math $count + 1)
        end
    end
    test $count -eq (math $n - 1)
end

function __opx_using -a sub
    __fish_seen_subcommand_from $sub
end

set -l expiries '1h\t"1 hour" 24h\t"1 day" 7d\t"1 week" 30d\t"30 days" 90d\t"90 days"'

for sub in $cmds
    test $sub = help; and continue
    complete -c opx -n "__opx_using $sub" -s h -l help -d 'Show help'
end

# set / get
for sub in set get
    complete -c opx -n "__opx_using $sub" -s v -l vault -x -a '(__opx_complete vaults)' -d 'Vault (default: Dev)'
    complete -c opx -n "__opx_using $sub" -s f -l field -x -a '(__opx_complete fields)' -d 'Field (default: first concealed)'
    complete -c opx -n "__opx_using $sub; and __opx_pos 1" -a '(__opx_complete items)'
end
complete -c opx -n '__opx_using set' -s t -l type -x -a '(__opx_complete categories)' -d 'Category for new items (default: API Credential)'
complete -c opx -n '__opx_using get' -s c -l copy -d 'Copy instead of printing'
complete -c opx -n '__opx_using get' -s a -l as -x -a '(__opx_complete keychain)' -d 'Read as service account (Keychain SERVICE)'

# mv / vault
complete -c opx -n '__opx_using mv' -s t -l to -x -a '(__opx_complete vaults)' -d 'Destination vault'
complete -c opx -n '__opx_using mv' -s f -l from -x -a '(__opx_complete vaults)' -d 'Source vault (default: search all)'
complete -c opx -n '__opx_using mv' -a '(__opx_complete all-items)'
complete -c opx -n '__opx_using vault; and __opx_pos 1' -a '(__opx_complete vaults)'

# sa
complete -c opx -n '__opx_using sa' -s v -l vault -x -a '(__opx_complete grants)' -d 'Grant VAULT[:PERMS] (repeatable)'
complete -c opx -n '__opx_using sa' -s e -l expires -x -a "$expiries" -d 'Token lifetime (default: never)'
complete -c opx -n '__opx_using sa' -s C -l can-create-vaults -d 'Allow creating vaults'
complete -c opx -n '__opx_using sa' -s s -l save-vault -x -a '(__opx_complete vaults)' -d 'Vault to save token in (default: Dev)'
complete -c opx -n '__opx_using sa' -s i -l item -x -d 'Item title for the token (default: NAME)'
complete -c opx -n '__opx_using sa' -s S -l store -x -a 'op\t"1Password item" keychain\t"macOS Keychain" both\t"1Password + Keychain"' -d 'Where to save the token'
complete -c opx -n '__opx_using sa' -s k -l keychain -x -a '(__opx_complete keychain)' -d 'Keychain service (default: NAME)'
complete -c opx -n '__opx_using sa' -s r -l replace -d 'Overwrite stored token (rotation)'
complete -c opx -n '__opx_using sa' -s c -l copy -d 'Also copy token to clipboard'
complete -c opx -n '__opx_using sa' -s y -l yes -d 'Skip confirmation'
complete -c opx -n '__opx_using sa' -s n -l dry-run -d 'Show plan; mint nothing'

# token / run
complete -c opx -n '__opx_using token; and __opx_pos 1' -a '(__opx_complete keychain)'
complete -c opx -n '__opx_using run; and __opx_pos 1' -a '(__opx_complete keychain)'
complete -c opx -n '__opx_using run; and not __opx_pos 1' -x -a '(__fish_complete_subcommand --fcs-skip=3)'

# agent
complete -c opx -n '__opx_using agent; and __opx_pos 1' -a '(__opx_complete vaults | string match -v -r "^(Personal|Private)\$")'
complete -c opx -n '__opx_using agent' -s m -l move -x -a '(__opx_complete all-items)' -d 'Item to move into VAULT (repeatable)'
complete -c opx -n '__opx_using agent' -s e -l expires -x -a "$expiries" -d 'Token lifetime (default: 30d)'
complete -c opx -n '__opx_using agent' -s k -l keychain -x -d 'Keychain service (default: VAULT-op-sa)'
complete -c opx -n '__opx_using agent' -s r -l replace -d 'Rotate: new token, overwrite stored copies'
complete -c opx -n '__opx_using agent' -s y -l yes -d 'Skip confirmation'
complete -c opx -n '__opx_using agent' -s n -l dry-run -d 'Show plan; change nothing'

# snippet
complete -c opx -n '__opx_using snippet; and __opx_pos 1' -a '(__opx_complete vaults)'
complete -c opx -n '__opx_using snippet; and not __opx_pos 1' -a '(__opx_complete items-in-first)'
complete -c opx -n '__opx_using snippet' -s k -l keychain -x -a '(__opx_complete keychain)' -d 'Keychain service (default: VAULT-op-sa)'
complete -c opx -n '__opx_using snippet' -s c -l copy -d 'Copy instead of printing'
