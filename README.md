# print-pipeline

Talk to Claude Code, get a 3D print.

```
/print 4 snack bag clips
```

An end-to-end CLI that chains AI model generation → PrusaSlicer → PrusaLink to go from a text description to a running print job on your Prusa printer.

## How it works

```
You: "/print a phone stand"
  │
  ├─ Claude writes OpenSCAD → renders STL
  ├─ Opens in PrusaSlicer for you to review
  ├─ You say "go" or give feedback
  ├─ PrusaSlicer CLI slices → bgcode
  └─ PrusaLink API uploads + starts the print
```

You can also skip the AI generation and just hand it an STL:

```
/print slice and print ~/Downloads/phone_stand.stl
```

## Setup

Clone this repo, open Claude Code, and say:

```
Read BLUEPRINT.md and set up my environment
```

Claude will walk you through finding your PrusaSlicer, connecting to your printer, and installing the `/print` slash command.

### Requirements

- macOS (Linux with path adjustments)
- [PrusaSlicer](https://www.prusa3d.com/page/prusaslicer_424/)
- A Prusa printer with [PrusaLink](https://help.prusa3d.com/article/prusa-connect-and-prusalink-explained_302608) enabled (Core One, MK4, MINI, XL)
- [Claude Code](https://docs.anthropic.com/en/docs/claude-code)
- [OpenSCAD](https://openscad.org/) (auto-installed during setup)

### Manual setup

If you'd rather set it up yourself:

1. `brew install --cask openscad`
2. Copy `.env.example` to `.env` and fill in your printer IP, API key, and PrusaSlicer path
3. Copy `.claude/commands/print.md` to `~/.claude/commands/print.md`
4. `./print.sh status` to test

## CLI usage

```bash
./print.sh status                    # Printer state (temp, progress)
./print.sh slice model.stl           # Slice STL → bgcode
./print.sh upload model.bgcode       # Upload to printer
./print.sh upload model.bgcode true  # Upload + start printing
./print.sh print FILENAME.BGC        # Start an already-uploaded file
```

## Limitations

- **AI-generated models need review.** Claude writes OpenSCAD blind — it can't see the geometry. Simple mechanical parts (clips, brackets, boxes) work okay. Organic shapes don't. Always review in PrusaSlicer before printing.
- **No automatic STL downloads.** Thingiverse/Printables block programmatic access. For proven models, download manually and pass the path.
- **PrusaLink only.** OctoPrint support would be straightforward to add but isn't implemented.

## License

MIT
