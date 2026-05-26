# NEPA Data Standard v1.2.0 - API Query Examples

This document provides practical curl and PostgREST query examples for the NEPA Data Standard API.

---

## Setup

**Base URL:** `https://permitting.innovation.gov/` (replace with actual deployment host)  
**Spec Location:** https://permitting.innovation.gov/swagger.json

---

## Project Queries

### Get all projects
```bash
curl -X GET "https://permitting.innovation.gov/project" \
  -H "Accept: application/json"
```

### Get projects with specific status
```bash
curl -X GET "https://permitting.innovation.gov/project?current_status=eq.underway" \
  -H "Accept: application/json"
```

### Get projects by agency
```bash
curl -X GET "https://permitting.innovation.gov/project?lead_agency=ilike.*EPA*" \
  -H "Accept: application/json"
```

### Get projects by geographic area (bounding box)
```bash
curl -X GET "https://permitting.innovation.gov/project?location_lat=gte.40&location_lat=lte.42&location_lon=gte.-75&location_lon=lte.-73" \
  -H "Accept: application/json"
```

### Get projects paginated (limit 10, skip 20)
```bash
curl -X GET "https://permitting.innovation.gov/project?limit=10&offset=20" \
  -H "Accept: application/json"
```

### Get specific columns only
```bash
curl -X GET "https://permitting.innovation.gov/project?select=id,title,lead_agency,current_status" \
  -H "Accept: application/json"
```

### Get projects sorted by creation date (newest first)
```bash
curl -X GET "https://permitting.innovation.gov/project?order=created_at.desc" \
  -H "Accept: application/json"
```

---

## Process Instance Queries

### Get all processes for a project
```bash
curl -X GET "https://permitting.innovation.gov/process_instance?parent_project_id=eq.123" \
  -H "Accept: application/json"
```

### Get active processes
```bash
curl -X GET "https://permitting.innovation.gov/process_instance?current_status=eq.underway" \
  -H "Accept: application/json"
```

### Get process with related documents
```bash
curl -X GET "https://permitting.innovation.gov/process_instance?id=eq.456&select=*,documents(*)" \
  -H "Accept: application/json"
```

---

## Document Queries

### Get all documents
```bash
curl -X GET "https://permitting.innovation.gov/document" \
  -H "Accept: application/json"
```

### Get documents for a specific process
```bash
curl -X GET "https://permitting.innovation.gov/document?parent_process_id=eq.456" \
  -H "Accept: application/json"
```

### Get NEPA-specific documents (EIS, EA, FONSI)
```bash
curl -X GET "https://permitting.innovation.gov/document?type=in.(EIS,EA,FONSI,ROD)" \
  -H "Accept: application/json"
```

### Get documents with full table of contents
```bash
curl -X GET "https://permitting.innovation.gov/document?id=eq.789&select=id,title,document_structure" \
  -H "Accept: application/json"
```

### Get recent documents
```bash
curl -X GET "https://permitting.innovation.gov/document?created_at=gte.2024-01-01&order=created_at.desc" \
  -H "Accept: application/json"
```

---

## Comment Queries

### Get all comments
```bash
curl -X GET "https://permitting.innovation.gov/comment" \
  -H "Accept: application/json"
```

### Get comments on a document
```bash
curl -X GET "https://permitting.innovation.gov/comment?parent_document_id=eq.789" \
  -H "Accept: application/json"
```

### Get public comments only
```bash
curl -X GET "https://permitting.innovation.gov/comment?public_source=is.true&public_access=is.true" \
  -H "Accept: application/json"
```

### Get comments submitted within a date range
```bash
curl -X GET "https://permitting.innovation.gov/comment?date_submitted=gte.2024-06-01&date_submitted=lt.2024-06-30" \
  -H "Accept: application/json"
```

### Get comments with responses
```bash
curl -X GET "https://permitting.innovation.gov/comment?response_text=not.is.null" \
  -H "Accept: application/json"
```

---

## Engagement Queries

### Get all public engagement events
```bash
curl -X GET "https://permitting.innovation.gov/engagement" \
  -H "Accept: application/json"
```

### Get engagement events for a process
```bash
curl -X GET "https://permitting.innovation.gov/engagement?parent_process_id=eq.456" \
  -H "Accept: application/json"
```

### Get public meetings
```bash
curl -X GET "https://permitting.innovation.gov/engagement?type=ilike.*public*meeting*" \
  -H "Accept: application/json"
```

### Get upcoming engagement events
```bash
curl -X GET "https://permitting.innovation.gov/engagement?start_datetime=gte.now()&order=start_datetime.asc" \
  -H "Accept: application/json"
```

---

## Case Event (Milestone) Queries

### Get all case events
```bash
curl -X GET "https://permitting.innovation.gov/case_event" \
  -H "Accept: application/json"
```

### Get case events for a process
```bash
curl -X GET "https://permitting.innovation.gov/case_event?parent_process_id=eq.456" \
  -H "Accept: application/json"
```

### Get overdue milestones
```bash
curl -X GET "https://permitting.innovation.gov/case_event?due_date=lt.now()&completion_date=is.null" \
  -H "Accept: application/json"
```

### Get events by status
```bash
curl -X GET "https://permitting.innovation.gov/case_event?status=eq.completed" \
  -H "Accept: application/json"
```

---

## GIS Data Queries

### Get all GIS data
```bash
curl -X GET "https://permitting.innovation.gov/gis_data" \
  -H "Accept: application/json"
```

### Get GIS data for a document
```bash
curl -X GET "https://permitting.innovation.gov/gis_data?parent_document_id=eq.789" \
  -H "Accept: application/json"
```

### Get GIS data for a process
```bash
curl -X GET "https://permitting.innovation.gov/gis_data?parent_process_id=eq.456" \
  -H "Accept: application/json"
```

### Get GIS elements with bounding box
```bash
curl -X GET "https://permitting.innovation.gov/gis_data_element?top_left_lat=gte.40&bot_right_lat=lte.42" \
  -H "Accept: application/json"
```

### Get GIS layers by format
```bash
curl -X GET "https://permitting.innovation.gov/gis_data_element?format=eq.GeoJSON" \
  -H "Accept: application/json"
```

---

## Process Model & Decision Queries

### Get all process models
```bash
curl -X GET "https://permitting.innovation.gov/process_model" \
  -H "Accept: application/json"
```

### Get decision elements for a model
```bash
curl -X GET "https://permitting.innovation.gov/decision_element?parent_process_model_id=eq.101" \
  -H "Accept: application/json"
```

### Get decision outcomes
```bash
curl -X GET "https://permitting.innovation.gov/process_decision_payload?process_instance_id=eq.456" \
  -H "Accept: application/json"
```

---

## Legal Structure Queries

### Get all regulations
```bash
curl -X GET "https://permitting.innovation.gov/legal_structure" \
  -H "Accept: application/json"
```

### Get regulations by issuing authority
```bash
curl -X GET "https://permitting.innovation.gov/legal_structure?issuing_authority=ilike.*EPA*" \
  -H "Accept: application/json"
```

### Get active regulations
```bash
curl -X GET "https://permitting.innovation.gov/legal_structure?effective_date=lte.now()" \
  -H "Accept: application/json"
```

---

## Export Queries

### Export all data as JSONB
```bash
curl -X POST "https://permitting.innovation.gov/rpc/export_all_tables_as_jsonb" \
  -H "Content-Type: application/json" \
  -d '{}'
```

### Download as CSV
```bash
curl -X GET "https://permitting.innovation.gov/project" \
  -H "Accept: text/csv" \
  > projects.csv
```

---

## Advanced Query Operators

PostgREST supports the following operators in query parameters:

| Operator | Example | Meaning |
|----------|---------|---------|
| `eq` | `status=eq.active` | Equal to |
| `neq` | `status=neq.inactive` | Not equal to |
| `gt` | `date=gt.2024-01-01` | Greater than |
| `gte` | `date=gte.2024-01-01` | Greater than or equal |
| `lt` | `date=lt.2024-12-31` | Less than |
| `lte` | `date=lte.2024-12-31` | Less than or equal |
| `like` | `title=like.*wind*` | SQL LIKE pattern |
| `ilike` | `title=ilike.*WIND*` | Case-insensitive LIKE |
| `in` | `status=in.(active,pending)` | In list |
| `is` | `field=is.null` | IS NULL / IS NOT NULL |

---

## Complex Queries

### Get projects with process details
```bash
curl -X GET "https://permitting.innovation.gov/project?select=id,title,*,process_instance(*)" \
  -H "Accept: application/json"
```

### Get process with all related data
```bash
curl -X GET "https://permitting.innovation.gov/process_instance?id=eq.456&select=*,project(*),document(*),case_event(*)" \
  -H "Accept: application/json"
```

### Get document with comments and engagement
```bash
curl -X GET "https://permitting.innovation.gov/document?id=eq.789&select=*,comment(*),engagement(*)" \
  -H "Accept: application/json"
```

---

## Response Formats

### JSON (default)
```bash
curl -X GET "https://permitting.innovation.gov/project?limit=1" \
  -H "Accept: application/json"
```

### Compact JSON (nulls stripped)
```bash
curl -X GET "https://permitting.innovation.gov/project?limit=1" \
  -H "Accept: application/vnd.pgrst.object+json;nulls=stripped"
```

### CSV
```bash
curl -X GET "https://permitting.innovation.gov/project?limit=10" \
  -H "Accept: text/csv"
```

---

## Pagination Best Practices

### Get total count
```bash
curl -I -X GET "https://permitting.innovation.gov/project" \
  -H "Accept: application/json" \
  -H "Prefer: count=exact"
```
Returns `Content-Range: 0-10/1000` (total 1000 records)

### Fetch page 2 (10 records per page)
```bash
curl -X GET "https://permitting.innovation.gov/project?limit=10&offset=10" \
  -H "Accept: application/json"
```

### Range header
```bash
curl -X GET "https://permitting.innovation.gov/project?order=id.asc" \
  -H "Range: 20-29"
```

---

## Error Handling

### Handle 404 (not found)
```bash
curl -X GET "https://permitting.innovation.gov/project?id=eq.999999" \
  -H "Accept: application/json"
# Returns 200 with empty array []
```

### Check for validation errors
```bash
curl -w "\n%{http_code}\n" -X GET "https://permitting.innovation.gov/project?invalid_filter=xyz" \
  -H "Accept: application/json"
# Returns 400 with error details
```

---

## PSA-NEPA Integration Examples

### Query Salesforce-equivalent data

Get all NEPA processes (Process__c equivalent):
```bash
curl -X GET "https://permitting.innovation.gov/process_instance?order=created_at.desc" \
  -H "Accept: application/json" \
  -H "Prefer: limit=100"
```

Get comments for analysis (PublicComplaint__c equivalent):
```bash
curl -X GET "https://permitting.innovation.gov/comment?public_access=is.true&order=date_submitted.desc" \
  -H "Accept: application/json"
```

Get case milestones (ApplicationTimeline__c equivalent):
```bash
curl -X GET "https://permitting.innovation.gov/case_event?order=due_date.asc" \
  -H "Accept: application/json"
```

---

## Performance Tips

1. **Use `select` to limit columns** — reduces payload size
2. **Add `limit` to all queries** — avoid fetching entire tables
3. **Use `offset` for pagination** — not cursor-based
4. **Index frequently-queried fields** — `parent_project_id`, `current_status`, `date_submitted`
5. **Cache responses** when data doesn't change frequently
6. **Use CSV export** for bulk data loads into data warehouses

---

## Further Reading

- **PostgREST API Reference:** https://postgrest.org/en/v12/references/api.html
- **NEPA Data Standard GitHub:** https://github.com/OMB-Circulars/NEPA-Data-Standard
- **Permitting Innovators Portal:** https://permitting.innovation.gov

