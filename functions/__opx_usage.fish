function __opx_usage --description "Print help for an opx command (stdout), or usage error (stderr) with --error"
    # __opx_usage [CMD] [--error]
    set -l err (contains -- --error $argv; and echo 1)
    set -l cmd (string match -v -- --error $argv)[1]
    set -l text
    switch "$cmd"
        case ''
            set text "usage: opx COMMAND [ARGS...]     opx help COMMAND for details

secrets
  set      store a masked secret in an item field        abbr: opset
  get      read a secret                                 abbr: opget
  mv       move items between vaults                     abbr: opmv
  vault    create a vault if missing                     abbr: opvault

service accounts / agents
  agent    vault + read-only SA + Keychain token, 1 step abbr: opagent
  snippet  print agent instructions for a vault          abbr: opsnippet
  sa       mint a service account token, save it         abbr: opsa, op-service-token
  token    print an SA token from the Keychain           abbr: opsatoken
  run      run a command as a service account            abbr: opsarun

Omit a required argument in an interactive shell to pick it with fzf;
scripts and agents get a usage error instead. Default vault: \$OPX_VAULT,
else Dev. Requires op and jq; fzf optional."

        case set
            set text "usage: opx set [ITEM] [-v VAULT] [-f FIELD[=VALUE]]... [--category CATEGORY]
abbr: opset

Store secrets in ITEM. Creates the item if missing; otherwise updates the
given fields, adding any that are absent. Masked values reach op as JSON on
stdin, never argv or history.

  -f FIELD         prompt (masked) for FIELD; stored concealed
  -f FIELD=VALUE   store VALUE as plain text (for non-secrets like a region)
  (no -f)          prompt for the item's first concealed field

With no ITEM, pick one with fzf (type a new name to create it).

  -v, --vault VAULT        vault (default: \$OPX_VAULT or Dev; picker: all)
  -f, --field FIELD[=VAL]  field to set; repeatable (see above)
      --category CATEGORY  category for new items (default: API Credential)
  -h, --help               show this help

examples:
  opx set openai-api-key
  opx set my-agents-aws -v my-agents -f access-key-id -f secret-access-key -f region=us-east-1
  opx set stripe -f secret-key -v Production

see also: opx get, opx snippet"

        case get
            set text "usage: opx get [ITEM] [-v VAULT] [-f FIELD] [-c] [-a SERVICE]
abbr: opget

Print a secret from ITEM to stdout.

With no ITEM, pick one with fzf; if it has several concealed fields and no
-f, pick the field too.

  -v, --vault VAULT    vault (default: \$OPX_VAULT or Dev; picker: all)
  -f, --field FIELD    field label or id (default: first concealed field
                       with a value)
  -c, --copy           copy to clipboard (no trailing newline) instead
  -a, --as SERVICE     read as the service account whose token is in
                       Keychain SERVICE (headless, no biometric prompt)
  -h, --help           show this help

examples:
  set -x OPENAI_API_KEY (opx get openai-api-key)
  opx get -c
  opx get slack-webhook -v my-agents --as my-agents-op-sa

see also: opx set, opx token"

        case mv
            set text "usage: opx mv [ITEM...] [--to VAULT] [--from VAULT]
abbr: opmv

Move items into another vault. ITEMs are matched by exact title across all
vaults (or --from) and must be unambiguous. Items already in the target are
skipped. Moving assigns a new item id; originals go to Recently Deleted.

With no ITEM, multi-select with fzf (Tab); with no --to, pick the vault.

      --to VAULT     destination vault
      --from VAULT   source vault (default: search all vaults)
  -h, --help         show this help

examples:
  opx mv slack-webhook --to my-agents

see also: opx vault, opx agent"

        case vault
            set text "usage: opx vault NAME
abbr: opvault

Create vault NAME unless it already exists.

  -h, --help   show this help

see also: opx mv, opx agent"

        case agent
            set text "usage: opx agent [VAULT] [-m ITEM]... [-e DURATION] [options]
abbr: opagent

One-step agent setup:
  1. create VAULT if missing           (opx vault)
  2. move -m items into it             (opx mv)
  3. mint a read-only service account  (opx sa VAULT-op-sa -v VAULT:read)
     token saved to Keychain VAULT-op-sa + 1Password (default vault)
  4. verify a headless read            (opx get --as)
  5. print instructions for the agent  (opx snippet)

With no VAULT, pick one with fzf (type a new name to create it). If VAULT
is already set up, choose rotate / snippet / cancel (headless: error; use -r).

  -m, --move ITEM          item to move into VAULT (repeatable)
  -e, --expires DURATION   token lifetime (default: 30d)
  -k, --keychain SERVICE   Keychain service / SA name (default: VAULT-op-sa)
  -s, --save-vault VAULT   vault for the backup token item (default: \$OPX_VAULT or Dev)
  -i, --item NAME          title for the backup token item (default: SERVICE)
  -c, --copy               also copy the token
  -r, --replace            rotate: mint a new token, overwrite stored copies
  -y, --yes                skip confirmation
  -n, --dry-run            show the plan; change nothing
  -h, --help               show this help

Rotate with -r before expiry, then revoke the old service account in the
1Password web app (Developer > Service Accounts).

examples:
  opx agent my-agents -m slack-webhook
  opx agent my-agents -r

see also: opx snippet, opx run, opx token, opx sa"

        case snippet
            set text "usage: opx snippet [VAULT [ITEM...]] [--env] [-o FILE] [-k SERVICE] [-c]
abbr: opsnippet

Print markdown instructions an agent can follow to read VAULT's secrets
headlessly: token from the Keychain, one op:// reference per field. Every
concealed field and plain-text field with a value is included (notes aside).
Items are read as the service account, so only what the agent can access is
listed; items with no values or with '/' in the name are skipped.

--env switches to an env file of op:// references (VAR=op://...; no secrets,
safe to commit) plus an `op run --env-file` command, so secrets reach the
agent's command as environment variables and never appear in its output.
Variable names come from item titles minus a leading vault name; items with
several fields get ITEM_FIELD (my-agents-aws → AWS_ACCESS_KEY_ID, AWS_REGION).

With no VAULT, pick from vaults that have a Keychain token.

      --env                env-file format (better for many secrets)
  -o, --out FILE           with --env: write the env file to FILE (default
                           output embeds it, for the agent to save as VAULT.env)
  -k, --keychain SERVICE   Keychain service (default: VAULT-op-sa)
  -c, --copy               copy instead of printing
  -h, --help               show this help

examples:
  opx snippet -c
  opx snippet my-agents slack-webhook
  opx snippet my-agents --env -o .env.op -c

see also: opx agent, opx token, opx run"

        case sa
            set text "usage: opx sa NAME [-v VAULT[:PERMS]]... [-e DURATION] [options]
abbrs: opsa, op-service-token

Mint a service account token and save it (1Password item and/or Keychain)
so the one-time token is never lost.

With no -v, pick vaults (Tab to multi-select) and permissions with fzf.

  -v, --vault VAULT[:PERMS]  grant access; repeatable. PERMS: comma list of
                             read, write, share (default read; write/share
                             imply read)
  -e, --expires DURATION     token lifetime, e.g. 24h, 7d, 4w (default: never)
  -C, --can-create-vaults    allow the service account to create vaults
  -s, --save-vault VAULT     vault for the token item (default: \$OPX_VAULT or Dev)
  -i, --item NAME            title for the token item (default: NAME)
  -S, --store WHERE          op | keychain | both (default: op; both with -k)
  -k, --keychain SERVICE     Keychain service (default: NAME)
  -r, --replace              overwrite stored copies (rotation)
  -c, --copy                 also copy the token
  -y, --yes                  skip confirmation
  -n, --dry-run              show the plan; mint nothing
  -h, --help                 show this help

Personal/Private vaults can't be granted. Revoke in the 1Password web app
(Developer > Service Accounts); the CLI can't.

examples:
  opx sa ci-deploy
  opx sa ci-deploy -v Dev -v Production:read,write -e 30d -k ci-deploy

see also: opx agent, opx token, opx run"

        case token
            set text "usage: opx token [SERVICE]
abbr: opsatoken

Print the service account token stored in Keychain SERVICE.

With no SERVICE, pick one with fzf.

  -h, --help   show this help

examples:
  set -x OP_SERVICE_ACCOUNT_TOKEN (opx token my-agents-op-sa)

see also: opx run, opx agent"

        case run
            set text "usage: opx run [SERVICE] -- CMD [ARGS...]
abbr: opsarun

Run CMD with OP_SERVICE_ACCOUNT_TOKEN from Keychain SERVICE, so op calls
inside it run headlessly as the service account.

With no SERVICE (CMD right after --), pick one with fzf.

  -h, --help   show this help

examples:
  opx run my-agents-op-sa -- op read op://my-agents/slack-webhook/credential
  opx run -- op vault list

see also: opx token, opx snippet"

        case '*'
            __opx_err help "unknown command '$cmd'"
            __opx_usage --error
            return 2
    end
    if test -n "$err"
        printf '%s\n' $text >&2
        return 2
    end
    printf '%s\n' $text
end
