set -l cmds set get mv vault sa token run agent snippet help
complete -c opx -f

function __opx_using -a sub
    __fish_seen_subcommand_from $sub
end
function __opx_npos -a n --description "True if completing positional #n after the subcommand"
    test (count (__opx_cl pos)) -eq (math $n - 1)
end

complete -c opx -n "not __fish_seen_subcommand_from $cmds" -a "set\t'Store a masked secret'
get\t'Read a secret'
mv\t'Move items between vaults'
vault\t'Create a vault if missing'
agent\t'Vault + read-only SA + Keychain token'
snippet\t'Print agent instructions'
sa\t'Mint a service account token'
token\t'Print SA token from Keychain'
run\t'Run a command as an SA'
help\t'Show help'"
complete -c opx -n '__opx_using help' -a "$cmds"
for sub in $cmds
    test $sub = help; or complete -c opx -n "__opx_using $sub" -s h -l help -d 'Show help'
end

set -l expiries '1h\t"1 hour" 24h\t"1 day" 7d\t"1 week" 30d\t"30 days" 90d\t"90 days"'

# set / get
for sub in set get
    complete -c opx -n "__opx_using $sub" -s v -l vault -x -a '(__opx_complete vaults)' -d 'Vault'
    complete -c opx -n "__opx_using $sub" -s f -l field -x -a '(__opx_complete fields)' -d 'Field (default: first concealed)'
    complete -c opx -n "__opx_using $sub; and __opx_npos 1" -a '(__opx_complete items)'
end
complete -c opx -n '__opx_using set' -l category -x -a '(__opx_complete categories)' -d 'Category for new items'
complete -c opx -n '__opx_using get' -s c -l copy -d 'Copy instead of printing'
complete -c opx -n '__opx_using get' -s a -l as -x -a '(__opx_complete keychain)' -d 'Read as service account'

# mv / vault
complete -c opx -n '__opx_using mv' -l to -x -a '(__opx_complete vaults)' -d 'Destination vault'
complete -c opx -n '__opx_using mv' -l from -x -a '(__opx_complete vaults)' -d 'Source vault'
complete -c opx -n '__opx_using mv' -a '(__opx_complete all-items)'
complete -c opx -n '__opx_using vault; and __opx_npos 1' -a '(__opx_complete vaults)'

# agent
complete -c opx -n '__opx_using agent; and __opx_npos 1' -a '(__opx_complete vaults | string match -v -r "^(Personal|Private)\t")'
complete -c opx -n '__opx_using agent' -s m -l move -x -a '(__opx_complete all-items)' -d 'Item to move in (repeatable)'
complete -c opx -n '__opx_using agent' -s e -l expires -x -a "$expiries" -d 'Token lifetime (default: 30d)'
complete -c opx -n '__opx_using agent' -s k -l keychain -x -d 'Keychain service (default: VAULT-op-sa)'
complete -c opx -n '__opx_using agent' -s s -l save-vault -x -a '(__opx_complete vaults)' -d 'Vault for the backup token item'
complete -c opx -n '__opx_using agent' -s i -l item -x -d 'Backup token item title (default: SERVICE)'
complete -c opx -n '__opx_using agent' -s c -l copy -d 'Also copy the token'
complete -c opx -n '__opx_using agent' -s r -l replace -d 'Rotate the token'
complete -c opx -n '__opx_using agent' -s y -l yes -d 'Skip confirmation'
complete -c opx -n '__opx_using agent' -s n -l dry-run -d 'Show plan; change nothing'

# snippet
complete -c opx -n '__opx_using snippet; and __opx_npos 1' -a '(__opx_complete agent-vaults)'
complete -c opx -n '__opx_using snippet; and not __opx_npos 1' -a '(__opx_complete vault-items)'
complete -c opx -n '__opx_using snippet' -s k -l keychain -x -a '(__opx_complete keychain)' -d 'Keychain service'
complete -c opx -n '__opx_using snippet' -s c -l copy -d 'Copy instead of printing'
complete -c opx -n '__opx_using snippet' -l env -d 'Env-file format for op run'
complete -c opx -n '__opx_using snippet' -s o -l out -r -F -d 'Write the env file here (implies --env)'

# sa
complete -c opx -n '__opx_using sa' -s v -l vault -x -a '(__opx_complete grants)' -d 'Grant VAULT[:PERMS] (repeatable)'
complete -c opx -n '__opx_using sa' -s e -l expires -x -a "$expiries" -d 'Token lifetime (default: never)'
complete -c opx -n '__opx_using sa' -s C -l can-create-vaults -d 'Allow creating vaults'
complete -c opx -n '__opx_using sa' -s s -l save-vault -x -a '(__opx_complete vaults)' -d 'Vault for the token item'
complete -c opx -n '__opx_using sa' -s i -l item -x -d 'Token item title (default: NAME)'
complete -c opx -n '__opx_using sa' -s S -l store -x -a 'op\t"1Password item" keychain\t"macOS Keychain" both\t"1Password + Keychain"' -d 'Where to save the token'
complete -c opx -n '__opx_using sa' -s k -l keychain -x -a '(__opx_complete keychain)' -d 'Keychain service (default: NAME)'
complete -c opx -n '__opx_using sa' -s r -l replace -d 'Overwrite stored copies (rotation)'
complete -c opx -n '__opx_using sa' -s c -l copy -d 'Also copy the token'
complete -c opx -n '__opx_using sa' -s y -l yes -d 'Skip confirmation'
complete -c opx -n '__opx_using sa' -s n -l dry-run -d 'Show plan; mint nothing'

# token / run
complete -c opx -n '__opx_using token; and __opx_npos 1' -a '(__opx_complete keychain)'
complete -c opx -n '__opx_using run; and __opx_npos 1' -a '(__opx_complete keychain)'
complete -c opx -n '__opx_using run; and not __opx_npos 1' -x -a '(__fish_complete_subcommand --fcs-skip=3)'
