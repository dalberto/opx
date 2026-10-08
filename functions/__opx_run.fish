function __opx_run --description "Run a command as a 1Password service account (token from Keychain)"
    if test (count $argv) -lt 2; or contains -- $argv[1] -h --help
        echo "usage: opx run SERVICE [--] CMD [ARGS...]

Run CMD with OP_SERVICE_ACCOUNT_TOKEN set from Keychain SERVICE, so op
calls inside it run headlessly as the service account.

examples:
  opx run my-agents-op-sa op read op://my-agents/slack/credential
  opx run my-agents-op-sa -- op run --env-file .env.op -- ./agent

see also: opx token, opx snippet" >&2
        contains -- $argv[1] -h --help; and return 0; or return 2
    end
    set -l service $argv[1]
    set -e argv[1]
    test "$argv[1]" = --; and set -e argv[1]
    set -l token (opx token $service); or return
    env OP_SERVICE_ACCOUNT_TOKEN=$token $argv
end
