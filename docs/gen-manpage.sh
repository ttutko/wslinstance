#!/usr/bin/env bash
# Generate the wsltools(1) man page from docs/tools.tsv (single source of truth).
# Usage: gen-manpage.sh [TSV] [OUTPUT.1]
set -euo pipefail

TSV="${1:-/usr/local/share/wsl/tools.tsv}"
OUT="${2:-/usr/share/man/man1/wsltools.1}"
DATE="$(date +%Y-%m-%d 2>/dev/null || echo 2026-01-01)"

mkdir -p "$(dirname "$OUT")"

awk -F'\t' -v date="$DATE" '
function esc(s){ gsub(/\\/,"\\\\",s); return s }
BEGIN{
  print ".TH WSLTOOLS 1 \"" date "\" \"wslinstance\" \"WSL Airgapped Tools\""
  print ".SH NAME"
  print "wsltools \\- overview of the tools preinstalled in this WSL instance"
  print ".SH DESCRIPTION"
  print "This WSL instance ships with the tools listed below, grouped by"
  print "category, each with a short description and a common usage example."
  print "For offline, example-driven help on most commands run \\fBtldr\\fR \\fICMD\\fR."
  print "Run \\fBwsltools\\fR for a colorized on-screen summary."
  print ".SH TOOLS"
}
{
  cat=$1; cmd=$2; desc=$3; ex=$4
  if(cat!=last){ print ".SS " esc(cat); last=cat }
  print ".TP"
  print ".B " esc(cmd)
  print esc(desc)
  print ".br"
  print "Example: \\fB" esc(ex) "\\fR"
}
END{
  print ".SH FILES"
  print ".TP"
  print "/usr/local/share/wsl/tools.tsv"
  print "The source list backing this page and the \\fBwsltools\\fR command."
  print ".SH SEE ALSO"
  print "\\fBtldr\\fR(1), \\fBstarship\\fR(1), \\fBwsl-firstrun\\fR"
}
' "$TSV" > "$OUT"

echo "Wrote $OUT"
