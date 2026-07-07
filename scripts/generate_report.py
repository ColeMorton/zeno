#!/usr/bin/env python3
"""Top-level report orchestrator for BTCNFT Protocol simulation results.

Extends the simulation-specific report generator with:
  - Unified CLI for single-run and multi-run reports
  - Automatic discovery of run directories
  - Invariant validation summary printed to stdout
  - Optional auto-open of generated reports

Usage:
    python scripts/generate_report.py [--control-tower] [--open]

By default generates the single-run simulation.html from the latest
contracts/simulation/reports/ data. Pass --control-tower to also
generate the multi-run control_tower.html.
"""

import argparse
import json
import subprocess
import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).parent.parent
SIM_DIR = PROJECT_ROOT / "contracts" / "simulation"
REPORTS_DIR = SIM_DIR / "reports"
SIM_RESULTS_DIR = SIM_DIR / "sim_results"
SIM_REPORT_SCRIPT = SIM_DIR / "scripts" / "generate_report.py"
TOWER_SCRIPT = SIM_DIR / "scripts" / "generate_control_tower.py"
INVARIANTS_PATH = SIM_DIR / "scripts" / "invariants.json"


def load_json(path: Path):
    with open(path) as f:
        return json.load(f)


def check_invariants_summary():
    """Load invariants config and print a human-readable summary."""
    if not INVARIANTS_PATH.exists():
        print("WARNING: No invariants.json found", file=sys.stderr)
        return

    config = load_json(INVARIANTS_PATH)
    invs = config.get("invariants", [])
    print(f"Invariant config loaded: {len(invs)} rules")
    for inv in invs:
        status = "enabled" if inv.get("enabled", True) else "DISABLED"
        sev = inv.get("severity", "critical")
        print(f"  [{sev:8}] {inv.get('label', inv['id']):25} ({status})")
    print()


def generate_simulation_report():
    """Run the simulation-specific report generator."""
    print("=" * 60)
    print("Generating single-run simulation report")
    print("=" * 60)
    result = subprocess.run(
        [sys.executable, str(SIM_REPORT_SCRIPT)],
        cwd=SIM_DIR,
        capture_output=False,
    )
    if result.returncode != 0:
        print("ERROR: Simulation report generation failed", file=sys.stderr)
        return False
    return True


def generate_control_tower():
    """Run the control tower multi-run report generator."""
    print()
    print("=" * 60)
    print("Generating multi-run control tower")
    print("=" * 60)
    result = subprocess.run(
        [sys.executable, str(TOWER_SCRIPT)],
        cwd=SIM_DIR,
        capture_output=False,
    )
    if result.returncode != 0:
        print("ERROR: Control tower generation failed", file=sys.stderr)
        return False
    return True


def open_report(path: Path):
    """Open the generated report in the default browser (macOS)."""
    if sys.platform == "darwin" and path.exists():
        import os
        os.system(f'open "{path}"')


def main():
    parser = argparse.ArgumentParser(
        description="Generate BTCNFT Protocol simulation reports."
    )
    parser.add_argument(
        "--control-tower",
        action="store_true",
        help="Also generate the multi-run control tower dashboard",
    )
    parser.add_argument(
        "--open",
        action="store_true",
        help="Auto-open generated reports in the default browser",
    )
    parser.add_argument(
        "--check-only",
        action="store_true",
        help="Only print invariant config summary and exit",
    )
    args = parser.parse_args()

    check_invariants_summary()

    if args.check_only:
        return

    ok = generate_simulation_report()
    if not ok:
        sys.exit(1)

    if args.control_tower:
        ok = generate_control_tower()
        if not ok:
            sys.exit(1)

    print()
    print("=" * 60)
    print("Report generation complete")
    print("=" * 60)
    print(f"  Single-run report: {REPORTS_DIR / 'simulation.html'}")
    if args.control_tower:
        print(f"  Control tower:     {REPORTS_DIR / 'control_tower.html'}")

    if args.open:
        open_report(REPORTS_DIR / "simulation.html")
        if args.control_tower:
            open_report(REPORTS_DIR / "control_tower.html")


if __name__ == "__main__":
    main()
