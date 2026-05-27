/**
 * Invocable GIS proximity service — replaces the OmniStudio NEPA_GISProximityIP.
 *
 * For each active NEPA_GIS_Layer__mdt record, builds an ArcGIS /query URL, fires
 * an HTTP callout via the layer's Named Credential, parses the features[] response,
 * writes one nepa_gis_data__c child record per hit, and stamps nepa_protection_areas__c,
 * nepa_gis_last_checked__c, and nepa_extraordinary_circumstances__c on the Program.
 *
 * Callout model: the @InvocableMethod enqueues a Queueable so callouts run after the
 * after-save flow's transaction commits. The existing NEPA_GIS_Proximity_Check flow
 * continues to work unchanged — only the action class reference changes.
 */
public with sharing class NepaGISProximityService {

    // ── Invocable contract ────────────────────────────────────────────────────

    public class Request {
        @InvocableVariable(label='Project Id' required=true)
        public String projectId;
    }

    public class Result {
        @InvocableVariable(label='Success')
        public Boolean success;
        @InvocableVariable(label='Error Message')
        public String errorMessage;
    }

    @InvocableMethod(
        label='Run GIS Proximity Check'
        description='Queries federal ArcGIS endpoints for each active NEPA_GIS_Layer__mdt and writes results to nepa_gis_data__c.'
        callout=true
    )
    public static List<Result> invoke(List<Request> requests) {
        List<Result> results = new List<Result>();
        for (Request req : requests) {
            Result res = new Result();
            try {
                if (String.isBlank(req.projectId)) {
                    res.success      = false;
                    res.errorMessage = 'projectId is required';
                } else {
                    System.enqueueJob(new GISProximityQueueable(req.projectId));
                    res.success      = true;
                    res.errorMessage = null;
                }
            } catch (Exception ex) {
                res.success      = false;
                res.errorMessage = ex.getMessage();
            }
            results.add(res);
        }
        return results;
    }

    // ── Queueable — callouts run after the triggering transaction commits ─────

    public class GISProximityQueueable implements Queueable, Database.AllowsCallouts {

        private final String projectId;

        public GISProximityQueueable(String projectId) {
            this.projectId = projectId;
        }

        public void execute(QueueableContext ctx) {
            List<Program> projects = [
                SELECT Id, nepa_location_lat__c, nepa_location_lon__c
                FROM   Program
                WHERE  Id = :projectId
                WITH   USER_MODE
                LIMIT  1
            ];
            if (projects.isEmpty()) { return; }
            Program proj = projects[0];
            if (proj.nepa_location_lat__c == null || proj.nepa_location_lon__c == null) { return; }

            List<NEPA_GIS_Layer__mdt> layers = [
                SELECT DeveloperName, Label, Service_URL__c, Layer_Number__c,
                       Buffer_Miles__c, Layer_Label__c, Result_Key_Field__c,
                       Query_Template__c, Named_Credential__c,
                       Extraordinary_Circumstances_Keyword__c, Priority__c
                FROM   NEPA_GIS_Layer__mdt
                WHERE  Active__c = true
                ORDER  BY Priority__c ASC NULLS LAST
            ];

            Decimal lat = proj.nepa_location_lat__c;
            Decimal lon = proj.nepa_location_lon__c;

            List<nepa_gis_data__c> gisRecords   = new List<nepa_gis_data__c>();
            List<String>            summaryLines = new List<String>();
            Boolean                 ecTriggered  = false;

            for (NEPA_GIS_Layer__mdt layer : layers) {
                String endpoint = buildCalloutEndpoint(layer, lat, lon);
                if (String.isBlank(endpoint)) { continue; }

                HttpResponse resp = fireCallout(endpoint);
                if (resp == null || resp.getStatusCode() != 200) { continue; }

                List<Map<String, Object>> features = parseFeatures(resp.getBody());
                if (features.isEmpty()) { continue; }

                String summary = extractSummary(features, layer.Result_Key_Field__c);
                summaryLines.add(layer.Layer_Label__c + ': ' + summary);
                gisRecords.add(buildGisRecord(proj.Id, layer, lat, lon, summary, features.size()));

                if (!ecTriggered && hasEcKeyword(summary, layer.Extraordinary_Circumstances_Keyword__c)) {
                    ecTriggered = true;
                }
            }

            if (!gisRecords.isEmpty()) {
                insert as user gisRecords;
            }

            Program progUpdate = new Program(
                Id                                  = proj.Id,
                nepa_protection_areas__c            = summaryLines.isEmpty() ? null : String.join(summaryLines, '\n'),
                nepa_extraordinary_circumstances__c = ecTriggered,
                nepa_gis_last_checked__c            = Datetime.now(),
                nepa_gis_proximity_complete__c      = true
            );
            update as user progUpdate;
        }
    }

    // ── URL / callout endpoint builder ────────────────────────────────────────

    /**
     * Returns a `callout:NC_NAME/path` endpoint string for use with Http.send().
     * Named Credentials store the base domain (e.g. https://services.arcgis.com);
     * we derive the path portion by stripping that base from the full Service_URL__c.
     */
    @TestVisible
    static String buildCalloutEndpoint(NEPA_GIS_Layer__mdt layer, Decimal lat, Decimal lon) {
        String fullUrl = buildFullUrl(layer, lat, lon);
        if (String.isBlank(fullUrl) || String.isBlank(layer.Named_Credential__c)) { return null; }
        String base = extractBase(fullUrl);
        String path = fullUrl.removeStart(base);
        return 'callout:' + layer.Named_Credential__c + path;
    }

    @TestVisible
    static String buildFullUrl(NEPA_GIS_Layer__mdt layer, Decimal lat, Decimal lon) {
        String latStr = String.valueOf(lat);
        String lonStr = String.valueOf(lon);

        if (String.isNotBlank(layer.Query_Template__c)) {
            return layer.Query_Template__c
                .replace('{lat}', latStr)
                .replace('{lon}', lonStr);
        }

        if (String.isBlank(layer.Service_URL__c)) { return null; }

        Decimal bufferMiles    = layer.Buffer_Miles__c != null ? layer.Buffer_Miles__c : 1.0;
        Decimal distanceMetres = bufferMiles * 1609.344;
        Integer layerNum       = layer.Layer_Number__c != null ? (Integer) layer.Layer_Number__c : 0;
        String  base           = layer.Service_URL__c.removeEnd('/');

        return base + '/' + layerNum + '/query'
            + '?geometry='         + EncodingUtil.urlEncode(lonStr + ',' + latStr, 'UTF-8')
            + '&geometryType=esriGeometryPoint'
            + '&inSR=4326'
            + '&spatialRel=esriSpatialRelIntersects'
            + '&distance='         + String.valueOf(distanceMetres.setScale(0))
            + '&units=esriSRUnit_Meter'
            + '&outFields=*'
            + '&returnGeometry=false'
            + '&f=json';
    }

    // Extracts https://host from a full URL by splitting on the third slash.
    @TestVisible
    static String extractBase(String url) {
        if (String.isBlank(url)) { return ''; }
        List<String> parts = url.split('/');
        // parts[0]='https:', parts[1]='', parts[2]='host'
        if (parts.size() < 3) { return url; }
        return parts[0] + '//' + parts[2];
    }

    // ── HTTP callout ──────────────────────────────────────────────────────────

    @TestVisible
    static HttpResponse fireCallout(String endpoint) {
        try {
            HttpRequest req = new HttpRequest();
            req.setMethod('GET');
            req.setTimeout(10000);
            req.setEndpoint(endpoint);
            return new Http().send(req);
        } catch (Exception ex) {
            return null;
        }
    }

    // ── Feature parsing ───────────────────────────────────────────────────────

    @TestVisible
    static List<Map<String, Object>> parseFeatures(String body) {
        try {
            Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(body);
            List<Object> raw = (List<Object>) parsed.get('features');
            if (raw == null) { return new List<Map<String, Object>>(); }
            List<Map<String, Object>> out = new List<Map<String, Object>>();
            for (Object o : raw) {
                out.add((Map<String, Object>) o);
            }
            return out;
        } catch (Exception ex) {
            return new List<Map<String, Object>>();
        }
    }

    @TestVisible
    static String extractSummary(List<Map<String, Object>> features, String keyField) {
        Set<String> values = new Set<String>();
        for (Map<String, Object> feat : features) {
            Map<String, Object> attrs = (Map<String, Object>) feat.get('attributes');
            if (attrs == null) { continue; }
            Object val = String.isNotBlank(keyField) ? attrs.get(keyField) : null;
            if (val != null) { values.add(String.valueOf(val)); }
        }
        return values.isEmpty()
            ? String.valueOf(features.size()) + ' feature(s)'
            : String.join(new List<String>(values), '; ');
    }

    @TestVisible
    static Boolean hasEcKeyword(String summary, String keywords) {
        if (String.isBlank(keywords) || String.isBlank(summary)) { return false; }
        String upper = summary.toUpperCase();
        for (String kw : keywords.split(',')) {
            if (String.isNotBlank(kw) && upper.contains(kw.trim().toUpperCase())) {
                return true;
            }
        }
        return false;
    }

    // ── Record builder ────────────────────────────────────────────────────────

    private static nepa_gis_data__c buildGisRecord(
        Id projectId, NEPA_GIS_Layer__mdt layer,
        Decimal lat, Decimal lon,
        String summary, Integer featureCount
    ) {
        nepa_gis_data__c rec           = new nepa_gis_data__c();
        rec.Name                       = layer.Layer_Label__c + ' — ' + System.now().format('yyyy-MM-dd');
        rec.nepa_parent_project__c     = projectId;
        rec.nepa_centroid_lat__c       = lat;
        rec.nepa_centroid_lon__c       = lon;
        rec.nepa_description__c        = layer.Layer_Label__c + ': ' + featureCount
            + ' feature(s) within ' + layer.Buffer_Miles__c + ' mile(s). ' + summary;
        rec.nepa_notes__c              = 'Layer: ' + layer.DeveloperName;
        rec.nepa_data_source_system__c = 'NepaGISProximityService';
        return rec;
    }
}