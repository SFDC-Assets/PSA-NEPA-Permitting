/**
 * AuraEnabled service for the nepaPermitDependencies LWC.
 * Queries nepa_required_permit__c records for a given IndividualApplication,
 * then makes a live GET callout to each agency's NEPA REST API to retrieve
 * current process status using NEPA_Agency_Endpoint__mdt for endpoint config.
 *
 * Each permit record maps to one HTTP callout keyed by NEPA_Agency_Endpoint__mdt.DeveloperName.
 * If the agency endpoint is unreachable or the CMT record is missing, the
 * result carries calloutSuccess=false and falls back to locally-cached status.
 */
@SuppressWarnings('PMD.TooManyFields')
public with sharing class NepaAgencyPermitService {

    /** DTO returned to the LWC for each dependent permit. */
    public class PermitStatusResult {
        @AuraEnabled public Id      permitId;
        @AuraEnabled public String  permitType;
        @AuraEnabled public String  leadAgency;
        @AuraEnabled public String  regulatoryCitation;
        @AuraEnabled public Boolean isCriticalPath;
        @AuraEnabled public String  agencySystemUrl;
        @AuraEnabled public Date    expectedCompletion;
        @AuraEnabled public Date    actualCompletion;
        // local cached values
        @AuraEnabled public String  localStatus;
        // live values from agency REST API
        @AuraEnabled public String  liveStatus;
        @AuraEnabled public String  liveStage;
        @AuraEnabled public Date    liveExpectedCompletion;
        @AuraEnabled public Datetime liveLastModified;
        @AuraEnabled public Datetime lastSynced;
        // callout diagnostics
        @AuraEnabled public Boolean calloutSuccess;
        @AuraEnabled public String  calloutError;
    }

    /**
     * Returns permit status results for all nepa_required_permit__c records
     * linked to the given IndividualApplication Id. Each result includes both
     * locally-cached status and (when reachable) live status from the agency API.
     *
     * @param processId  Id of the IndividualApplication record
     * @return           List of PermitStatusResult, one per permit record
     */
    @AuraEnabled(cacheable=false)
    public static List<PermitStatusResult> getPermitStatuses(Id processId) {
        if (processId == null) {
            throw new AuraHandledException('processId is required');
        }

        List<nepa_required_permit__c> permits = [
            SELECT Id,
                   nepa_permit_type__c,
                   nepa_lead_agency__c,
                   nepa_regulatory_citation__c,
                   nepa_is_critical_path__c,
                   nepa_agency_system_url__c,
                   nepa_expected_completion__c,
                   nepa_actual_completion__c,
                   nepa_permit_status__c,
                   nepa_external_federal_id__c,
                   nepa_agency_endpoint_ref__c,
                   nepa_last_synced__c
            FROM nepa_required_permit__c
            WHERE nepa_process__c = :processId
            WITH USER_MODE
            ORDER BY nepa_is_critical_path__c DESC, nepa_permit_type__c ASC
        ];

        // CMT records are always readable by all code — CRUD enforcement does not apply.
        // PMD flags this SOQL as a false positive; suppress at the method level instead.
        Map<String, NEPA_Agency_Endpoint__mdt> endpointMap = loadEndpointMap();

        List<PermitStatusResult> results = new List<PermitStatusResult>();
        for (nepa_required_permit__c permit : permits) {
            results.add(buildResult(permit, endpointMap));
        }
        return results;
    }

    @SuppressWarnings('PMD.ApexCRUDViolation')
    private static Map<String, NEPA_Agency_Endpoint__mdt> loadEndpointMap() {
        Map<String, NEPA_Agency_Endpoint__mdt> endpointMap = new Map<String, NEPA_Agency_Endpoint__mdt>();
        for (NEPA_Agency_Endpoint__mdt ep : [
            SELECT DeveloperName, Agency_Key__c, Named_Credential__c, Process_Endpoint_Path__c, Is_Active__c
            FROM NEPA_Agency_Endpoint__mdt
            WHERE Is_Active__c = true
        ]) {
            endpointMap.put(ep.DeveloperName, ep);
        }
        return endpointMap;
    }

    private static PermitStatusResult buildResult(
        nepa_required_permit__c permit,
        Map<String, NEPA_Agency_Endpoint__mdt> endpointMap
    ) {
        PermitStatusResult res = populateLocalFields(permit);

        String endpointKey   = permit.nepa_agency_endpoint_ref__c;
        String externalFedId = permit.nepa_external_federal_id__c;

        if (String.isBlank(endpointKey) || String.isBlank(externalFedId)) {
            res.calloutError = 'No agency endpoint key or external federal ID configured — showing cached status.';
            return res;
        }

        NEPA_Agency_Endpoint__mdt ep = endpointMap.get(endpointKey);
        if (ep == null) {
            res.calloutError = 'No active NEPA_Agency_Endpoint__mdt record found for key: ' + endpointKey;
            return res;
        }

        return performCallout(res, ep, externalFedId);
    }

    private static PermitStatusResult populateLocalFields(nepa_required_permit__c permit) {
        PermitStatusResult res  = new PermitStatusResult();
        res.permitId            = permit.Id;
        res.permitType          = permit.nepa_permit_type__c;
        res.leadAgency          = permit.nepa_lead_agency__c;
        res.regulatoryCitation  = permit.nepa_regulatory_citation__c;
        res.isCriticalPath      = permit.nepa_is_critical_path__c;
        res.agencySystemUrl     = permit.nepa_agency_system_url__c;
        res.expectedCompletion  = permit.nepa_expected_completion__c;
        res.actualCompletion    = permit.nepa_actual_completion__c;
        res.localStatus         = permit.nepa_permit_status__c;
        res.lastSynced          = permit.nepa_last_synced__c;
        res.calloutSuccess      = false;
        return res;
    }

    private static PermitStatusResult performCallout(
        PermitStatusResult res,
        NEPA_Agency_Endpoint__mdt ep,
        String externalFedId
    ) {
        String url = 'callout:' + ep.Named_Credential__c + ep.Process_Endpoint_Path__c + externalFedId;
        try {
            HttpRequest req = new HttpRequest();
            req.setEndpoint(url);
            req.setMethod('GET');
            req.setHeader('Accept', 'application/json');
            req.setTimeout(10000);

            HttpResponse httpRes = new Http().send(req);

            if (httpRes.getStatusCode() == 200) {
                Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(httpRes.getBody());
                if (body.get('success') == true && body.containsKey('data')) {
                    Map<String, Object> data  = (Map<String, Object>) body.get('data');
                    res.liveStatus            = (String) data.get('processStatus');
                    res.liveStage             = (String) data.get('processStage');
                    res.liveLastModified      = parseDateTime((String) data.get('lastModified'));
                    res.liveExpectedCompletion = parseDate((String) data.get('targetCompletionDate'));
                    res.calloutSuccess        = true;
                } else {
                    res.calloutError = 'Agency API returned success=false or missing data node.';
                }
            } else if (httpRes.getStatusCode() == 404) {
                res.calloutError = 'Permit process not found at agency (404). Verify external federal ID.';
            } else {
                res.calloutError = 'Agency API returned HTTP ' + httpRes.getStatusCode();
            }
        } catch (System.CalloutException ex) {
            res.calloutError = 'Callout failed: ' + ex.getMessage();
        } catch (Exception ex) {
            res.calloutError = 'Unexpected error: ' + ex.getMessage();
        }
        return res;
    }

    private static Datetime parseDateTime(String raw) {
        if (String.isBlank(raw)) { return null; }
        try {
            return (Datetime) JSON.deserialize('"' + raw + '"', Datetime.class);
        } catch (Exception e) {
            return null;
        }
    }

    private static Date parseDate(String raw) {
        if (String.isBlank(raw)) { return null; }
        try {
            return Date.valueOf(raw.left(10));
        } catch (Exception e) {
            return null;
        }
    }
}