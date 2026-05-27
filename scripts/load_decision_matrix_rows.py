#!/usr/bin/env python3
"""
Load NEPA Decision Matrix rows and activate Decision Matrix + Expression Set versions.

Replaces the manual BRE UI workflow:
  create new version → import CSV → deactivate empty original version

Correct sequence per Salesforce BRE platform behavior:
  1. Query the deployed DMDV (status=Draft, CMV.IsEnabled=False after Metadata API deploy)
  2. POST rows via the Connect API (/connect/omnistudio/decision-matrices/.../rows)
     — this is the only path that triggers BRE indexing and sets LoadProcessStatus=Completed.
     Direct CalculationMatrixRow REST inserts are SOQL-visible but BRE-invisible.
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
import json
import os
import subprocess
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
    "NEPA_Survey_Priority_Gate_V1": {
        "csv": "NEPA_Survey_Priority_Gate.csv",
        "input_cols": ["Discipline", "ReviewType"],
        "output_cols": ["Priority", "IsHardGate", "WindowStartMonth", "WindowEndMonth"],
    },
}

# Expression Set version developer names to activate.
# Each entry is the ESDV DeveloperName (not the ESD DeveloperName).
# For the Risk Scorer: V1 is the active version — the previous V2/V3 label was
# from a multi-version history that was collapsed into a single Active V1 during
# the Tooling API activation workaround (LatestVersionSnapshotId platform bug).
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


def tooling_get(base_url, token, sobject, record_id, fields="Metadata"):
    """Fetch a single Tooling API record by ID. Returns the parsed JSON body."""
    import http.client

    parsed = urllib.parse.urlparse(base_url)
    conn = http.client.HTTPSConnection(parsed.hostname)
    path = f"/services/data/v62.0/tooling/sobjects/{sobject}/{record_id}?fields={fields}"
    try:
        conn.request("GET", path, headers={"Authorization": f"Bearer {token}"})
        resp = conn.getresponse()
        return json.loads(resp.read())
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


def connect_post_rows(base_url, token, matrix_id, version_id, rows, batch_size=200):
    """POST rows to a Decision Matrix version via the Connect API.

    Uses /connect/omnistudio/decision-matrices/{matrixId}/versions/{versionId}/rows,
    the official documented endpoint that triggers BRE indexing and sets
    LoadProcessStatus=Completed (unlike direct CalculationMatrixRow REST inserts
    which are SOQL-visible but invisible to the BRE evaluation engine).

    rows: list of flat dicts merging input and output column values, e.g.
          [{"CircuitKey": "4th", "Points": "20", "MatchScore": "100"}]
    Returns (inserted_count, error_messages_list).
    """
    import http.client

    inserted = 0
    errors = []
    parsed = urllib.parse.urlparse(base_url)
    path = (
        f"/services/data/v62.0/connect/omnistudio/decision-matrices"
        f"/{matrix_id}/versions/{version_id}/rows"
    )

    for batch_start in range(0, len(rows), batch_size):
        batch = rows[batch_start : batch_start + batch_size]
        payload = json.dumps(
            {"rows": [{"rowData": {k: str(v) for k, v in r.items()}} for r in batch]}
        ).encode()
        conn = http.client.HTTPSConnection(parsed.hostname)
        try:
            conn.request(
                "POST",
                path,
                body=payload,
                headers={
                    "Authorization": f"Bearer {token}",
                    "Content-Type": "application/json",
                },
            )
            resp = conn.getresponse()
            body = resp.read()
            if resp.status in (200, 201):
                inserted += len(batch)
            else:
                try:
                    data = json.loads(body)
                    if isinstance(data, list):
                        msg = "; ".join(e.get("message", str(e)) for e in data)
                    else:
                        msg = data.get("message") or str(data)[:300]
                except Exception:
                    msg = body[:300].decode(errors="replace")
                errors.append(
                    f"batch {batch_start}-{batch_start + len(batch) - 1}: "
                    f"HTTP {resp.status}: {msg}"
                )
        except Exception as e:
            errors.append(f"batch {batch_start}-{batch_start + len(batch) - 1}: {e}")
        finally:
            conn.close()

    return inserted, errors



def load_csv_rows(csv_path, input_cols, output_cols):
    """Read a CSV file and return list of flat row dicts (all columns as strings).

    The Connect API accepts rowData values as strings; no numeric coercion needed.
    """
    all_cols = input_cols + output_cols
    rows = []
    with open(csv_path, newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            rows.append({k: row[k] for k in all_cols if k in row})
    return rows


def create_new_dmdv_version(base_url, token, dmd_dev_name, existing_metadata):
    """Create a new Draft DMDV for an existing DecisionMatrixDefinition.

    Used when the V1 CMV is already enabled (locked) with no rows — typically
    because the metadata deploy activated it before Phase 5b-data could run.
    Returns (new_dmdv_id, error_message).
    """
    import http.client

    # Build new version metadata from existing, bumping versionNumber and forcing Draft.
    # Strip isWildcardColumn/wildcardValue from columns — Decision Matrices are exact-match
    # only; those fields break all DM lookups by causing the platform to ignore row data.
    new_meta = {k: v for k, v in existing_metadata.items() if k not in ("urls", "status", "versionNumber")}
    if "columns" in new_meta:
        cleaned_cols = []
        for col in new_meta["columns"]:
            cleaned_col = {k: v for k, v in col.items() if k not in ("isWildcardColumn", "wildcardValue")}
            cleaned_cols.append(cleaned_col)
        new_meta["columns"] = cleaned_cols
    new_meta["status"] = "Draft"
    # Find the highest existing versionNumber/rank for this DMD to avoid duplicates
    existing_versions = tooling_query(
        base_url, token,
        f"SELECT VersionNumber, Metadata FROM DecisionMatrixDefinitionVersion "
        f"WHERE DecisionMatrixDefinition.DeveloperName = '{dmd_dev_name}' "
        f"ORDER BY VersionNumber DESC LIMIT 1",
    )
    if existing_versions:
        latest_meta = existing_versions[0].get("Metadata") or {}
        max_ver = existing_versions[0].get("VersionNumber") or 1
        max_rank = latest_meta.get("rank") or 1
    else:
        max_ver = existing_metadata.get("versionNumber") or 1
        max_rank = existing_metadata.get("rank") or 1
    new_ver_num_val = max_ver + 1
    new_meta["versionNumber"] = new_ver_num_val
    new_meta["rank"] = max_rank + 1
    new_meta["decisionMatrixDefinition"] = dmd_dev_name
    # startDate is required
    if not new_meta.get("startDate"):
        new_meta["startDate"] = "2025-01-01"

    full_name = f"{dmd_dev_name}_V{new_ver_num_val}"
    new_meta["label"] = full_name.replace("_", " ")

    payload = json.dumps({"FullName": full_name, "Metadata": new_meta}).encode()
    parsed = urllib.parse.urlparse(base_url)
    conn = http.client.HTTPSConnection(parsed.hostname)
    path = "/services/data/v62.0/tooling/sobjects/DecisionMatrixDefinitionVersion/"
    try:
        conn.request("POST", path, body=payload,
                     headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"})
        resp = conn.getresponse()
        data = json.loads(resp.read())
        if isinstance(data, list):
            return None, "; ".join(e.get("message", str(e)) for e in data)
        if data.get("success"):
            return data["id"], None
        return None, str(data.get("errors", data))
    except Exception as e:
        return None, str(e)
    finally:
        conn.close()


def deactivate_cmv(base_url, token, cmv_id):
    """Disable a CalculationMatrixVersion via REST PATCH. Returns (success, error)."""
    import http.client

    payload = json.dumps({"IsEnabled": False}).encode()
    parsed = urllib.parse.urlparse(base_url)
    conn = http.client.HTTPSConnection(parsed.hostname)
    path = f"/services/data/v62.0/sobjects/CalculationMatrixVersion/{cmv_id}"
    try:
        conn.request("PATCH", path, body=payload,
                     headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"})
        resp = conn.getresponse()
        body = resp.read()
        if resp.status in (200, 204):
            return True, None
        data = json.loads(body) if body else []
        msg = data[0].get("message", str(data)) if isinstance(data, list) else str(data)
        return False, msg
    except Exception as e:
        return False, str(e)
    finally:
        conn.close()


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
    current_metadata = dmdv.get("Metadata") or {}

    # Query corresponding CMV (include CalculationMatrixId for Connect API path)
    cmv_recs = soql_query(
        base_url,
        token,
        f"SELECT Id, CalculationMatrixId, IsEnabled, LoadProcessStatus FROM CalculationMatrixVersion "
        f"WHERE DecisionMatrixDefinitionVerId = '{dmdv_id}'",
    )
    if not cmv_recs:
        print(f"  [SKIP] {dmdv_dev_name} — no CalculationMatrixVersion linked to DMDV")
        return False

    cmv = cmv_recs[0]
    cmv_id = cmv["Id"]
    matrix_id = cmv["CalculationMatrixId"]
    is_enabled = cmv.get("IsEnabled", False)
    load_status = cmv.get("LoadProcessStatus")

    # Only skip if rows are confirmed loaded (LoadProcessStatus=Completed).
    # DMDV.Status=Active alone is not sufficient — the metadata deploy can
    # activate the CMV before rows are inserted, leaving an empty active matrix.
    if skip_existing and load_status == "Completed":
        print(
            f"  [SKIP] {dmdv_dev_name} — rows already loaded (use --no-skip to reload)"
        )
        return True

    rows = load_csv_rows(csv_path, config["input_cols"], config["output_cols"])
    print(f"  {dmdv_dev_name}: {len(rows)} rows from {config['csv']}, DMDV.Status={current_status}, CMV.IsEnabled={is_enabled}")

    if dry_run:
        print(f"    [DRY-RUN] would insert {len(rows)} rows then activate")
        return True

    # Insert rows via Connect API (triggers BRE indexing and sets LoadProcessStatus=Completed).
    # Recovery path: if CMV is already enabled with no rows (metadata deploy activated it
    # before rows were loaded), create a new Draft version, load rows into it, activate
    # it, then deactivate the old empty version.
    if is_enabled:
        print(
            f"  [WARN] CMV IsEnabled=True but LoadProcessStatus={load_status} — "
            "DM was activated before rows were loaded. Creating new Draft version to recover..."
        )
        dmd_dev_name = dmdv_dev_name.rsplit("_V", 1)[0]  # strip _V1 suffix
        new_dmdv_id, err = create_new_dmdv_version(base_url, token, dmd_dev_name, current_metadata)
        if err:
            print(f"  [ERROR] Could not create new DMDV version: {err}")
            return False
        print(f"    Created new Draft DMDV: {new_dmdv_id}")

        # Get the new CMV and its parent CalculationMatrix ID
        new_cmv_recs = soql_query(
            base_url, token,
            f"SELECT Id, CalculationMatrixId FROM CalculationMatrixVersion "
            f"WHERE DecisionMatrixDefinitionVerId = '{new_dmdv_id}'"
        )
        if not new_cmv_recs:
            print(f"  [ERROR] No CMV linked to new DMDV {new_dmdv_id}")
            return False
        new_cmv_id = new_cmv_recs[0]["Id"]
        new_matrix_id = new_cmv_recs[0]["CalculationMatrixId"]
        old_cmv_id = cmv["Id"]
        print(f"    New CMV: {new_cmv_id}  (old empty CMV: {old_cmv_id})")

        inserted, errs = connect_post_rows(base_url, token, new_matrix_id, new_cmv_id, rows)
        for e in errs[:3]:
            print(f"    [ROW-ERROR] {e}")
        print(f"    Inserted {inserted}/{len(rows)} rows into new version ({len(errs)} errors)")
        if errs and inserted == 0:
            print(f"  [FAIL] All rows failed — not activating new version")
            return False

        # Activate new version
        new_dmdv_rec = tooling_query(
            base_url, token,
            f"SELECT Id, Status, Metadata FROM DecisionMatrixDefinitionVersion WHERE Id = '{new_dmdv_id}'"
        )
        new_meta = new_dmdv_rec[0].get("Metadata", {}) if new_dmdv_rec else {}
        ok, err = activate_dmdv(base_url, token, new_dmdv_id, new_meta)
        if not ok:
            print(f"  [ERROR] Failed to activate new DMDV: {err}")
            return False
        print(f"    Activated new DMDV version")

        # Deactivate the old empty CMV
        ok, err = deactivate_cmv(base_url, token, old_cmv_id)
        if ok:
            print(f"    Deactivated old empty CMV {old_cmv_id}")
        else:
            print(f"    [WARN] Could not deactivate old CMV (non-fatal): {err}")

        print(f"  [OK] {dmdv_dev_name} — recovered: {inserted} rows loaded in new version")
        return True
    else:
        inserted, errs = connect_post_rows(base_url, token, matrix_id, cmv_id, rows)
        for e in errs[:3]:
            print(f"    [ROW-ERROR] {e}")
        print(f"    Inserted {inserted}/{len(rows)} rows ({len(errs)} errors)")
        if errs and inserted == 0:
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
        current_metadata = esdv.get("Metadata") or {}

        # SOQL on compound fields can return Metadata=null for Draft ESDVs.
        # Fall back to a direct GET by ID which always returns the full compound.
        if not current_metadata:
            fetched = tooling_get(base_url, token, "ExpressionSetDefinitionVersion", esdv_id)
            current_metadata = fetched.get("Metadata") or {}

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
