function __opx_keychain_services --description "List Keychain services that look like service-account tokens (*op-sa*)"
    # Reads item metadata only; no secrets are unlocked.
    security dump-keychain 2>/dev/null \
        | string match -r -g '"svce"<blob>="([^"]*op-sa[^"]*)"' | sort -u
end
