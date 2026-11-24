#!/bin/sh
set -eu
cd "$(dirname "$0")/../proposal"
mkdir -p ../build
for font in 'DejaVu Sans' 'DejaVu Sans Mono'; do
    if [ "$(fc-match -f '%{family}' "$font")" != "$font" ]; then
        echo "Install $font or configure FONTCONFIG_FILE before building the proposal." >&2
        exit 1
    fi
done
tmp=$(mktemp -d ../build/proposal-print.XXXXXXXX)
trap 'rm -rf "$tmp"' EXIT
# Keep relative image resources anchored at proposal/, not the intermediate dir.
pandoc --from=markdown+raw_html --to=html5 --wrap=none --standalone --template=print.html -M pagetitle='Private EEG verification' proposal.md evidence.md measurement.md -o ../build/proposal.html
weasyprint --pdf-tags --base-url "$PWD/" ../build/proposal.html "$tmp/proposal.pdf" 2>"$tmp/render.log" || { cat "$tmp/render.log" >&2; exit 1; }
cat "$tmp/render.log" >&2
# WeasyPrint can exit successfully with a missing diagram or glyph.
if grep -Eiq '^ERROR:|Glyph .* missing' "$tmp/render.log"; then exit 1; fi
mv "$tmp/proposal.pdf" chipalooza-4-private-eeg.pdf
