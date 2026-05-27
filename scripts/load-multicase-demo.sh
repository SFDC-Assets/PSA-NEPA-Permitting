#!/usr/bin/env bash
# Load all multicase demo data into the target org.
# Each case_*/  subdirectory contains 5 CSVs loaded in dependency order.
#
# Usage:  ./scripts/load-multicase-demo.sh <org-alias>
#
# Prerequisites: metadata already deployed; Carrie Placer Mine load optional.
# Idempotent: all objects use External_ID__c or nepa_*_id__c upsert keys.

set -euo pipefail

TARGET_ORG="${1:?Usage: $0 <org-alias>}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$SCRIPT_DIR/../demo/import_data/multicase"

echo "=== Multicase Demo Load → $TARGET_ORG ==="

for CASE_DIR in "$BASE_DIR"/case_*/; do
  CASE_NAME=$(basename "$CASE_DIR")
  echo ""
  echo "--- Loading $CASE_NAME ---"

  # 1. Accounts (lead agency + sponsor)
  if [[ -f "$CASE_DIR/02_Account.csv" ]]; then
    echo "  Accounts..."
    sf data upsert bulk -s Account \
      -f "$CASE_DIR/02_Account.csv" \
      -i External_ID__c \
      -o "$TARGET_ORG" -w 10 --line-ending CRLF
  fi

  # 2. Program (project container)
  if [[ -f "$CASE_DIR/08_Program.csv" ]]; then
    echo "  Program..."
    sf data upsert bulk -s Program \
      -f "$CASE_DIR/08_Program.csv" \
      -i nepa_project_id__c \
      -o "$TARGET_ORG" -w 10 --line-ending CRLF
  fi

  # 3. IndividualApplication (NEPA process)
  if [[ -f "$CASE_DIR/09_IndividualApplication.csv" ]]; then
    echo "  IndividualApplication..."
    sf data upsert bulk -s IndividualApplication \
      -f "$CASE_DIR/09_IndividualApplication.csv" \
      -i nepa_federal_unique_id__c \
      -o "$TARGET_ORG" -w 10 --line-ending CRLF
  fi

  # 4. ContentVersion — VersionData (Blob) required; cannot load via Bulk API CSV.
  #    Handled by post-load Apex (step below) after all CSV loads complete.

  # 5. ApplicationTimeline (milestones)
  if [[ -f "$CASE_DIR/12_ApplicationTimeline.csv" ]]; then
    echo "  ApplicationTimeline..."
    sf data upsert bulk -s ApplicationTimeline \
      -f "$CASE_DIR/12_ApplicationTimeline.csv" \
      -i External_ID__c \
      -o "$TARGET_ORG" -w 10 --line-ending CRLF
  fi

  echo "  $CASE_NAME: done"
done

echo ""
echo "=== Step: ContentVersion (Apex post-load) ==="
sf apex run \
  --file "$SCRIPT_DIR/../demo/import_data/multicase/10_postload_content_versions.apex" \
  -o "$TARGET_ORG"

echo ""
echo "=== Verifying load ==="
sf data query \
  --query "SELECT Id, nepa_project_id__c, Name FROM Program WHERE nepa_project_id__c LIKE 'SAMPLE%' ORDER BY Name" \
  -o "$TARGET_ORG"

sf data query \
  --query "SELECT Id, nepa_federal_unique_id__c, nepa_review_type__c FROM IndividualApplication WHERE nepa_federal_unique_id__c LIKE 'SAMPLE%' ORDER BY nepa_review_type__c" \
  -o "$TARGET_ORG"

echo ""
echo "Multicase load complete."
