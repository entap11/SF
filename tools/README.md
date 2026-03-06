# Tools

## fix_lane_alpha.py

Detects baked checkerboard pixels in `lane_final.png` and writes a cleaned
`lane_final_fixed.png` with real transparency. It also updates
`assets/sprites/sf_skin_v1/skin_manifest.json` to point lane sprites to the
fixed file if (and only if) a baked checkerboard is detected.

### Requirements
- Python 3
- Pillow
- numpy

Install dependencies (example):

```
pip3 install pillow numpy
```

### Run
Start the rank Postgres once (if not already running):

```bash
cd tools/rank-service && docker compose up -d
```

From repo root:

```
python3 tools/fix_lane_alpha.py
```

The script prints:
- `baked_checkered=<true/false>`
- `checker_colors=<rgb1> <rgb2>`
- `wrote=<path>`

Re-running is safe and idempotent.

## run_with_rank_service.sh

Starts the dedicated rank service and then launches Godot so local boots use central rank state.

### Run
From repo root:

```bash
./tools/run_with_rank_service.sh
```

Optional arguments are forwarded to `godot`, for example:

```bash
./tools/run_with_rank_service.sh --headless -s tools/rank_system_smoke_test.gd
```

If Postgres is elsewhere, set `RANK_DATABASE_URL` when launching:

```bash
RANK_DATABASE_URL=postgres://user:pass@host:5432/swarmfront_rank ./tools/run_with_rank_service.sh
```
