# opx — 1Password helpers. Abbreviations expand to `opx <command>` at the prompt.
status is-interactive; or return

for pair in opset:set opget:get opmv:mv opvault:vault opagent:agent \
        opsnippet:snippet opsa:sa op-service-token:sa opsatoken:token opsarun:run
    set -l kv (string split : -- $pair)
    abbr -a $kv[1] "opx $kv[2]"
end

function _opx_uninstall --on-event opx_uninstall
    for a in opset opget opmv opvault opagent opsnippet opsa op-service-token opsatoken opsarun
        abbr -e $a 2>/dev/null
    end
    set -e (set -n | string match '__opx_complete_cache_*')
    functions -e _opx_uninstall
end
