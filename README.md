# opx

1Password helpers for [fish](https://fishshell.com): masked secret entry, quick reads, and one-step setup of read-only service accounts so headless agents can read secrets without biometric prompts.

```fish
fisher install dalberto/opx
```

Requires the [1Password CLI](https://developer.1password.com/docs/cli/) (`op`), `jq`, and macOS (Keychain, `pbcopy`). `fzf` is optional, for interactive vault picking.

## Commands

```
opx set      store a masked secret in an item field          abbr: opset
opx get      read a secret (optionally as a service account) abbr: opget
opx mv       move items between vaults                       abbr: opmv
opx vault    create a vault if missing                       abbr: opvault
opx agent    one-step: vault + read-only SA + Keychain token abbr: opagent
opx snippet  print agent instructions for a vault            abbr: opsnippet
opx sa       mint a service account token, save it           abbr: opsa, op-service-token
opx token    print an SA token from the Keychain             abbr: opsatoken
opx run      run a command as a service account              abbr: opsarun
```

`opx help COMMAND` (or `opx COMMAND -h`) for details.

Conventions, same for every command:

- **Pickers**: leave out a required argument in an interactive shell and fzf picks it (items across all vaults, vaults, fields, Keychain tokens). `opx set` and `opx agent` also accept a typed new name. Scripts and agents never see a picker; they get a usage error (exit 2).
- **Flags**: `-v` vault, `-f` field, `-c` copy, `-k` Keychain service, `-e` expiry, `-r` replace, `-y` yes, `-n` dry run, `-h` help. `opx mv` uses `--to`/`--from`; `opx set` uses `--category`.
- **Naming items**: a title, part of a title (`opx get openai`, if unique), an item id, or an `op://vault/item/field` reference. Ambiguous or missing → fzf picker prefiltered with what you typed (headless: error).
- **Clipboard**: `opx get` in a terminal copies instead of printing (`-p` to print; piped or `(…)` prints). Copied secrets clear after `$OPX_CLIP_SECONDS` (default 45) unless you copied something else since. `opx set -P` takes the value from the clipboard and clears it.
- **Fields**: `opx set ITEM -f a -f b -f region=us-east-1` prompts (masked) for `a` and `b` and stores `region` as plain text; `-g` generates values instead. `opx get ITEM --env -- CMD` runs CMD with every field as an env var. `opx snippet` exports every field, as `ITEM_FIELD` variables for multi-field items.
- **Defaults**: vault `$OPX_VAULT`, else `Dev`; new items are API Credentials; the field is the item's first concealed field.
- **Output**: values go to stdout, everything else to stderr as `opx CMD: …`. `-h` prints to stdout.
- **Completion**: everything tab-completes (vaults, items, fields, `VAULT:PERMS` grants, Keychain services). Lists are cached for 5 minutes and refreshed after writes.

Abbreviations expand at the prompt only; scripts should call `opx COMMAND`.

## Agent secrets

Agents can't answer Touch ID prompts. A [service account](https://developer.1password.com/docs/service-accounts/) token makes `op` skip the desktop app entirely.

```fish
opx agent my-agents -m slack-webhook   # vault + move item + read-only SA (30d) + verify
opx snippet -c                         # pick an agent vault, copy instructions for the agent
```

`opx agent` creates the vault if missing, moves items into it, mints a service account with read-only access to that vault only, stores the token in the macOS Keychain (service `VAULT-op-sa`) plus a backup item in `Dev`, verifies a headless read, and prints the snippet. The agent then runs:

```sh
OP_SERVICE_ACCOUNT_TOKEN="$(security find-generic-password -s my-agents-op-sa -w)" \
  op read 'op://my-agents/slack-webhook/credential'
```

For more than a handful of secrets, `opx snippet VAULT --env -o .env.op` writes an env file of `op://` references (no secrets; safe to commit) and tells the agent to run commands under `op run --env-file .env.op -- <command>`. Secrets arrive as environment variables and are masked if printed.

No prompts: `security` created the Keychain item, so `security` reads it silently. Any process running as you can read it, so the protection comes from the token's scope (read-only, one vault, expiring, revocable, audited), not from Keychain ACLs.

Rotate before expiry with `opx agent my-agents -r`, then revoke the old service account in the 1Password web app (Developer → Service Accounts). The CLI can't list or revoke service accounts.

Secrets never pass through argv or shell history: values travel to `op` as JSON on stdin and to the Keychain via `security -i`.

## Agent skill

`skills/opx/SKILL.md` teaches coding agents to read secrets headlessly and ask you for new ones with `opx set`. Install with [dotagents](https://github.com/getsentry/dotagents): `npx @sentry/dotagents add dalberto/opx opx`.

## Development

Edit, push, then `fisher update dalberto/opx`. To try local changes without pushing:

```fish
set -p fish_function_path (pwd)/functions; set -p fish_complete_path (pwd)/completions
```

## License

MIT
