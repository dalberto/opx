function __opx_copy_secret --description "Copy stdin to the clipboard; clear it after \$OPX_CLIP_SECONDS (default 45) if unchanged"
    # The clear is keyed on the pasteboard's change counter, so nothing derived
    # from the secret is kept, and anything copied in the meantime is left alone.
    pbcopy; or return 1
    set -l secs 45
    set -q OPX_CLIP_SECONDS[1]; and set secs $OPX_CLIP_SECONDS
    test "$secs" -gt 0 2>/dev/null; or return 0
    set -l counter 'ObjC.import("AppKit"); $.NSPasteboard.generalPasteboard.changeCount'
    set -l now (osascript -l JavaScript -e $counter 2>/dev/null); or return 0
    command sh -c 'sleep "$1"; [ "$(osascript -l JavaScript -e "$2" 2>/dev/null)" = "$3" ] && printf "" | pbcopy' \
        opx-clip $secs $counter $now </dev/null >/dev/null 2>&1 &
    disown 2>/dev/null
    echo $secs
end
