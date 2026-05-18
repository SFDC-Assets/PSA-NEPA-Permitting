#!/usr/bin/env python3
"""
Load NEPA Decision Matrix rows and activate Decision Matrix + Expression Set versions.

Replaces the manual BRE UI workflow:
  create new version → import CSV → deactivate empty original version

Correct sequence per Salesforce BRE platform behavior:
  1. Query the deployed DMDV (status=Draft, CMV.IsEnabled=False after Metadata API deploy)
  2. Insert CalculationMatrixRows while the version is NOT enabled
     (rows cannot be modified on an enabled CMV)
  3. Activate the DMDV via Tooling API PATCH (Metadata.status="Active")
     → This sets CMV.IsEnabled=True and DMDV.Status=Active atomically

Usage:
  python3 scripts/load_decision_matrix_rows.py --org <alias>
  python3 scripts/load_decision_matrix_rows.py --org <alias> --dry-run
  python3 scripts/load_decision_matrix_rows.py --org <alias> --dm NEPA_Risk_Agency --dm NEPA_Risk_Circuit

Options:
  --org <alias>         Salesforce org alias (required)
  --dry-run             Print row counts and DM names without writing to org
  --dm <name>           Limit to specific DM developer name(s) (repeatable)
  --activate-es         Also activate Expression Set versions after DMs
  --skip-existing       Skip DMs whose CMV already has LoadProcessStatus=Completed or IsEnabled=True
  --csv-dir <path>      Path to CSV directory (default: decision_matrix_rows/)
"""

import argparse
import csv
import hashlib
import json
import os
import subprocess
import sys
import urllib.parse

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.dirname(SCRIPT_DIR)

# Map: DMDV DeveloperName → {csv_file, input_cols, output_cols}
DM_CONFIG = {
    "NEPA_Risk_Agency_V1": {
        "csv": "NEPA_Risk_Agency.csv",
        "input_cols": ["AgencyName"],
        "output_cols": ["Points", "MatchScore"],
    },
    "NEPA_Risk_Circuit_V1": {
        "csv": "NEPA_Risk_Circuit.csv",
        "input_cols": ["CircuitKey"],
        "output_cols": ["Points", "MatchScore"],
    },
    "NEPA_Risk_ReviewType_V1": {
        "csv": "NEPA_Risk_ReviewType.csv",
        "input_cols": ["ReviewType"],
        "output_cols": ["Points"],
    },
    "NEPA_Risk_SectorCircuit_V1": {
        "csv": "NEPA_Risk_SectorCircuit.csv",
        "input_cols": ["SectorCircuitKey"],
        "output_cols": ["WinRatePct", "CaseCount", "RiskCellLabel"],
    },
    "NEPA_CE_Screener_NAICS_V1": {
        "csv": "NEPA_CE_Screener_NAICS.csv",
        "input_cols": ["NAICSCode"],
        "output_cols": ["ReviewType", "CECode", "Confidence", "ClassificationBasis"],
    },
    "NEPA_CE_Screener_Tier1_V1": {
        "csv": "NEPA_CE_Screener_Tier1.csv",
        "input_cols": ["AgencyAbbr", "SectorKey", "TypeKey"],
        "output_cols": ["ReviewType", "CECode", "Confidence", "ClassificationBasis"],
    },
    "NEPA_CE_Screener_Tier2_V1": {
        "csv": "NEPA_CE_Screener_Tier2.csv",
        "input_cols": ["AgencyAbbr", "ActionType"],
        "output_cols": ["ReviewType", "CECode", "Confidence", "ClassificationBasis"],
    },
    "NEPA_Permit_Matrix_BRE_V1": {
        "csv": "NEPA_Permit_Matrix_BRE.csv",
        "input_cols": ["Sector", "ProjectType"],
        "output_cols": ["RequiredPermits", "CooperatingAgencies"],
    },
}

# Expression Set version developer names to activate
ES_VERSIONS = [
    "NEPA_CE_Screener_V3",
    "NEPA_Permit_Coordinator_V1",
    "NEPA_Litigation_Risk_Scorer_V1",
]


def run_sf(args, capture=True):
    """Run an sf CLI command and return stdout."""
    cmd = ["sf"] + args
    result = subprocess.run(cmd, capture_output=capture, text=True)
    return result.stdout if capture else None


def get_org_connection(org_alias):
    """Return (instance_url, access_token) for the given org alias."""
    raw = run_sf(["org", "display", "--target-org", org_alias, "--json"])
    lines = raw.splitlines()
    start = next(i for i, l in enumerate(lines) if l.strip().startswith("{"))
    data = json.loads("\n".join(lines[start:]))
    result = data["result"]
    return result["instanceUrl"], result["accessToken"]


def tooling_query(base_url, token, soql):
    """Run a Tooling API SOQL query and return records list."""
    import http.client

    encoded = urllib.parse.quote(soql)
    parsed = urllib.parse.urlparse(base_url)
    conn = http.client.HTTPSConnection(parsed.hostname)
    try:
        conn.request("GET", f"/services/data/v62.0/tooling/query/?q={encoded}",
                     headers={"Authorization": f"Bearer {token}"})
        resp = conn.getresponse()
        return json.loads(resp.read()).get("records", [])
    finally:
        conn.close()


def tooling_patch(base_url, token, sobject, record_id, payload):
    """PATCH a Tooling API record. Returns (success, error_message)."""
    import http.client

    body = json.dumps(payload).encode()
    parsed = urllib.parse.urlparse(base_url)
    conn = http.client.HTTPSConnection(parsed.hostname)
    path = f"/services/data/v62.0/tooling/sobjects/{sobject}/{record_id}"
    try:
        conn.request(
            "PATCH",
            path,
            body=body,
            headers={
                "Authorization": f"Bearer {token}",
                "Content-Type": "application/json",
            },
        )
        resp = conn.getresponse()
        resp_body = resp.read()
        if resp.status in (200, 204):
            return True, None
        return False, f"HTTP {resp.status}: {resp_body[:200].decode(errors='replace')}"
    except Exception as e:
        return False, str(e)
    finally:
        conn.close()


def rest_post(base_url, token, sobject, payload):
    """POST a record via Data REST API. Returns (id, success, errors)."""
    import http.client

    body = json.dumps(payload).encode()
    parsed = urllib.parse.urlparse(base_url)
    conn = http.client.HTTPSConnection(parsed.hostname)
    path = f"/services/data/v62.0/sobjects/{sobject}"
    try:
        conn.request(
            "POST",
            path,
            body=body,
            headers={
                "Authorization": f"Bearer {token}",
                "Content-Type": "application/json",
            },
        )
        resp = conn.getresponse()
        data = json.loads(resp.read())
        if isinstance(data, list):
            return None, False, [e.get("message", str(e)) for e in data]
        return data.get("id"), data.get("success", False), data.get("errors", [])
    except Exception as e:
        return None, False, [str(e)]
    finally:
        conn.close()


def soql_query(base_url, token, soql):
    """Run a Data REST API SOQL query and return records."""
    import http.client

    encoded = urllib.parse.quote(soql)
    parsed = urllib.parse.urlparse(base_url)
    conn = http.client.HTTPSConnection(parsed.hostname)
    try:
        conn.request("GET", f"/services/data/v62.0/query/?q={encoded}",
                     headers={"Authorization": f"Bearer {token}"})
        resp = conn.getresponse()
        return json.loads(resp.read()).get("records", [])
    finally:
        conn.close()


def build_row_name(input_data: dict) -> str:
    """Build an MD5 row name matching Salesforce's format (sorted keys, compact JSON)."""
    compact = json.dumps(input_data, sort_keys=True, separators=(",", ":"))
    return hashlib.md5(compact.encode()).hexdigest()


def load_csv_rows(csv_path, input_cols, output_cols):
    """Read a CSV file and return list of (input_data, output_data) dicts."""
    rows = []
    with open(csv_path, newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            input_data = {k: row[k] for k in input_cols if k in row}
            output_data = {}
            for k in output_cols:
                if k not in row:
                    continue
                val = row[k]
                # Coerce numeric outputs to numbers
                try:
                    output_data[k] = int(val) if "." not in val else float(val)
                except (ValueError, TypeError):
                    output_data[k] = val
            rows.append((input_data, output_data))
    return rows


def activate_dmdv(base_url, token, dmdv_id, current_metadata):
    """Activate a DecisionMatrixDefinitionVersion via Tooling API PATCH."""
    metadata = dict(current_metadata)
    metadata["status"] = "Active"
    # Remove fields Tooling API won't accept in PATCH
    for drop in ("urls",):
        metadata.pop(drop, None)
    return tooling_patch(
        base_url, token, "DecisionMatrixDefinitionVersion", dmdv_id, {"Metadata": metadata}
    )


def activate_esdv(base_url, token, esdv_id, current_metadata):
    """Activate an ExpressionSetDefinitionVersion via Tooling API PATCH."""
    metadata = dict(current_metadata)
    metadata["status"] = "Active"
    for drop in ("urls",):
        metadata.pop(drop, None)
    return tooling_patch(
        base_url, token, "ExpressionSetDefinitionVersion", esdv_id, {"Metadata": metadata}
    )


def process_dm(
    base_url, token, dmdv_dev_name, config, csv_dir, dry_run, skip_existing
):
    """Load rows and activate one Decision Matrix version."""
    csv_path = os.path.join(csv_dir, config["csv"])
    if not os.path.exists(csv_path):
        print(f"  [SKIP] {dmdv_dev_name} — CSV not found: {csv_path}")
        return False

    # Query DMDV
    recs = tooling_query(
        base_url,
        token,
        f"SELECT Id, DeveloperName, Status, Metadata FROM DecisionMatrixDefinitionVersion "
        f"WHERE DeveloperName = '{dmdv_dev_name}'",
    )
    if not recs:
        print(f"  [SKIP] {dmdv_dev_name} — DMDV not found in org (deploy DMs first)")
        return False

    dmdv = recs[0]
    dmdv_id = dmdv["Id"]
    current_status = dmdv.get("Status", "")
    current_metadata = dmdv.get("Metadata", {})

    # Query corresponding CMV
    cmv_recs = soql_query(
        base_url,
        token,
        f"SELECT Id, Name, IsEnabled, LoadProcessStatus FROM CalculationMatrixVersion "
        f"WHERE DecisionMatrixDefinitionVerId = '{dmdv_id}'",
    )
    if not cmv_recs:
        print(f"  [SKIP] {dmdv_dev_name} — no CalculationMatrixVersion linked to DMDV")
        return False

    cmv = cmv_recs[0]
    cmv_id = cmv["Id"]
    is_enabled = cmv.get("IsEnabled", False)
    load_status = cmv.get("LoadProcessStatus")

    if skip_existing and (current_status == "Active" or load_status == "Completed"):
        print(
            f"  [SKIP] {dmdv_dev_name} — already Active/Completed (use --no-skip to reload)"
        )
        return True

    rows = load_csv_rows(csv_path, config["input_cols"], config["output_cols"])
    print(f"  {dmdv_dev_name}: {len(rows)} rows from {config['csv']}, DMDV.Status={current_status}, CMV.IsEnabled={is_enabled}")

    if dry_run:
        print(f"    [DRY-RUN] would insert {len(rows)} rows then activate")
        return True

    # Insert rows (only safe while CMV is NOT enabled)
    if is_enabled:
        print(
            f"  [WARN] CMV is already enabled — cannot insert rows. "
            "This DM was already activated. Skipping row load."
        )
    else:
        inserted = 0
        errors = 0
        for input_data, output_data in rows:
            row_name = build_row_name(input_data)
            rec_id, success, errs = rest_post(
                base_url,
                token,
                "CalculationMatrixRow",
                {
                    "CalculationMatrixVersionId": cmv_id,
                    "Name": row_name,
                    "InputData": json.dumps(input_data),
                    "OutputData": json.dumps(output_data),
                },
            )
            if success:
                inserted += 1
            else:
                errors += 1
                if errors <= 3:
                    print(f"    [ROW-ERROR] {input_data}: {errs}")
        print(f"    Inserted {inserted}/{len(rows)} rows ({errors} errors)")
        if errors > 0 and errors == len(rows):
            print(f"  [FAIL] All rows failed — not activating {dmdv_dev_name}")
            return False

    # Activate DMDV (only needed when transitioning from Draft → Active)
    if current_status == "Active":
        print(f"    Already Active — no activation needed")
    else:
        ok, err = activate_dmdv(base_url, token, dmdv_id, current_metadata)
        if ok:
            print(f"    Activated DMDV {dmdv_dev_name}")
        else:
            print(f"    [FAIL] Activation failed: {err}")
            return False

    return True


def process_expression_sets(base_url, token, es_names, dry_run):
    """Activate Expression Set versions."""
    print()
    print("  Activating Expression Set versions...")
    for dev_name in es_names:
        recs = tooling_query(
            base_url,
            token,
            f"SELECT Id, DeveloperName, Status, Metadata FROM ExpressionSetDefinitionVersion "
            f"WHERE DeveloperName = '{dev_name}'",
        )
        if not recs:
            print(f"  [SKIP] {dev_name} — ESDV not found (deploy ES first)")
            continue

        esdv = recs[0]
        esdv_id = esdv["Id"]
        current_status = esdv.get("Status", "")
        current_metadata = esdv.get("Metadata", {})

        if current_status == "Active":
            print(f"  [OK] {dev_name} — already Active")
            continue

        if dry_run:
            print(f"  [DRY-RUN] would activate ESDV {dev_name} (currently {current_status})")
            continue

        ok, err = activate_esdv(base_url, token, esdv_id, current_metadata)
        if ok:
            print(f"  [OK] Activated {dev_name}")
        else:
            print(f"  [FAIL] {dev_name}: {err}")


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--org", required=True, help="Salesforce org alias")
    parser.add_argument("--dry-run", action="store_true", help="Preview without writing")
    parser.add_argument("--dm", action="append", dest="dms", default=[], help="Limit to DM developer names (repeatable)")
    parser.add_argument("--activate-es", action="store_true", help="Also activate Expression Set versions")
    parser.add_argument("--skip-existing", action="store_true", default=True, help="Skip DMs already Active/Completed (default: on)")
    parser.add_argument("--no-skip", action="store_false", dest="skip_existing", help="Re-process even Active/Completed DMs")
    parser.add_argument("--csv-dir", default=os.path.join(REPO_ROOT, "decision_matrix_rows"), help="Path to CSV directory")
    args = parser.parse_args()

    print(f"==> BRE Decision Matrix row loader")
    print(f"    Org:     {args.org}")
    print(f"    CSV dir: {args.csv_dir}")
    print(f"    Mode:    {'DRY-RUN' if args.dry_run else 'LIVE'}")
    print()

    base_url, token = get_org_connection(args.org)

    # Determine which DMs to process
    if args.dms:
        # User specified DM developer names without _V1 suffix — normalize
        requested = set()
        for dm in args.dms:
            requested.add(dm if dm.endswith("_V1") else dm + "_V1")
        configs = {k: v for k, v in DM_CONFIG.items() if k in requested}
        missing = requested - set(configs)
        for m in missing:
            print(f"  [WARN] {m} not in DM_CONFIG — skipping")
    else:
        configs = DM_CONFIG

    print(f"  Processing {len(configs)} Decision Matrix version(s)...")

    success_count = 0
    for dmdv_dev_name, config in configs.items():
        ok = process_dm(
            base_url, token, dmdv_dev_name, config, args.csv_dir,
            args.dry_run, args.skip_existing
        )
        if ok:
            success_count += 1

    print()
    print(f"  DM processing complete: {success_count}/{len(configs)} succeeded")

    if args.activate_es:
        process_expression_sets(base_url, token, ES_VERSIONS, args.dry_run)

    print()
    print("==> Done.")


if __name__ == "__main__":
    main()
