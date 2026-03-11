# Print Pipeline — Setup Blueprint

> Tell Claude Code: "Read BLUEPRINT.md and set up my environment"

This is an AI-to-3D-printer pipeline. You describe what you want to print, Claude generates or sources the model, slices it, and sends it to your printer. It works with PrusaSlicer and any printer that speaks PrusaLink (Prusa Core One, MK4, MINI, XL).

## What you'll get

- A `/print` slash command for Claude Code — say `/print 4 bag clips` and it handles the rest
- A `print.sh` CLI that chains: OpenSCAD (generate STL) → PrusaSlicer (slice) → PrusaLink (upload & print)
- Human-in-the-loop review step: Claude opens the model in PrusaSlicer for you to inspect before printing

## Prerequisites

- macOS (Linux should work with path adjustments)
- [PrusaSlicer](https://www.prusa3d.com/page/prusaslicer_424/) installed
- A Prusa printer with PrusaLink enabled (check printer Settings > Network)
- [Claude Code](https://claude.ai/claude-code) installed

## Setup Instructions (for Claude)

When the user asks you to set up this project, follow these steps:

### 1. Install OpenSCAD

```bash
brew install --cask openscad
# If macOS blocks it:
xattr -dr com.apple.quarantine /Applications/OpenSCAD-2021.01.app
```

### 2. Find PrusaSlicer

Check these common locations:
```bash
ls "/Applications/Original Prusa Drivers/PrusaSlicer.app/Contents/MacOS/PrusaSlicer"
ls "/Applications/PrusaSlicer.app/Contents/MacOS/PrusaSlicer"
```

### 3. Get printer profiles

Run PrusaSlicer CLI to discover available profiles:
```bash
PRUSASLICER="<path from step 2>"
"$PRUSASLICER" --query-printer-models --printer-technology FFF 2>/dev/null | python3 -m json.tool
```

Also check the active profiles in `~/Library/Application Support/PrusaSlicer/PrusaSlicer.ini` — look for the `[presets]` section which lists the user's current printer, print, and filament profiles.

### 4. Get printer connection info

Ask the user for:
- **Printer IP address** — found on the printer under Settings > Network, or Settings > PrusaLink
- **PrusaLink API key** — shown in the same PrusaLink settings screen

Test the connection:
```bash
curl -s -m 15 "http://<PRINTER_IP>/api/v1/status" -H "X-Api-Key: <API_KEY>" | python3 -m json.tool
```

### 5. Create .env file

Create `.env` in the project root (this file is gitignored):
```
PRUSALINK_HOST="http://<PRINTER_IP>"
PRUSALINK_API_KEY="<API_KEY>"
PRUSASLICER_BIN="<path to PrusaSlicer binary>"
PRINTER_PROFILE="<printer profile name from step 3>"
PRINT_PROFILE="<print profile name from step 3>"
FILAMENT_PROFILE="<filament profile name from step 3>"
```

### 6. Install the slash command globally

```bash
mkdir -p ~/.claude/commands
cp .claude/commands/print.md ~/.claude/commands/print.md
```

### 7. Test the pipeline

```bash
# Check printer connection
./print.sh status

# Test slicing (use any STL file)
./print.sh slice some_model.stl
```

## Usage

From any Claude Code session:

```
/print 4 bag clips
/print a phone stand with cable hole
/print slice and print ~/Downloads/model.stl
```

Claude will generate the model, open it in PrusaSlicer for your review, then slice and send to the printer after you confirm.

### Manual CLI usage

```bash
./print.sh status                    # Check printer state
./print.sh slice model.stl           # Slice an STL to bgcode
./print.sh upload model.bgcode       # Upload to printer
./print.sh upload model.bgcode true  # Upload and start printing
./print.sh print FILENAME.BGC        # Start printing an uploaded file
```

## How it works

```
You: "/print 4 bag clips"
  │
  ├─ Claude writes OpenSCAD code → tmp/model.scad
  ├─ openscad renders → tmp/model.stl
  ├─ Opens in PrusaSlicer for review ← YOU LOOK AT IT HERE
  ├─ You say "go" (or give feedback for iteration)
  ├─ PrusaSlicer CLI slices → tmp/model.bgcode
  ├─ PrusaLink API uploads to printer
  └─ PrusaLink API starts the print
```

## API Reference

This project uses PrusaLink v1 API:

| Action | Method | Endpoint |
|--------|--------|----------|
| Printer status | GET | `/api/v1/status` |
| List files | GET | `/api/v1/files/usb` |
| Upload file | PUT | `/api/v1/files/usb/<filename>` |
| Start print | POST | `/api/v1/files/usb/<filename>` |

Headers: `X-Api-Key: <key>`, `Content-Type: application/octet-stream` (for upload), `Print-After-Upload: ?1` (to auto-start), `Overwrite: ?1` (to replace existing).

## Limitations

- AI-generated OpenSCAD models may have printability issues (overhangs, thin walls). Always review in PrusaSlicer before printing.
- Downloading STL files from Thingiverse/Printables programmatically is blocked by those sites. For proven models, download manually and pass the file path to Claude.
- The PrusaSlicer CLI cannot read GUI profiles by name on all systems. If slicing fails with profile errors, export your configs via File > Export > Export Config in the GUI and use `--load` instead of `--printer-profile`.
