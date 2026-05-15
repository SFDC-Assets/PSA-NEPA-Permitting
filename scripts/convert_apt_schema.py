#!/usr/bin/env python3
"""
Convert nepadata-schema APT files to Salesforce Metadata API schema.

Source schema (nepadata):
  <ActionPlanTemplate>
    <description>...</description>
    <isActive>true</isActive>           -- REMOVE
    <name>...</name>
    <targetObject>...</targetObject>   -- rename to <targetEntityType>
    <uniqueName>...</uniqueName>
    <actionPlanTemplateItems>           -- rename to <actionPlanTemplateItem>
      <assignedToType>User</assignedToType>  -- REMOVE
      <dueDateOffset>N</dueDateOffset>       -- REMOVE (not in target schema)
      <isRequired>true/false</isRequired>
      <name>...</name>
      <priority>...</priority>               -- move to itemValue
      <taskNote>...</taskNote>               -- move to itemValue (Description)
      <type>Task</type>                      -- rename to <itemEntityType>
    </actionPlanTemplateItems>

Target schema (working):
  <ActionPlanTemplate>
    <description>...</description>
    <isAdHocItemCreationEnabled>false</isAdHocItemCreationEnabled>
    <name>...</name>
    <targetEntityType>IndividualApplication</targetEntityType>
    <uniqueName>...</uniqueName>
    <actionPlanTemplateItem>
      <displayOrder>N</displayOrder>
      <isRequired>true/false</isRequired>
      <itemEntityType>Task</itemEntityType>
      <name>...</name>
      <uniqueName>APT_UNIQUE_NAME_Item_N</uniqueName>
      <actionPlanTemplateItemValue>
        <itemEntityType>Task</itemEntityType>
        <name>Subject</name>
        <valueLiteral>task name</valueLiteral>
      </actionPlanTemplateItemValue>
      <actionPlanTemplateItemValue>
        <itemEntityType>Task</itemEntityType>
        <name>Priority</name>
        <valueLiteral>High|Normal|Low</valueLiteral>
      </actionPlanTemplateItemValue>
      <actionPlanTemplateItemValue>
        <itemEntityType>Task</itemEntityType>
        <name>Description</name>
        <valueLiteral>taskNote content</valueLiteral>
      </actionPlanTemplateItemValue>
    </actionPlanTemplateItem>
"""

import os
import sys
import glob
import re
import xml.etree.ElementTree as ET

NS = "http://soap.sforce.com/2006/04/metadata"

def strip_ns(tag):
    return tag.replace(f"{{{NS}}}", "")

def get_text(el, tag):
    child = el.find(f"{{{NS}}}{tag}")
    if child is None:
        child = el.find(tag)
    return child.text.strip() if child is not None and child.text else ""

def convert_file(path):
    tree = ET.parse(path)
    root = tree.getroot()

    desc = get_text(root, "description")
    name = get_text(root, "name")
    unique_name = get_text(root, "uniqueName")
    target = get_text(root, "targetObject") or get_text(root, "targetEntityType") or "IndividualApplication"

    items = root.findall(f"{{{NS}}}actionPlanTemplateItems") or root.findall("actionPlanTemplateItems")

    lines = ['<?xml version="1.0" encoding="UTF-8"?>']
    lines.append(f'<ActionPlanTemplate xmlns="{NS}">')
    # Escape XML special chars in description
    # Description field has a 255-char limit in Salesforce
    desc_truncated = desc[:252] + "..." if len(desc) > 255 else desc
    lines.append(f"    <description>{xml_escape(desc_truncated)}</description>")
    lines.append(f"    <isAdHocItemCreationEnabled>false</isAdHocItemCreationEnabled>")
    lines.append(f"    <name>{xml_escape(name)}</name>")
    lines.append(f"    <targetEntityType>{target}</targetEntityType>")
    lines.append(f"    <uniqueName>{unique_name}</uniqueName>")

    for i, item in enumerate(items, start=1):
        item_name = get_text(item, "name")
        is_required = get_text(item, "isRequired") or "false"
        priority = get_text(item, "priority") or "Normal"
        task_note = get_text(item, "taskNote") or ""
        item_unique = f"{unique_name}_Item_{i}"

        lines.append(f"    <actionPlanTemplateItem>")
        lines.append(f"        <displayOrder>{i}</displayOrder>")
        lines.append(f"        <isRequired>{is_required}</isRequired>")
        lines.append(f"        <itemEntityType>Task</itemEntityType>")
        lines.append(f"        <name>{xml_escape(item_name)}</name>")
        lines.append(f"        <uniqueName>{item_unique}</uniqueName>")
        # Subject value
        lines.append(f"        <actionPlanTemplateItemValue>")
        lines.append(f"            <itemEntityType>Task</itemEntityType>")
        lines.append(f"            <name>Subject</name>")
        lines.append(f"            <valueLiteral>{xml_escape(item_name)}</valueLiteral>")
        lines.append(f"        </actionPlanTemplateItemValue>")
        # Priority value
        lines.append(f"        <actionPlanTemplateItemValue>")
        lines.append(f"            <itemEntityType>Task</itemEntityType>")
        lines.append(f"            <name>Priority</name>")
        lines.append(f"            <valueLiteral>{xml_escape(priority)}</valueLiteral>")
        lines.append(f"        </actionPlanTemplateItemValue>")
        # Description value (taskNote)
        if task_note:
            lines.append(f"        <actionPlanTemplateItemValue>")
            lines.append(f"            <itemEntityType>Task</itemEntityType>")
            lines.append(f"            <name>Description</name>")
            lines.append(f"            <valueLiteral>{xml_escape(task_note)}</valueLiteral>")
            lines.append(f"        </actionPlanTemplateItemValue>")
        lines.append(f"    </actionPlanTemplateItem>")

    lines.append("</ActionPlanTemplate>")
    return "\n".join(lines) + "\n"

def xml_escape(s):
    if not s:
        return s
    s = s.replace("&", "&amp;")
    s = s.replace("<", "&lt;")
    s = s.replace(">", "&gt;")
    s = s.replace('"', "&quot;")
    return s

def main():
    apt_dir = os.path.join(os.path.dirname(__file__), "..", "force-app", "main", "default", "actionPlanTemplates")
    # Only convert the new permit-type files (not the existing WO_* or Process_Milestones files)
    patterns = [
        os.path.join(apt_dir, "NEPA_CE_[A-Z]*.apt-meta.xml"),
        os.path.join(apt_dir, "NEPA_EA_[A-Z]*.apt-meta.xml"),
        os.path.join(apt_dir, "NEPA_EIS_[A-Z]*.apt-meta.xml"),
    ]
    files = []
    for p in patterns:
        files.extend(glob.glob(p))
    # Exclude already-correct Process_Milestones files
    files = [f for f in files if "Process_Milestones" not in f]
    files.sort()

    if not files:
        print("No files found to convert.")
        return

    nepadata_src = "/Users/shannon.schupbach/claude-projects/nepadata/force-app/main/default/actionPlanTemplates"

    for path in files:
        basename = os.path.basename(path)
        # Derive the source filename in nepadata (uses .actionPlanTemplate-meta.xml extension)
        src_name = basename.replace(".apt-meta.xml", ".actionPlanTemplate-meta.xml")
        src_path = os.path.join(nepadata_src, src_name)
        if not os.path.exists(src_path):
            print(f"SKIP (no source): {basename}")
            continue
        try:
            output = convert_file(src_path)
            with open(path, "w", encoding="utf-8") as fh:
                fh.write(output)
            print(f"OK: {basename}")
        except Exception as e:
            print(f"FAIL: {basename} — {e}")

if __name__ == "__main__":
    main()
