#!/usr/bin/env bash
# BDA Labs downloader for Ubuntu Desktop.
# Downloads lab1.txt ... lab9.txt directly into the current user's Home folder.
# Uses only Bash and the Python 3 standard library already supplied by Ubuntu Desktop.

set -u

REPO_RAW='https://raw.githubusercontent.com/EWG-F/BDA/main'
SCRIPT_PATH="$(readlink -f -- "${BASH_SOURCE[0]}")"

# When launched by Ubuntu Files, there is no interactive terminal attached.
# Open a tab in the Ubuntu terminal app (or a new terminal window if none is open).
if [[ "${1:-}" != '--terminal-child' && ( ! -t 0 || ! -t 1 ) ]]; then
    if command -v ptyxis >/dev/null 2>&1; then
        exec ptyxis --tab --title='BDA Labs Setup' -- bash "$SCRIPT_PATH" --terminal-child
    elif command -v gnome-terminal >/dev/null 2>&1; then
        exec gnome-terminal --tab --title='BDA Labs Setup' -- bash "$SCRIPT_PATH" --terminal-child
    elif command -v x-terminal-emulator >/dev/null 2>&1; then
        exec x-terminal-emulator -e bash "$SCRIPT_PATH" --terminal-child
    else
        printf '%s\n' 'Could not find the Ubuntu terminal application.'
        exit 1
    fi
fi

WAIT_AT_END=0
if [[ "${1:-}" == '--terminal-child' ]]; then
    WAIT_AT_END=1
fi

printf '\n==============================================\n'
printf '          BDA LABS 1-9 DOWNLOADER\n'
printf '==============================================\n\n'
printf 'Destination: %s\n\n' "$HOME"

if ! command -v python3 >/dev/null 2>&1; then
    printf '%s\n' 'ERROR: Python 3 was not found.'
    printf '%s\n' 'This installer expects the standard Python 3 included with Ubuntu Desktop.'
    exit 1
fi

python3 - "$HOME" "$REPO_RAW" <<'PY'
import pathlib
import sys
import tempfile
import urllib.error
import urllib.request

home = pathlib.Path(sys.argv[1]).expanduser()
base_url = sys.argv[2].rstrip("/")

print("Starting downloads from the public GitHub repository...", flush=True)

for number in range(1, 10):
    filename = f"lab{number}.txt"
    url = f"{base_url}/{filename}"
    destination = home / filename
    print(f"[{number}/9] Downloading {filename} ... ", end="", flush=True)

    temporary_path = None
    try:
        request = urllib.request.Request(
            url,
            headers={"User-Agent": "BDA-Labs-Setup/1.0"},
        )
        with urllib.request.urlopen(request, timeout=45) as response:
            content = response.read()

        if not content.strip():
            raise RuntimeError("GitHub returned an empty file")

        # Write to a temporary file first so an interrupted download doesn't
        # destroy a previously downloaded lab file.
        with tempfile.NamedTemporaryFile(
            mode="wb", prefix=f".{filename}.", suffix=".tmp",
            dir=home, delete=False
        ) as temporary_file:
            temporary_file.write(content)
            temporary_path = pathlib.Path(temporary_file.name)

        temporary_path.replace(destination)
        temporary_path = None
        print("DONE", flush=True)

    except (urllib.error.URLError, TimeoutError, OSError, RuntimeError) as error:
        if temporary_path is not None:
            try:
                temporary_path.unlink(missing_ok=True)
            except OSError:
                pass
        print("FAILED", flush=True)
        print(f"\nCould not download {filename}: {error}", file=sys.stderr, flush=True)
        print("Check the internet connection and run setup-labs.sh again.", file=sys.stderr, flush=True)
        sys.exit(1)

print("\nAll nine lab programs were downloaded successfully!", flush=True)
print(f"Files are saved directly in: {home}", flush=True)
print("You can open them from Home: lab1.txt through lab9.txt", flush=True)
PY

RESULT=$?
printf '\n'
if [[ "$RESULT" -eq 0 ]]; then
    printf '%s\n' '=============================================='
    printf '%s\n' '                 COMPLETE!'
    printf '%s\n' '=============================================='
else
    printf '%s\n' '=============================================='
    printf '%s\n' '             DOWNLOAD INCOMPLETE'
    printf '%s\n' '=============================================='
fi

if [[ "$WAIT_AT_END" -eq 1 ]]; then
    printf '\nPress Enter to close this terminal tab...'
    read -r _ || true
fi

exit "$RESULT"
