#!/usr/bin/env python3
"""
Generate NEPA_CE_Code__mdt custom metadata records from the CEQ CE Explorer
filtered dataset (exclusions_filtered.json).

Each record in the filtered JSON corresponds to one CATEX. The developer name
is derived from the structuredID after sanitizing non-alphanumeric characters.
Existing NEPA_CE_Code CMT records (NEPATEC-derived) are NOT touched — this
script only creates new records for CE Explorer-sourced codes.
"""

import json
import os
import re
import xml.etree.ElementTree as ET
from pathlib import Path

SOURCE = Path(__file__).parent.parent / "exclusions_filtered.json"
DEST = Path(__file__).parent.parent / "force-app/main/default/customMetadata"

AGENCY_MAP = {
    "DOD - USACE": "USACE",
    "DOE":         "DOE",
    "DOI - BLM":   "BLM",
    "DOI - USFWS": "USFWS",
    "DOT - FHWA":  "FHWA",
    "FERC":        "FERC",
}

XML_NS = "http://soap.sforce.com/2006/04/metadata"
XSI_NS = "http://www.w3.org/2001/XMLSchema-instance"
XSD_NS = "http://www.w3.org/2001/XMLSchema"

def sanitize_devname(structured_id: str) -> str:
    """Convert structuredID like 'USACE---1-1' → 'CE_Exp_USACE_1_1'."""
    cleaned = re.sub(r"[^A-Za-z0-9]+", "_", structured_id).strip("_")
    return f"CE_Exp_{cleaned}"

def escape_xml(text: str) -> str:
    return (text
            .replace("&", "&amp;")
            .replace("<", "&lt;")
            .replace(">", "&gt;")
            .replace('"', "&quot;"))

def make_value(field: str, type_ns: str, content: str) -> str:
    return (
        f"    <values>\n"
        f"        <field>{field}</field>\n"
        f"        <value xsi:type=\"{type_ns}\">{escape_xml(content)}</value>\n"
        f"    </values>\n"
    )

def make_bool_value(field: str, val: bool) -> str:
    return (
        f"    <values>\n"
        f"        <field>{field}</field>\n"
        f"        <value xsi:type=\"xsd:boolean\">{str(val).lower()}</value>\n"
        f"    </values>\n"
    )

def make_record(rec: dict, agency_abbr: str) -> tuple[str, str]:
    """Return (developer_name, xml_content)."""
    dev_name = sanitize_devname(rec["structuredID"])

    # Derive a short plain-language label: first 80 chars of exclusion text
    short_desc = rec["exclusion"][:77].rstrip() + ("..." if len(rec["exclusion"]) > 77 else "")
    label = f"{agency_abbr} {rec['structuredID']}"[:40]

    circ = rec["circumstances"] if rec["circumstances"] != "Not Catalogued" else ""

    xml = (
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        f'<CustomMetadata xmlns="{XML_NS}"'
        f' xmlns:xsi="{XSI_NS}"'
        f' xmlns:xsd="{XSD_NS}">\n'
        f"    <label>{escape_xml(label)}</label>\n"
        f"    <protected>false</protected>\n"
        + make_value("Code__c", "xsd:string", rec["structuredID"])
        + make_value("Authority_CFR__c", "xsd:string", rec["origin"][:255])
        + make_value("Plain_Language_Description__c", "xsd:string", short_desc[:255])
        + make_value("Agency__c", "xsd:string", agency_abbr[:10])
        + make_bool_value("Indoor_Only__c", False)
        + '    <values>\n        <field>Acreage_Threshold__c</field>\n        <value xsi:type="xsd:decimal">0</value>\n    </values>\n'
        + make_bool_value("Requires_GIS_Review__c", False)
        + make_bool_value("Is_Multi_Code__c", False)
        + '    <values>\n        <field>Record_Count_NEPATEC__c</field>\n        <value xsi:type="xsd:decimal">0</value>\n    </values>\n'
        + make_bool_value("Active__c", True)
        + make_value("CE_Explorer_ID__c", "xsd:string", rec["structuredID"][:80])
        + make_value("Exclusion_Text__c", "xsd:string", rec["exclusion"])
        + make_value("Extraordinary_Circumstances__c", "xsd:string", circ)
        + make_value("Source_URL__c", "xsd:string", rec["originUrl"][:255])
        + make_value("Long_Unit__c", "xsd:string", rec["longUnit"][:150])
        + make_value("Context__c", "xsd:string", rec["context"][:255])
        + "</CustomMetadata>\n"
    )
    return dev_name, xml


def main():
    data = json.loads(SOURCE.read_text())
    DEST.mkdir(parents=True, exist_ok=True)

    created = 0
    skipped = 0
    package_members = []

    for unit_key, records in data.items():
        agency_abbr = AGENCY_MAP.get(unit_key, unit_key.split(" - ")[-1][:10])
        for rec in records:
            dev_name, xml_content = make_record(rec, agency_abbr)
            filename = DEST / f"NEPA_CE_Code.{dev_name}.md-meta.xml"
            if filename.exists():
                skipped += 1
                continue
            filename.write_text(xml_content, encoding="utf-8")
            package_members.append(f"NEPA_CE_Code.{dev_name}")
            created += 1

    print(f"Created: {created}  Skipped (already existed): {skipped}")
    print("\nPackage.xml <members> entries to add:")
    for m in sorted(package_members):
        print(f"        <members>{m}</members>")


if __name__ == "__main__":
    main()
