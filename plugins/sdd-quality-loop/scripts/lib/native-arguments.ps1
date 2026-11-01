# Start-Process joins its ArgumentList array with spaces. Encode each atom for
# the native command-line parser; this is not quoting for cmd.exe or a shell.
function ConvertTo-SddNativeArgumentString {
    param([string[]]$Arguments)
    $quoted = foreach ($argument in $Arguments) {
        $escaped = [regex]::Replace($argument, '(\\*)"', '$1$1\"')
        $escaped = [regex]::Replace($escaped, '(\\+)$', '$1$1')
        '"' + $escaped + '"'
    }
    $quoted -join ' '
}
