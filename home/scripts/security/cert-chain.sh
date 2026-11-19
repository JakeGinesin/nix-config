#!/bin/bash
[ -z "$1" ] && { echo "Usage: $0 <domain>"; exit 1; }

echo | openssl s_client -showcerts -servername "$1" -connect "$1:443" 2>/dev/null | \
awk -v dom="$1" '
BEGIN {
    C = "\033[36m"; G = "\033[32m"; D = "\033[90m"; R = "\033[0m"
    print "\nCertificate Chain for: " G dom R "\n"
}

function get(line, f) {
    if (match(line, "(^|[ ,/])" f "[ \t]*=[ \t]*")) {
        val = substr(line, RSTART + RLENGTH)
        sub(/[,/].*/, "", val)
        return val
    }
    return ""
}

/^[ \t]*[0-9]* s:/ {
    cn = get($0, "CN")
    o  = get($0, "O")
    
    pad = ""; for (i=0; i<depth; i++) pad = pad "    "
    org = (o != "") ? " " D "[" o "]" R : ""
    
    if (depth == 0) {
        printf "%s%s%s%s\n", C, cn, R, org
    } else {
        printf "%s↳ %s%s%s%s\n", pad, C, cn, R, org
    }
    
    depth++
}

/^[ \t]*[0-9]* i:/ { 
    last_i = $0 
}

END {
    cn = get(last_i, "CN")
    o  = get(last_i, "O")
    
    pad = ""; for (i=0; i<depth; i++) pad = pad "    "
    org = (o != "") ? " " D "[" o "]" R : ""
    
    printf "%s↳ %s%s%s%s (Root)\n\n", pad, C, cn, R, org
}
'
