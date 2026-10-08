# jq definitions shared by every command that reads or writes fields.
# One line, so `(__opx_jq)'...'` stays a single argument.
function __opx_jq --description "Shared jq defs for opx field handling"
    echo -n 'def concealed: [.fields[]? | select(.type == "CONCEALED")]; '\
'def readable: concealed | map(select((.value // "") != "")); '\
'def field($f): if $f == "" then readable | first '\
'else [.fields[]? | select(.id == $f or .label == $f)] | first end; '
end
