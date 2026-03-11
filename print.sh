#!/bin/bash
#
# print.sh — End-to-end 3D print pipeline
#
# Usage:
#   ./print.sh generate "a snack bag clip" --count 4
#   ./print.sh slice model.stl
#   ./print.sh upload model.bgcode
#   ./print.sh print model.bgcode
#   ./print.sh auto "a snack bag clip" --count 4   # full pipeline: generate → slice → upload → print
#   ./print.sh status
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/.env"

TMP_DIR="$SCRIPT_DIR/tmp"
mkdir -p "$TMP_DIR"

# ── Helpers ──────────────────────────────────────────────────

prusalink() {
  local method="$1" path="$2"
  shift 2
  curl -s -m 30 -X "$method" \
    "${PRUSALINK_HOST}${path}" \
    -H "X-Api-Key: $PRUSALINK_API_KEY" \
    "$@"
}

log() { echo "▸ $*" >&2; }
err() { echo "✗ $*" >&2; exit 1; }

# ── Commands ─────────────────────────────────────────────────

cmd_status() {
  log "Checking printer status..."
  prusalink GET /api/v1/status | python3 -m json.tool
}

cmd_generate() {
  local description="$1"
  local count="${2:-1}"
  local scad_file="$TMP_DIR/model.scad"
  local stl_file="$TMP_DIR/model.stl"

  log "Generating OpenSCAD model: $description (count: $count)"

  # Claude (or any AI) writes the .scad file, then we render it
  if [[ -f "$scad_file" ]]; then
    log "Rendering $scad_file → $stl_file"
    openscad -o "$stl_file" "$scad_file"
    log "STL generated: $stl_file"
    echo "$stl_file"
  else
    err "No .scad file found at $scad_file. Write the OpenSCAD code first."
  fi
}

cmd_slice() {
  local stl_file="$1"
  local basename
  basename="$(basename "$stl_file" .stl)"
  local bgcode_file="$TMP_DIR/${basename}.bgcode"

  [[ -f "$stl_file" ]] || err "STL file not found: $stl_file"

  log "Slicing $stl_file → $bgcode_file"
  log "  Printer: $PRINTER_PROFILE"
  log "  Print:   $PRINT_PROFILE"
  log "  Filament: $FILAMENT_PROFILE"

  "$PRUSASLICER_BIN" \
    --export-gcode \
    --binary-gcode \
    --printer-profile "$PRINTER_PROFILE" \
    --print-profile "$PRINT_PROFILE" \
    --material-profile "$FILAMENT_PROFILE" \
    --output "$bgcode_file" \
    "$stl_file" 2>&1

  [[ -f "$bgcode_file" ]] || err "Slicing failed — no output file generated"
  log "Sliced: $bgcode_file ($(du -h "$bgcode_file" | cut -f1))"
  echo "$bgcode_file"
}

cmd_upload() {
  local bgcode_file="$1"
  local print_after="${2:-false}"
  local remote_name
  remote_name="$(basename "$bgcode_file")"

  [[ -f "$bgcode_file" ]] || err "File not found: $bgcode_file"

  local print_header="Print-After-Upload: ?0"
  if [[ "$print_after" == "true" ]]; then
    print_header="Print-After-Upload: ?1"
  fi

  log "Uploading $remote_name to printer..."
  local response
  response=$(curl -s -m 120 -X PUT \
    "${PRUSALINK_HOST}/api/v1/files/usb/${remote_name}" \
    -H "X-Api-Key: $PRUSALINK_API_KEY" \
    -H "Content-Type: application/octet-stream" \
    -H "Overwrite: ?1" \
    -H "$print_header" \
    --data-binary "@$bgcode_file" \
    -w "\n%{http_code}" 2>&1)

  local http_code
  http_code=$(echo "$response" | tail -1)
  local body
  body=$(echo "$response" | sed '$d')

  if [[ "$http_code" == "201" || "$http_code" == "200" ]]; then
    log "Uploaded successfully: $remote_name"
    # Extract the 8.3 filename from the response for printing
    local short_name
    short_name=$(echo "$body" | python3 -c "import sys,json; print(json.load(sys.stdin)['name'])" 2>/dev/null || echo "$remote_name")
    echo "$short_name"
  else
    err "Upload failed (HTTP $http_code): $body"
  fi
}

cmd_print() {
  local remote_name="$1"
  log "Starting print: usb/$remote_name"

  local http_code
  http_code=$(prusalink POST "/api/v1/files/usb/${remote_name}" \
    -w "%{http_code}" -o /dev/null 2>&1)

  if [[ "$http_code" == "204" ]]; then
    log "Print started!"
  elif [[ "$http_code" == "409" ]]; then
    err "Printer busy — a print may already be running, or the LCD isn't on the main screen."
  else
    log "Print command returned HTTP $http_code. Check printer display."
  fi

  sleep 2
  cmd_status
}

cmd_auto() {
  local description="$1"
  local count="${2:-1}"

  log "=== AUTO PIPELINE ==="
  log "Description: $description"
  log "Count: $count"
  echo ""

  # Step 1: Generate STL
  local stl_file
  stl_file=$(cmd_generate "$description" "$count")

  # Step 2: Slice
  local bgcode_file
  bgcode_file=$(cmd_slice "$stl_file")

  # Step 3: Upload and print
  local remote_name
  remote_name=$(cmd_upload "$bgcode_file" "true")

  echo ""
  log "Upload complete. Print should start automatically."
  sleep 3
  cmd_status
}

# ── Main ─────────────────────────────────────────────────────

case "${1:-help}" in
  status)   cmd_status ;;
  generate) cmd_generate "${2:?Usage: print.sh generate DESCRIPTION [COUNT]}" "${3:-1}" ;;
  slice)    cmd_slice "${2:?Usage: print.sh slice FILE.stl}" ;;
  upload)   cmd_upload "${2:?Usage: print.sh upload FILE.bgcode}" ;;
  print)    cmd_print "${2:?Usage: print.sh print REMOTE_NAME}" ;;
  auto)     cmd_auto "${2:?Usage: print.sh auto DESCRIPTION [COUNT]}" "${3:-1}" ;;
  help)
    echo "Usage: print.sh {status|generate|slice|upload|print|auto} [args]"
    echo ""
    echo "Commands:"
    echo "  status                         Check printer status"
    echo "  generate DESCRIPTION [COUNT]   Render OpenSCAD model to STL"
    echo "  slice FILE.stl                 Slice STL to bgcode"
    echo "  upload FILE.bgcode             Upload bgcode to printer"
    echo "  print REMOTE_NAME              Start printing uploaded file"
    echo "  auto DESCRIPTION [COUNT]       Full pipeline: generate → slice → upload → print"
    ;;
  *) err "Unknown command: $1. Run './print.sh help' for usage." ;;
esac
