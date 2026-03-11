The user wants to 3D print something. Their request: $ARGUMENTS

## Setup
- Print pipeline is at ~/src/print-pipeline/
- Printer: Prusa Core One (HF 0.4 nozzle) at 192.168.1.163
- PrusaSlicer CLI at: /Applications/Original Prusa Drivers/PrusaSlicer.app/Contents/MacOS/PrusaSlicer
- Profiles: "0.20mm SPEED @COREONE HF0.4" / "Generic PLA @COREONE HF0.4" / "Prusa CORE One HF0.4 nozzle"

## Steps

### Step 1: Get the model

**If generating from scratch:**
1. Write an OpenSCAD file to ~/src/print-pipeline/tmp/model.scad. Keep it simple — primitives and boolean ops. Think about printability: flat base on the bed, no unsupported overhangs, minimum wall thickness 1.2mm. Include a `count` parameter if they specified a quantity.
2. Render to STL:
   ```
   openscad -o ~/src/print-pipeline/tmp/model.stl ~/src/print-pipeline/tmp/model.scad
   ```

**If the user provides an STL file**, skip to Step 2.

### Step 2: Review — STOP HERE AND WAIT

Open the STL in PrusaSlicer so the user can visually inspect it:
```
open -a "/Applications/Original Prusa Drivers/PrusaSlicer.app" ~/src/print-pipeline/tmp/model.stl
```

Tell the user: "Take a look at the model in PrusaSlicer. Let me know if you want any changes, or say 'go' to print."

**Do NOT proceed until the user confirms.** If they give feedback, update the .scad file, re-render, and re-open in PrusaSlicer. Repeat until they're happy.

### Step 3: Slice

```
~/src/print-pipeline/print.sh slice ~/src/print-pipeline/tmp/model.stl
```

### Step 4: Upload and print

```
~/src/print-pipeline/print.sh upload ~/src/print-pipeline/tmp/model.bgcode true
```

### Step 5: Confirm

```
~/src/print-pipeline/print.sh status
```

Report the printer state and estimated time to the user.
