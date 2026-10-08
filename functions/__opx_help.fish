function __opx_help --description "List opx commands, or show help for one"
    if set -q argv[1]
        opx $argv[1] --help
        return
    end
    echo "usage: opx COMMAND [ARGS...]    (opx help COMMAND for details)

secrets
  set      store a masked secret in an item field          abbr: opset
  get      read a secret (optionally as a service account) abbr: opget
  mv       move items between vaults                       abbr: opmv
  vault    create a vault if missing                       abbr: opvault

service accounts / agents
  agent    one-step: vault + read-only SA + Keychain token abbr: opagent
  snippet  print agent instructions for a vault            abbr: opsnippet
  sa       mint a service account token, save it           abbr: opsa, op-service-token
  token    print an SA token from the Keychain             abbr: opsatoken
  run      run a command as a service account              abbr: opsarun

Defaults: vault Dev; agent tokens expire in 30d. Requires op, jq; fzf optional." >&2
end
