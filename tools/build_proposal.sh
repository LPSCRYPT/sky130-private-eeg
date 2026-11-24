#!/bin/sh
set -eu
cd "$(dirname "$0")/../proposal"
mkdir -p ../build
# Keep relative image resources anchored at proposal/, not the intermediate dir.
pandoc --from=markdown+raw_html --to=html5 --wrap=none --standalone --template=print.html -M pagetitle='Private EEG window commitment IP' proposal.md evidence.md measurement.md -o ../build/proposal.html
weasyprint --base-url "$PWD/" ../build/proposal.html chipalooza-4-private-eeg.pdf
