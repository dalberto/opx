function __opx_token_file --description "Validate a provisioned Linux token file; print its path only"
    set -l service $argv[1]
    if not string match -qr '^[A-Za-z0-9._-]+$' -- "$service"; or contains -- "$service" . ..
        __opx_err token "invalid service name"
        return 1
    end
    set -l dir (__opx_token_dir)
    set -l file "$dir/$service"
    # Refuse symlinks and shared files/directories before reading credentials.
    set -l uid (id -u)
    set -l dir_meta (stat -c '%u:%a' -- "$dir" 2>/dev/null)
    if test -L "$dir"; or not test -d "$dir"; or test "$dir_meta" != "$uid:700"
        __opx_err token "token directory must be owned by the current user with mode 0700: $dir"
        return 1
    end
    if test -L "$file"; or not test -f "$file"; or not test -r "$file"
        __opx_err token "no readable token file '$file'"
        return 1
    end
    set -l file_meta (stat -c '%u:%a' -- "$file" 2>/dev/null)
    if test "$file_meta" != "$uid:600"
        __opx_err token "token file must be owned by the current user with mode 0600: $file"
        return 1
    end
    printf '%s\n' "$file"
end
