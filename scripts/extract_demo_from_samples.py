#!/usr/bin/env python3
"""
Extract one NEPA project from a nepadata/samples JSONL file and write
Salesforce-ready CSVs into demo/import_data/multicase/<case_name>/.

Usage:
  python3 scripts/extract_demo_from_samples.py \
      --file /path/to/sample_CE_BLM.jsonl \
      --project-id c7c614db-06e2-8d10-5b70-73b4236514a0 \
      --case-name case_A_ce_blm \
      [--out-dir demo/import_data/multicase] \
      [--preview]

  --preview  Print mapped fields as JSON without writing files.
"""

import argparse
import csv
import json
import os
import re
import sys
from pathlib import Path

# ---------------------------------------------------------------------------
# Picklist normalization maps (sourced from field-meta.xml picklist values)
# ---------------------------------------------------------------------------

SECTOR_MAP = {
    "Agriculture and Natural Resource Management": "Agriculture and Natural Resource Management",
    "Energy Production and Management": "Energy Production and Management",
    "Energy - Oil and Gas": "Energy - Oil and Gas",
    "Energy - Renewable": "Energy - Renewable",
    "Lands and Realty": "Lands and Realty",
    "Materials and Manufacturing": "Materials and Manufacturing",
    "Recreation": "Recreation",
    "Transportation and Infrastructure": "Transportation and Infrastructure",
    "Water and Waste Management": "Water and Waste Management",
    "Water Resources": "Water Resources",
    "Wildlife and Habitat": "Wildlife and Habitat",
    # fallback tokens
    "Environmental Policy": "Lands and Realty",
    "Land Development": "Lands and Realty",
    "Urban Planning": "Lands and Realty",
}

TYPE_MAP = {
    "Rangeland Management": "Rangeland Management / Grazing",
    "Agriculture": "Rangeland Management / Grazing",
    "Grazing": "Rangeland Management / Grazing",
    "Grazing Permit": "Rangeland Management / Grazing",
    "Land Use or Forest Management Plan": "Land Use or Forest Management Plan",
    "Forest Management Plan": "Land Use or Forest Management Plan",
    "Vegetation and Fuels Management": "Vegetation and Fuels Management",
    "Ecosystem Management and Restoration": "Habitat Restoration",
    "Manufacturing": "Manufacturing and Industrial Facilities",
    "Mining - Metals": "Mining - Metals",
    "Mining - Non-Metallic Minerals": "Mining - Non-Metallic",
    "Mining - Non-Metallic": "Mining - Non-Metallic",
    "Conventional Energy Production - Land-based Oil & Gas": "Conventional Energy Production - Land-based Oil & Gas",
    "Conventional Energy Production - Nuclear": "Nuclear Power Generation",
    "Renewable Energy Production - Solar": "Renewable Energy Production - Solar",
    "Renewable Energy Production - Energy Storage": "Renewable Energy Production - Solar",
    "Electricity Transmission": "Electricity Transmission",
    "Pipelines": "Pipelines",
    "Surface Transportation - Other": "Surface Transportation - Highway/Other",
    "Surface Transportation - Railroads": "Railroads and Transit",
    "Water Resources - Other": "Water Quality Monitoring",
    "Water Resources - Irrigation and Water Supply": "Water Quality Monitoring",
    "Waste Management": "Waste Management - Non-Nuclear",
    "Nuclear Technology": "Waste Management - Nuclear/Radiological",
    "Threatened and Endangered Species Management": "Species Survey",
}

REVIEW_TYPE_MAP = {
    "Categorical Exclusion": "CE",
    "Environmental Assessment (EA)": "EA",
    "Environmental Impact Statement (EIS)": "EIS",
}

# Risk/defensibility defaults by review type
RISK_DEFAULTS = {
    "CE":  {"risk_score": "18.50", "defensibility_score": "94", "status": "Completed", "stage": "Decision"},
    "EA":  {"risk_score": "52.30", "defensibility_score": "88", "status": "Completed", "stage": "Decision"},
    "EIS": {"risk_score": "74.80", "defensibility_score": "82", "status": "Completed", "stage": "Decision"},
}

# Synthetic timeline templates per review type
# Each entry: (event_type, description_template, days_offset_from_start)
# nepa_event_type__c restricted picklist values on ApplicationTimeline:
# NOI, Intake Complete, Analysis Complete, Review Complete, Screening Complete,
# CE Determination Complete, Decision Issued, Scoping Open, Scoping Complete,
# Draft EA Published, Draft EIS Published, Comment Period Open, Comment Period Closed,
# Final EIS Published, ROD Issued, EA Initiated, FONSI Issued, CE Determination,
# Permit Issued, Process Paused, Process Cancelled, Other
TIMELINE_TEMPLATES = {
    "CE": [
        ("Intake Complete",          "Initial project application received and intake screening complete.",    0),
        ("Screening Complete",       "Categorical Exclusion screening completed; no extraordinary circumstances identified.", 14),
        ("Analysis Complete",        "Informal agency consultation with resource staff completed.",            30),
        ("CE Determination Complete","Categorical Exclusion determination finalized by Authorized Officer.",  60),
        ("Decision Issued",          "Decision Record issued; project approved under CE.",                    75),
    ],
    "EA": [
        ("Intake Complete",          "Initial project application received and logged.",                       0),
        ("Scoping Open",             "Scoping period opened; public notice issued.",                          21),
        ("Scoping Complete",         "Scoping period closed; issues and alternatives identified.",             51),
        ("EA Initiated",             "Environmental Assessment preparation initiated.",                       90),
        ("Draft EA Published",       "Draft Environmental Assessment published for public review.",           120),
        ("Comment Period Open",      "30-day public comment period opened.",                                  120),
        ("Comment Period Closed",    "Public comment period closed; comments received and logged.",           150),
        ("FONSI Issued",             "Finding of No Significant Impact signed by Authorized Officer.",        210),
        ("Decision Issued",          "Decision Record issued; project approved with mitigation measures.",    225),
    ],
    "EIS": [
        ("NOI",                      "Notice of Intent filed; NEPA scoping initiated.",                        0),
        ("Scoping Open",             "Scoping period opened; public scoping meetings scheduled.",              30),
        ("Scoping Complete",         "Scoping period closed; final scope of issues identified.",               90),
        ("Draft EIS Published",      "Draft Environmental Impact Statement published.",                       365),
        ("Comment Period Open",      "45-day public comment period on Draft EIS opened.",                     365),
        ("Comment Period Closed",    "Public comment period on Draft EIS closed.",                            410),
        ("Final EIS Published",      "Final Environmental Impact Statement published.",                       600),
        ("ROD Issued",               "Record of Decision signed; project approved.",                          660),
        ("Decision Issued",          "Final agency decision recorded; project authorization complete.",        660),
    ],
}


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _get(obj, *keys, default=""):
    """Safely traverse nested dict with .get('value') at each level."""
    cur = obj
    for k in keys:
        if not isinstance(cur, dict):
            return default
        cur = cur.get(k, {})
    if isinstance(cur, dict):
        return cur.get("value", default)
    return cur if cur is not None else default


def normalize_sector(raw_values):
    """Return best-fit picklist value for nepa_project_sector__c."""
    if not raw_values:
        return "Lands and Realty"
    for v in raw_values:
        if v in SECTOR_MAP:
            return SECTOR_MAP[v]
    # token match
    for v in raw_values:
        for token, mapped in SECTOR_MAP.items():
            if token.lower() in v.lower():
                return mapped
    return "Lands and Realty"


def normalize_type(raw_values):
    """Return best-fit picklist value for nepa_project_type__c."""
    if not raw_values:
        return "Land Use or Forest Management Plan"
    for v in raw_values:
        if v in TYPE_MAP:
            return TYPE_MAP[v]
    for v in raw_values:
        for token, mapped in TYPE_MAP.items():
            if token.lower() in v.lower():
                return mapped
    return "Land Use or Forest Management Plan"


def extract_year(docs):
    """Attempt to find the primary year from document text."""
    for d in docs:
        pages = d.get("pages", [])
        if pages:
            text = pages[0].get("page text", "")
            years = re.findall(r"\b(20[01]\d)\b", text)
            if years:
                from collections import Counter
                most_common = Counter(years).most_common(1)[0][0]
                return int(most_common)
    return 2022  # safe fallback


def build_timeline(case_slug, review_type, base_year):
    """Generate ApplicationTimeline rows from template."""
    import datetime
    template = TIMELINE_TEMPLATES.get(review_type, TIMELINE_TEMPLATES["EA"])
    start = datetime.date(base_year, 3, 1)
    rows = []
    for i, (event_type, desc, offset) in enumerate(template, start=1):
        event_date = start + datetime.timedelta(days=offset)
        ext_id = f"SAMPLE_{case_slug.upper()}_AT_{i:02d}"
        rows.append({
            "External_ID__c": ext_id,
            "Name": event_type,
            "nepa_event_type__c": event_type,
            "nepa_event_description__c": desc,
            "nepa_status__c": "Completed",
            "nepa_start_date__c": event_date.isoformat(),
        })
    return rows


# ---------------------------------------------------------------------------
# Main extraction
# ---------------------------------------------------------------------------

def extract(jsonl_path, project_id_prefix, case_name, out_dir, preview_only):
    record = None
    with open(jsonl_path) as f:
        for line in f:
            r = json.loads(line)
            pid = _get(r, "project", "project_ID")
            if pid.startswith(project_id_prefix):
                record = r
                break

    if not record:
        sys.exit(f"ERROR: project_id prefix '{project_id_prefix}' not found in {jsonl_path}")

    proj = record["project"]
    proc = record["process"]
    docs = record.get("documents", [])

    pid        = _get(proj, "project_ID")
    title      = _get(proj, "project_title")
    sectors    = _get(proj, "project_sector") or []
    types      = _get(proj, "project_type") or []
    sponsors   = _get(proj, "project_sponsor") or []
    locations  = _get(proj, "location") or []
    desc_list  = _get(proj, "project_description") or []
    proc_type  = _get(proc, "process_type")  # "Categorical Exclusion" etc.
    agencies   = _get(proc, "lead_agency") or []

    review_type = REVIEW_TYPE_MAP.get(proc_type, "EA")
    defaults    = RISK_DEFAULTS[review_type]
    sector_val  = normalize_sector(sectors)
    type_val    = normalize_type(types)
    location    = locations[0] if locations else ""
    sponsor     = sponsors[0] if sponsors else "Lead Agency"
    agency      = agencies[0] if agencies else "Department of the Interior - Bureau of Land Management"
    description = desc_list[0][:32000] if desc_list else ""

    # Short IDs
    pid_short   = pid.replace("-", "")[:8].upper()
    fed_uid     = f"SAMPLE-{pid_short}"
    project_id  = f"SAMPLE-{pid_short}"
    case_slug   = case_name.replace("case_", "").upper()  # e.g. A_CE_BLM

    base_year   = extract_year(docs)

    # -----------------------------------------------------------------------
    # Build mapped data
    # -----------------------------------------------------------------------

    accounts = [
        {
            "External_ID__c": f"SAMPLE_ACCT_{case_slug}_01",
            "Name": agency.replace("Department of the Interior - ", "")
                         .replace("Department of Agriculture - ", "")
                         .replace("Department of Energy - ", "")
                         .replace("Department of Energy", "DOE")
                         .strip(),
            "Type": "Government",
        }
    ]
    if sponsor and sponsor not in ("None - action is sponsored by the lead agency",) and sponsor != accounts[0]["Name"]:
        accounts.append({
            "External_ID__c": f"SAMPLE_ACCT_{case_slug}_02",
            "Name": sponsor[:80],
            "Type": "Other",
        })

    program = {
        "nepa_project_id__c": project_id,
        "Name": title[:120],
        "nepa_project_description__c": description[:32000],
        "nepa_project_sector__c": sector_val,
        "nepa_project_type__c": type_val,
        "nepa_location_text__c": location[:255],
        "nepa_primary_sector__c": sector_val,
        "Status": "Active",
    }

    # IndividualApplication.nepa_project_sector__c uses a shorter restricted picklist
    IA_SECTOR_MAP = {
        "Agriculture and Natural Resource Management": "Agriculture",
        "Energy Production and Management": "Energy",
        "Energy - Oil and Gas": "Energy",
        "Energy - Renewable": "Energy",
        "Materials and Manufacturing": "Mining",
        "Transportation and Infrastructure": "Transportation",
        "Water and Waste Management": "Water/Coastal",
        "Water Resources": "Water/Coastal",
        "Wildlife and Habitat": "Wildlife",
        "Lands and Realty": "Public Lands",
        "Recreation": "Public Lands",
    }
    # IndividualApplication.nepa_project_type__c restricted picklist
    IA_TYPE_MAP = {
        "Rangeland Management / Grazing": "Agriculture and Public Lands",
        "Forest Management Plan": "Agriculture and Public Lands",
        "Land Use or Forest Management Plan": "Agriculture and Public Lands",
        "Vegetation and Fuels Management": "Agriculture and Public Lands",
        "Habitat Restoration": "Agriculture and Public Lands",
        "Conventional Energy Production - Land-based Oil & Gas": "Energy - Oil, Gas, Land, Coal",
        "Renewable Energy Production - Solar": "Energy - Renewables",
        "Electricity Transmission": "Energy - Hydro and Transmission",
        "Nuclear Power Generation": "Energy - Nuclear and Waste",
        "Waste Management - Nuclear/Radiological": "Energy - Nuclear and Waste",
        "Waste Management - Non-Nuclear": "Materials and Mining",
        "Manufacturing and Industrial Facilities": "Materials and Mining",
        "Mining - Metals": "Materials and Mining",
        "Mining - Non-Metallic": "Materials and Mining",
        "Pipelines": "Energy - Pipeline and LNG",
        "Surface Transportation - Highway/Other": "Transportation - Land",
        "Railroads and Transit": "Transportation - Land",
        "Water Quality Monitoring": "Water Resources",
    }
    ia_sector = IA_SECTOR_MAP.get(sector_val, "Other")
    ia_type   = IA_TYPE_MAP.get(type_val, "Agriculture and Public Lands")

    application = {
        "nepa_federal_unique_id__c": fed_uid,
        "Status": "Approved",
        "Category": "Permit",
        "nepa_review_type__c": review_type,
        "nepa_process_status__c": defaults["status"].lower(),   # restricted: lowercase
        "nepa_process_stage__c": defaults["stage"],
        "nepa_risk_score__c": defaults["risk_score"],
        "nepa_defensibility_score__c": defaults["defensibility_score"],
        "nepa_project_sector__c": ia_sector,
        "nepa_project_type__c": ia_type,
        "nepa_related_project__r.nepa_project_id__c": project_id,
        "nepa_record_owner_agency__c": accounts[0]["Name"][:80],
        "nepa_data_source_agency__c": accounts[0]["Name"][:80],
        "nepa_data_source_system__c": "nepadata/samples",
        "nepa_data_record_version__c": "1",
    }

    # ContentVersion: up to 3 docs
    content_versions = []
    for i, d in enumerate(docs[:3]):
        dm = d.get("metadata", {}).get("document_metadata", {})
        fm = d.get("metadata", {}).get("file_metadata", {})
        doc_id   = _get(dm, "document_ID")
        dtype    = _get(dm, "document_type") or "OTHER"
        dtitle   = _get(dm, "document_title") or ""
        fname    = _get(fm, "file_name") or f"document_{i+1}.pdf"
        sec_title= _get(fm, "section_or_volume_title") or dtitle or fname
        npages   = _get(fm, "total_pages") or 1

        # Derive a clean title
        clean_title = dtitle or re.sub(r"\.pdf$", "", fname, flags=re.IGNORECASE)
        clean_title = re.sub(r"[_/]+", " ", clean_title).strip()[:200] or f"{title[:60]} Document {i+1}"

        content_versions.append({
            "Title": clean_title[:200],
            "nepa_document_summary__c": sec_title[:500],
            "nepa_document_type__c": dtype[:40],
            "nepa_process__r.nepa_federal_unique_id__c": fed_uid,
            "PathOnClient": fname[:255],
        })

    timeline = build_timeline(case_slug, review_type, base_year)

    mapped = {
        "case": case_name,
        "project_ID": pid,
        "review_type": review_type,
        "base_year": base_year,
        "accounts": accounts,
        "program": program,
        "application": application,
        "content_versions": content_versions,
        "timeline_events": len(timeline),
    }

    if preview_only:
        print(json.dumps(mapped, indent=2))
        return

    # -----------------------------------------------------------------------
    # Write CSVs
    # -----------------------------------------------------------------------

    case_dir = Path(out_dir) / case_name
    case_dir.mkdir(parents=True, exist_ok=True)

    def write_csv(filename, rows):
        if not rows:
            return
        # Collapse embedded newlines in all values so every CSV row uses CRLF
        # terminators consistently — required by sf data upsert bulk --line-ending CRLF.
        clean_rows = [
            {k: v.replace("\r\n", " ").replace("\n", " ").replace("\r", " ")
               if isinstance(v, str) else v
             for k, v in row.items()}
            for row in rows
        ]
        fpath = case_dir / filename
        with open(fpath, "w", newline="", encoding="utf-8") as f:
            writer = csv.DictWriter(f, fieldnames=list(clean_rows[0].keys()))
            writer.writeheader()
            writer.writerows(clean_rows)
        print(f"  Wrote {len(rows)} record(s) → {fpath}")

    write_csv("02_Account.csv", accounts)
    write_csv("08_Program.csv", [program])
    write_csv("09_IndividualApplication.csv", [application])
    write_csv("10_ContentVersion.csv", content_versions)
    write_csv("12_ApplicationTimeline.csv", timeline)

    print(f"[OK] {case_name}: {len(docs)} source docs, {len(timeline)} timeline events, base year {base_year}")


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--file",       required=True, help="Path to .jsonl file")
    p.add_argument("--project-id", required=True, help="project_ID value or prefix")
    p.add_argument("--case-name",  required=True, help="Output subdirectory name, e.g. case_A_ce_blm")
    p.add_argument("--out-dir",    default="demo/import_data/multicase", help="Base output directory")
    p.add_argument("--preview",    action="store_true", help="Print mapped fields as JSON; do not write files")
    args = p.parse_args()
    extract(args.file, args.project_id, args.case_name, args.out_dir, args.preview)


if __name__ == "__main__":
    main()
