#!/usr/bin/env python3
"""
Load nepa_ce_library__c records from the CEQ CE Explorer filtered dataset.

Usage:
    python3 scripts/load_ce_library.py --org <alias> [--all] [--dry-run]

    --org      Target org alias (required for live load)
    --all      Load all 2,105 records from the full exclusions.json
               (default: load only the 314 priority-agency records
               from exclusions_filtered.json)
    --dry-run  Write CSV only, do not call sf CLI

The script:
  1. Reads the source JSON
  2. Writes a CSV to data/ce_library_load.csv
  3. Upserts via `sf data upsert bulk` using nepa_ce_explorer_id__c as the
     external ID (idempotent — safe to re-run after a dataset version update)

Re-run strategy for CE Explorer version updates:
  - Download the new exclusions.json to the repo root
  - Run with --all to refresh all records
  - Records not in the new dataset will NOT be deactivated automatically;
    run a SOQL query to find nepa_dataset_version__c != '<new_version>' and
    set nepa_active__c = false on those records.
"""

import argparse
import csv
import json
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).parent.parent
FILTERED = REPO / "exclusions_filtered.json"
FULL = REPO / "exclusions.json"
CSV_OUT = REPO / "data" / "ce_library_load.csv"
DATASET_VERSION = "2.0.0"

AGENCY_MAP = {
    "DOD - USACE": "USACE",
    "DOE":         "DOE",
    "DOI - BLM":   "BLM",
    "DOI - USFWS": "USFWS",
    "DOT - FHWA":  "FHWA",
    "FERC":        "FERC",
}

FIELDS = [
    "nepa_ce_explorer_id__c",
    "nepa_source_id__c",
    "nepa_agency_abbr__c",
    "nepa_agency_name__c",
    "nepa_origin__c",
    "nepa_source_url__c",
    "nepa_context__c",
    "nepa_exclusion_text__c",
    "nepa_extraordinary_circumstances__c",
    "nepa_dataset_version__c",
    "nepa_active__c",
]


def flatten(data: dict | list) -> list[dict]:
    """Accept grouped-by-agency dict or flat array."""
    if isinstance(data, list):
        return data
    recs = []
    for v in data.values():
        recs.extend(v)
    return recs


def to_row(rec: dict) -> dict:
    circ = rec["circumstances"] if rec["circumstances"] != "Not Catalogued" else ""
    return {
        "nepa_ce_explorer_id__c": rec["structuredID"],
        "nepa_source_id__c": rec["id"],
        "nepa_agency_abbr__c": rec["unit"],
        "nepa_agency_name__c": rec["longUnit"],
        "nepa_origin__c": rec["origin"][:255],
        "nepa_source_url__c": rec["originUrl"],
        "nepa_context__c": rec["context"][:255],
        "nepa_exclusion_text__c": rec["exclusion"],
        "nepa_extraordinary_circumstances__c": circ,
        "nepa_dataset_version__c": DATASET_VERSION,
        "nepa_active__c": "true",
    }


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--org", help="Target org alias")
    parser.add_argument("--all", dest="load_all", action="store_true",
                        help="Load full 2,105-record dataset (requires exclusions.json in repo root)")
    parser.add_argument("--dry-run", action="store_true",
                        help="Write CSV only, skip sf CLI upsert")
    args = parser.parse_args()

    if args.load_all:
        source = FULL
        if not source.exists():
            sys.exit(f"ERROR: {source} not found. Download the full exclusions.json from "
                     "https://ce.permitting.innovation.gov/data/exclusions.json first.")
    else:
        source = FILTERED
        if not source.exists():
            sys.exit(f"ERROR: {source} not found.")

    raw = json.loads(source.read_text())
    records = flatten(raw)

    # For filtered source, data is already agency-grouped dict
    if isinstance(raw, dict) and "exclusions" in raw:
        records = raw["exclusions"]

    rows = [to_row(r) for r in records]
    print(f"Records to load: {len(rows)}")

    CSV_OUT.parent.mkdir(parents=True, exist_ok=True)
    with CSV_OUT.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=FIELDS)
        writer.writeheader()
        writer.writerows(rows)
    print(f"CSV written: {CSV_OUT}")

    if args.dry_run or not args.org:
        if not args.org:
            print("No --org specified. CSV written. Run with --org <alias> to load.")
        return

    cmd = [
        "sf", "data", "upsert", "bulk",
        "--sobject", "nepa_ce_library__c",
        "--file", str(CSV_OUT),
        "--external-id", "nepa_ce_explorer_id__c",
        "--target-org", args.org,
        "--line-ending", "CRLF",
        "--wait", "10",
        "--json",
    ]
    print(f"\nRunning: {' '.join(cmd)}")
    result = subprocess.run(cmd, capture_output=True, text=True)
    print(result.stdout)
    if result.returncode != 0:
        print("STDERR:", result.stderr)
        sys.exit(result.returncode)
    print("Load complete.")


if __name__ == "__main__":
    main()
