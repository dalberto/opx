---
name: opx
description: Use whenever a task needs a secret or credential (API key, token, password, webhook URL, cloud keys) on the user's Mac, needs the user to store one, or touches 1Password, `op`, `op://` references, OP_SERVICE_ACCOUNT_TOKEN, or `opx`. Covers reading secrets headlessly through a read-only 1Password service account and asking the user to add secrets with `opx set`.
---

# opx: secrets via 1Password

`opx` is the user's fish wrapper around the 1Password CLI. It is a fish function: from bash, run `fish -c 'opx …'`. Don't rely on this file for flags. Run `fish -c 'opx help'` and `fish -c 'opx help <command>'` for the current commands and options before using one.

## Rules

- **Never** ask the user to paste a secret into chat. Never print, log, echo, commit or write secret values. `op://` references are not secrets and are fine to write.
- **Stay headless.** Only call `op`/`opx` with `OP_SERVICE_ACCOUNT_TOKEN` set from the Keychain, as the snippet shows. Any other `op` call prompts the user for Touch ID. Never work around a failure that way.
- **Inject, don't read.** Prefer `op run --env-file …` (from `opx snippet --env`), so values reach the command's environment and are masked in output. Avoid `op read` into variables or stdout.
- Steps marked **human** need the user's own 1Password session. Hand them the exact command, then wait.

## Getting access

1. If the user gave you an `opx snippet`, follow it.
2. Otherwise run `fish -c 'opx snippet'`. The error lists the agent vaults that have a token. Then run `fish -c 'opx snippet <vault> --env'`. It reads as the service account, so it causes no prompt.
3. If there's no suitable vault, **human**: `opx agent <project>-agents`. It creates the vault and a read-only, expiring service account, and stores the token in the Keychain.

## Asking the user for a secret

Give a ready-to-run `opx set` command rather than raw `op`. It uses masked prompts, and nothing goes to chat or shell history:

```fish
opx set <vault>-<service> -v <vault> -f <field> -f <field> -f <non-secret>=<value>
```

- Name items `<vault>-<service>`. Env vars then come out as `SERVICE_FIELD` (see `opx help snippet`).
- `-f name=value` is plain text and lands in shell history, so use it only for non-secrets (region, endpoint). Mention `-P` (paste from clipboard) when the user is copying the value from a web page.
- Say what each field is and where to find it. Ask the user to reply "done", then re-run `opx snippet <vault> --env` to pick it up.

## When things fail

| Symptom | Ask the user (**human**) |
|---|---|
| The item exists in another vault | `opx mv <item> --to <vault>`. Don't ask for broader access. |
| "can't read … expired or revoked" / authorization errors | `opx agent <vault> -r` (rotate) |
| No Keychain token for the vault | `opx agent <vault>` |
| "Keychain prompt" | Click **Always Allow** |
