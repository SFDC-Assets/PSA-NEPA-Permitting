# GIS Proximity Check — Setup and Extension Guide

> **Backlog — OmniStudio Integration Procedure path not verified**
>
> The GIS proximity check architecture described in this guide (Flow → Apex bridge → `NEPA_GISProximityIP` Integration Procedure) is the intended design but the end-to-end path through the OmniStudio Integration Procedure **was not successfully verified**. The GIS layer catalog (`NEPA_GIS_Layer__mdt`), `nepa_gis_data__c` object, and `nepa_detected_protection_layer__c` schema are fully deployed and working. The Integration Procedure activation and end-to-end GIS callout path are backlog. See [ARCHITECTURE_DECISIONS.md — Appendix C](ARCHITECTURE_DECISIONS.md#appendix-c--omnistudio-backlog-detail).
>
> The architectural notes in this guide (particularly the ADR 009 Apex bridge pattern) are accurate design documentation and serve as a resumption guide.

The GIS proximity feature is designed to automatically query federal geospatial services when a project's coordinates are entered. It writes a human-readable protection areas summary, a timestamp, and an extraordinary circumstances flag back to the project record. The entire layer registry lives in custom metadata — adding a new service means adding one record, nothing else.

---

## How It Works

When `nepa_location_lat__c` or `nepa_location_lon__c` changes on a Program record and both fields are populated:

1. `NEPA_GIS_Proximity_Check` (after-save Flow, AsyncAfterCommit) calls `NepaGISProximityIPInvoker` via an Apex `@InvocableMethod` action
2. The Apex bridge calls `NEPA_GISProximityIP` (OmniIntegrationProcedure) via `omnistudio.IntegrationProcedureService.invokeMethod()`
3. The IP reads all active `NEPA_GIS_Layer__mdt` records ordered by Priority
4. For each layer it builds a spatial query URL and fires an HTTP callout
5. Matching features are appended to a running summary, and one `nepa_detected_protection_layer__c` record per layer is accumulated
6. If any match contains a keyword listed in `Extraordinary_Circumstances_Keyword__c`, the extraordinary circumstances flag is set to true
7. `DRUpsertDetectedLayer` upserts the per-layer records to `nepa_detected_protection_layer__c` using `nepa_upsert_key__c` (idempotent — re-runs update existing records)
8. The summary, timestamp, and flag are written back to the Program record via `DRLoadGISResults`
9. The flow stamps `nepa_gis_proximity_complete__c = true`, which triggers `NEPA_Team_Assembly_Orchestrator`

**Why an Apex bridge instead of a Flow subflow:**
OmniIntegrationProcedures are stored as `OmniProcess` sObject records, not Flow records. A Flow `<subflows>` element resolves only actual Flow records by developer name. Attempting to reference an IP name directly in `<subflows>` causes an HTTP-level `UNKNOWN_EXCEPTION` at Flow activation time with no structured error message. The `NepaGISProximityIPInvoker` Apex invocable is the correct bridge pattern for calling any OmniStudio IP from a Flow.

The result looks like this on the record:

```
NWI Wetlands: Freshwater Emergent Wetland (+ 2 more)
FWS Critical Habitat: Designated — Greater Sage-Grouse
EPA Superfund NPL Site: [no features within 1 mile]
EJScreen EJ Index: EJ Index = 63.4
```

---

## Prerequisites

Before deploying, confirm:
- OmniStudio (Industries package) is installed in the target org
- The org has outbound callout capability (not blocked by firewall or Salesforce callout restrictions)
- You have `Customize Application` permission to activate Flows and deploy metadata

---

## Deployment Steps

### 1. Deploy metadata

The standard deploy script (`scripts/deploy.sh`) handles the full GIS chain in dependency order. For a targeted manual deploy:

```bash
# Step 1: Schema — detected layer object + Program GIS fields
sf project deploy start \
  --metadata CustomObject:NEPA_GIS_Layer__mdt \
  --metadata CustomObject:NEPA_Layer_Discipline__mdt \
  --metadata CustomObject:nepa_detected_protection_layer__c \
  --metadata CustomObject:Program \
  --target-org <alias> --wait 30

# Step 2: Remote Site Settings + Named Credentials
sf project deploy start \
  --metadata RemoteSiteSetting:NEPA_GIS_NWI \
  --metadata RemoteSiteSetting:NEPA_GIS_EPA \
  --metadata RemoteSiteSetting:NEPA_GIS_FWS \
  --metadata RemoteSiteSetting:NEPA_GIS_EJScreen \
  --metadata NamedCredential:NEPA_GIS_NWI \
  --metadata NamedCredential:NEPA_GIS_EPA \
  --metadata NamedCredential:NEPA_GIS_FWS \
  --metadata NamedCredential:NEPA_GIS_EJScreen \
  --target-org <alias> --wait 10

# Step 3: CMT seed records
sf project deploy start \
  --metadata CustomMetadata:NEPA_GIS_Layer.NWI_Wetlands \
  --metadata CustomMetadata:NEPA_GIS_Layer.EPA_Superfund_NPL \
  --metadata CustomMetadata:NEPA_GIS_Layer.FWS_Critical_Habitat \
  --metadata CustomMetadata:NEPA_GIS_Layer.EJScreen_EJ_Index \
  --target-org <alias> --wait 10

# Step 4: Apex bridge (must exist before the flow references it)
sf project deploy start \
  --metadata ApexClass:NepaGISProximityIPInvoker \
  --metadata ApexClass:NepaGISProximityIPInvokerTest \
  --target-org <alias> --wait 30

# Step 5a: DRUpsertDetectedLayer — two-step required on net-new orgs
#   (globalKeys embed the org's record ID; see deploy.sh idiosyncrasy note 7)
#   If the DR header already exists in the org, Step 5a is a no-op.
#   Use deploy.sh deploy_omnidatatransform() to handle this automatically.
#
# Step 5b: Other DataRaptors
sf project deploy start \
  --metadata OmniDataTransform:DRExtractGISLayers_1 \
  --metadata OmniDataTransform:DRLoadGISResults_1 \
  --target-org <alias> --wait 10

# Step 6: Integration Procedure
#   uniqueName: NEPA_GISProximityIP_Procedure_1
#   Also requires a two-step on net-new orgs (header first, then with elements)
sf project deploy start \
  --metadata OmniIntegrationProcedure:NEPA_GISProximityIP_Procedure_1 \
  --target-org <alias> --wait 10

# Step 7: Flow (deploy after Apex and IP are in the org)
sf project deploy start \
  --metadata Flow:NEPA_GIS_Proximity_Check \
  --target-org <alias> --wait 30
```

### 2. Verify OmniStudio activation

OmniIntegrationProcedures deployed via Metadata API are created in active state (`isActive=true`). If a component shows inactive in the OmniStudio designer after deploy, open it in **OmniStudio > Integration Procedures**, make no changes, and click **Activate**.

### 3. Verify the Flow is active

`NEPA_GIS_Proximity_Check` deploys as Active (the XML contains `<status>Active</status>`). Confirm in **Setup > Flows** that the flow shows Active status.

### 4. Verify the FWS Named Credential (if needed)

`ecos.fws.gov` uses a federal intermediate CA that Salesforce does not trust by default. If callouts to the FWS Critical Habitat layer fail with an SSL error:

1. Download the DoD Root CA 3 and FWS intermediate certificates from `https://militarycac.com/dodcerts.htm`
2. Go to **Setup > Certificate and Key Management > Upload CA Certificate**
3. Upload both certificates
4. Retry the GIS check — callouts to `ecos.fws.gov` should now succeed

To skip FWS while testing the other layers, set the `FWS_Critical_Habitat` CMT record's `Active__c` to false.

---

## Testing the Integration

### Manual trigger

Open any Program record, set both `nepa_location_lat__c` and `nepa_location_lon__c` to valid decimal degree coordinates, and save. Wait a few seconds (after-save flows are async), then refresh — `nepa_protection_areas__c` and `nepa_gis_last_checked__c` should be populated.

Test coordinates that reliably hit known data:

| Lat | Lon | Expected hits |
|---|---|---|
| 39.7392 | -104.9903 | Denver, CO — likely EJ index present |
| 38.8977 | -77.0366 | DC area — Anacostia River wetlands |
| 40.7128 | -74.0060 | NYC — Superfund sites likely within 1 mile |

### Test via IP directly

Use the OmniStudio IP debug console or invoke via Apex anonymous execution:

```apex
Map<String,Object> input   = new Map<String,Object>{ 'projectId' => '<your Program record Id>' };
Map<String,Object> output  = new Map<String,Object>();
Map<String,Object> options = new Map<String,Object>();
omnistudio.IntegrationProcedureService svc = new omnistudio.IntegrationProcedureService();
Object result = svc.invokeMethod('runIntegrationService', input, output, options);
System.debug('result: ' + result);
System.debug('output: ' + output);
```

The IP key is `NEPA_GISProximityIP` (type `NEPA`, subType `GISProximityIP`). The `invokeMethod` call is the correct API — the static `runIntegrationService()` method and the `IntegrationProcedureRunner` inner class do not exist in this version of the OmniStudio package.

### Verify extraordinary circumstances flag

Set coordinates that fall inside a known wetland polygon (e.g., within the Everglades). After the check runs, `nepa_extraordinary_circumstances__c` should be `true` and the NWI Wetlands line in `nepa_protection_areas__c` should contain a wetland type.

If `nepa_extraordinary_circumstances__c` is true, the CE Screener will not recommend a CE pathway — the project will be escalated to at minimum an EA.

---

## Adding a New ArcGIS FeatureServer Layer

No IP changes, no Flow changes, no code. Three steps:

### Step 1 — Find the endpoint

Go to the ArcGIS REST endpoint for the service you want. The URL pattern for a standard FeatureServer layer is:

```
https://<host>/arcgis/rest/services/<ServiceName>/FeatureServer/<LayerIndex>
```

Browse to that URL in a browser. You should see a JSON or HTML page describing the layer. Note:
- The full base URL up to (not including) the layer index
- The layer index number
- The field name in the response attributes that best identifies a feature (e.g., `NAME`, `SITE_NAME`, `SPECIES_CD`)

To test the spatial query manually, paste this into a browser (replacing lat, lon, and the URL):

```
https://<host>/arcgis/rest/services/<Service>/FeatureServer/<Layer>/query
  ?geometry={"x":-104.99,"y":39.74,"spatialReference":{"wkid":4326}}
  &geometryType=esriGeometryPoint
  &distance=1
  &units=esriSRUnit_Mile
  &spatialRel=esriSpatialRelIntersects
  &outFields=<KEY_FIELD>
  &returnGeometry=false
  &f=json
```

If you get back `{"features":[...]}` with data, the endpoint works.

### Step 2 — Create a Named Credential and Remote Site Setting

**Named Credential** (if the service is a new host not already covered):

Create `force-app/main/default/namedCredentials/NEPA_GIS_<Shortname>.namedCredential-meta.xml`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<NamedCredential xmlns="http://soap.sforce.com/2006/04/metadata">
    <label>NEPA GIS - <Descriptive Name></label>
    <endpoint>https://<host></endpoint>
    <principalType>Anonymous</principalType>
    <protocol>NoAuthentication</protocol>
    <allowMergeFieldsInBody>false</allowMergeFieldsInBody>
    <allowMergeFieldsInHeader>false</allowMergeFieldsInHeader>
    <generateAuthorizationHeader>false</generateAuthorizationHeader>
</NamedCredential>
```

**Remote Site Setting:**

Create `force-app/main/default/remoteSiteSettings/NEPA_GIS_<Shortname>.remoteSite-meta.xml`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<RemoteSiteSetting xmlns="http://soap.sforce.com/2006/04/metadata">
    <description>Brief description of this endpoint and what it provides.</description>
    <disableProtocolSecurity>false</disableProtocolSecurity>
    <isActive>true</isActive>
    <url>https://<host></url>
</RemoteSiteSetting>
```

If the new layer shares a host with an existing Named Credential (e.g., another layer on `geodata.epa.gov`), you don't need a new credential — just reference `NEPA_GIS_EPA` in the CMT record.

### Step 3 — Create the CMT record

Create `force-app/main/default/customMetadata/NEPA_GIS_Layer.<RecordName>.md-meta.xml`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<CustomMetadata xmlns="http://soap.sforce.com/2006/04/metadata"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xmlns:xsd="http://www.w3.org/2001/XMLSchema">
    <label><!-- Human-readable layer name --></label>
    <protected>false</protected>
    <values>
        <field>Service_URL__c</field>
        <value xsi:type="xsd:string">https://<host>/arcgis/rest/services/<Service>/FeatureServer</value>
    </values>
    <values>
        <field>Layer_Number__c</field>
        <value xsi:type="xsd:decimal"><!-- layer index, e.g. 0 --></value>
    </values>
    <values>
        <field>Buffer_Miles__c</field>
        <value xsi:type="xsd:decimal"><!-- e.g. 1.0 --></value>
    </values>
    <values>
        <field>Layer_Label__c</field>
        <value xsi:type="xsd:string"><!-- Written to the protection areas summary line --></value>
    </values>
    <values>
        <field>Result_Key_Field__c</field>
        <value xsi:type="xsd:string"><!-- Field name from attributes, e.g. SITE_NAME --></value>
    </values>
    <values>
        <field>Query_Template__c</field>
        <value xsi:nil="true"/>
    </values>
    <values>
        <field>Named_Credential__c</field>
        <value xsi:type="xsd:string"><!-- API name of Named Credential, e.g. NEPA_GIS_EPA --></value>
    </values>
    <values>
        <field>Extraordinary_Circumstances_Keyword__c</field>
        <!-- Comma-separated keywords that trigger extraordinary circumstances flag.
             Leave nil if proximity alone is not a CE disqualifier for this layer. -->
        <value xsi:nil="true"/>
    </values>
    <values>
        <field>Priority__c</field>
        <value xsi:type="xsd:decimal"><!-- Controls display order; existing layers use 10/20/30/40 --></value>
    </values>
    <values>
        <field>Active__c</field>
        <value xsi:type="xsd:boolean">true</value>
    </values>
</CustomMetadata>
```

Deploy the new files:

```bash
sf project deploy start \
  --metadata RemoteSiteSetting:NEPA_GIS_<Shortname> \
  --metadata NamedCredential:NEPA_GIS_<Shortname> \
  --metadata CustomMetadata:NEPA_GIS_Layer.<RecordName> \
  --target-org <alias> --wait 10
```

The next time a project's coordinates are saved, the new layer will be included automatically.

---

## Adding a Non-ArcGIS REST Endpoint

For services that don't follow the ArcGIS FeatureServer query pattern, set `Layer_Number__c = -1` and populate `Query_Template__c` with the full URL using `{lat}` and `{lon}` as placeholders. The IP detects `Layer_Number__c = -1` and uses the template directly instead of constructing an ArcGIS query URL.

Example — adding USGS StreamStats:

```xml
<values>
    <field>Layer_Number__c</field>
    <value xsi:type="xsd:decimal">-1</value>
</values>
<values>
    <field>Query_Template__c</field>
    <value xsi:type="xsd:string">https://streamstats.usgs.gov/regionservices/api/services/region?rcode=CO&xlocation={lon}&ylocation={lat}&crs=4326&includeparameters=false&includeflowtypes=false&includefeatures=true&returnGeometry=false</value>
</values>
```

The `Result_Key_Field__c` for non-ArcGIS responses should match the top-level key in the JSON that contains the identifying value (e.g., `regionID`). If the response shape is significantly different from ArcGIS, you may need to add a `Set Values` element inside the loop to extract the right field — this is the only case where the IP itself needs modification.

---

## CMT Field Reference

| Field | Type | Required | Description |
|---|---|---|---|
| `Service_URL__c` | Text(512) | Yes | Base FeatureServer URL, e.g. `https://host/arcgis/rest/services/Svc/FeatureServer` |
| `Layer_Number__c` | Number | Yes | Layer index appended before `/query`. Use `-1` for non-ArcGIS endpoints |
| `Buffer_Miles__c` | Number | Yes | Proximity radius in miles |
| `Layer_Label__c` | Text(255) | Yes | Written to the summary line on the Program record |
| `Result_Key_Field__c` | Text(128) | Yes | Attribute field name used to describe a match, e.g. `SITE_NAME` |
| `Query_Template__c` | LongTextArea | No | Full URL with `{lat}` and `{lon}` — used when `Layer_Number__c = -1` |
| `Named_Credential__c` | Text(128) | Yes | API name of the Named Credential for this endpoint's host |
| `Extraordinary_Circumstances_Keyword__c` | Text(255) | No | Comma-separated keywords; match sets `nepa_extraordinary_circumstances__c = true` |
| `Priority__c` | Number | Yes | Controls loop order and summary line ordering; lower = first |
| `Active__c` | Checkbox | Yes | Set false to disable a layer without deleting it |

---

## Seeded Layers

| Label | Host | Layer | Buffer | EC Keywords |
|---|---|---|---|---|
| NWI Wetlands | fwspublicservices.wim.usgs.gov | 0 | 1 mi | WETLANDS, FLOODPLAIN, RIPARIAN |
| EPA Superfund NPL Site | geodata.epa.gov | 22 | 1 mi | NPL, SUPERFUND, CERCLA |
| FWS Critical Habitat | ecos.fws.gov | 0 | 1 mi | CRITICAL HABITAT, DESIGNATED, PROPOSED |
| EJScreen EJ Index | ejscreen.epa.gov | -1 (template) | 1 mi | — (informational only) |
