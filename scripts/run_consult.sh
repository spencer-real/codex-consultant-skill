#!/bin/sh
# Choose a supported Python interpreter without relying on a shell alias.
case $0 in
    */*) script_directory=${0%/*} ;;
    *) script_directory=. ;;
esac
script_directory=$(CDPATH= cd -P "$script_directory" && pwd) || exit 1

if command -v python3 >/dev/null 2>&1 &&
    python3 -c 'import sys; raise SystemExit(sys.version_info < (3, 9))' >/dev/null 2>&1; then
    exec python3 "$script_directory/consult.py" "$@"
fi
if command -v python >/dev/null 2>&1 &&
    python -c 'import sys; raise SystemExit(sys.version_info < (3, 9))' >/dev/null 2>&1; then
    exec python "$script_directory/consult.py" "$@"
fi

printf '%s\n' 'consultant: Python 3.9+ is required; neither python3 nor python provides it.' >&2
exit 127
