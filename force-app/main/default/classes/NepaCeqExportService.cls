/**
 * REST endpoint exposing NEPA permit process data to CEQ for MFR compliance reporting.
 * URL: /services/apexrest/nepa/v1/processes/
 *
 * GET /nepa/v1/processes/{id}   — single process by Salesforce ID or nepa_federal_unique_id__c
 * GET /nepa/v1/processes/       — list with optional query params:
 *     reviewType   (EIS | EA | CE | Other Authorization)
 *     status       (planned | pre-application | in progress | paused | completed | cancelled)
 *     agencyId     (nepa_agency_id__c text value)
 *     updatedSince (ISO-8601 date, filters on LastModifiedDate)
 *     pageSize     (default 50, max 200)
 *     page         (1-based, default 1)
 *
 * Response shape: { "success": true, "data": {...} | [...], "totalCount": n, "page": n, "pageSize": n }
 * Error shape:    { "success": false, "errorCode": "...", "message": "..." }
 *
 * Auth: callers must have API access + NEPA_Permitting permission set (or System Administrator).
 * CEQ determines their own OAuth/auth pattern — this class imposes no auth beyond Salesforce's
 * standard profile/permission-set access control.
 */
@RestResource(urlMapping='/nepa/v1/processes/*')
global with sharing class NepaCeqExportService {

    private static final Integer DEFAULT_PAGE_SIZE = 50;
    private static final Integer MAX_PAGE_SIZE = 200;

    // ── GET dispatcher ────────────────────────────────────────────────────────

    /**
     * Handles all GET requests to /nepa/v1/processes/*.
     * Routes to single-record or list handler based on the path suffix.
     */
    @SuppressWarnings('PMD.AvoidDebugStatements')
    @HttpGet
    global static void doGet() {
        RestRequest  req  = RestContext.request;
        RestResponse res  = RestContext.response;
        res.addHeader('Content-Type', 'application/json');

        try {
            String pathSuffix = req.requestURI.substringAfter('/nepa/v1/processes/').trim();

            if (String.isNotBlank(pathSuffix)) {
                handleSingleRecord(pathSuffix, res);
            } else {
                handleList(req, res);
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'NepaCeqExportService error: ' + e.getMessage() + ' | ' + e.getStackTraceString());
            res.statusCode = 500;
            res.responseBody = Blob.valueOf(
                JSON.serialize(errorResponse('SERVER_ERROR', 'An internal error occurred. Contact your administrator.'))
            );
        }
    }

    // ── Single record ─────────────────────────────────────────────────────────

    private static void handleSingleRecord(String idOrFuid, RestResponse res) {
        // sfge-disable-next-line MissingNullCheckOnSoqlVariable -- caller (doGet) guards isNotBlank before invoking
        List<IndividualApplication> records = [
            SELECT Id, Name,
                   nepa_federal_unique_id__c,
                   nepa_review_type__c,
                   nepa_process_status__c,
                   nepa_process_stage__c,
                   nepa_agency_id__c,
                   nepa_start_date__c,
                   nepa_target_completion_date__c,
                   nepa_sla_due_date__c,
                   nepa_sla_overdue__c,
                   nepa_risk_score__c,
                   nepa_risk_tier__c,
                   nepa_record_completeness__c,
                   nepa_last_stage_transition__c,
                   LastModifiedDate
            FROM IndividualApplication
            WHERE Id = :idOrFuid
               OR nepa_federal_unique_id__c = :idOrFuid
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];

        if (records.isEmpty()) {
            res.statusCode = 404;
            res.responseBody = Blob.valueOf(
                JSON.serialize(errorResponse('NOT_FOUND', 'No process found for identifier: ' + idOrFuid))
            );
            return;
        }

        res.statusCode = 200;
        res.responseBody = Blob.valueOf(
            JSON.serialize(new Map<String, Object>{
                'success' => true,
                'data'    => toDto(records[0])
            })
        );
    }

    // ── List ──────────────────────────────────────────────────────────────────

    @SuppressWarnings('PMD.ApexSOQLInjection')
    private static void handleList(RestRequest req, RestResponse res) {
        String reviewType   = req.params.get('reviewType');
        String status       = req.params.get('status');
        String agencyId     = req.params.get('agencyId');
        String updatedSince = req.params.get('updatedSince');

        Integer pageSize = parseIntParam(req.params.get('pageSize'), DEFAULT_PAGE_SIZE, MAX_PAGE_SIZE);
        Integer page     = parseIntParam(req.params.get('page'), 1, null);
        Integer offset   = (page - 1) * pageSize;

        // Build dynamic WHERE clauses — no user-controlled string interpolation
        List<String> clauses = new List<String>();

        if (String.isNotBlank(reviewType)) {
            clauses.add('nepa_review_type__c = :reviewType');
        }
        if (String.isNotBlank(status)) {
            clauses.add('nepa_process_status__c = :status');
        }
        if (String.isNotBlank(agencyId)) {
            clauses.add('nepa_agency_id__c = :agencyId');
        }

        DateTime updatedSinceDt = null;
        if (String.isNotBlank(updatedSince)) {
            try {
                updatedSinceDt = (DateTime) JSON.deserialize('"' + updatedSince + '"', DateTime.class);
                clauses.add('LastModifiedDate >= :updatedSinceDt');
            } catch (Exception e) {
                res.statusCode = 400;
                res.responseBody = Blob.valueOf(
                    JSON.serialize(errorResponse('INVALID_PARAM', 'updatedSince must be ISO-8601 (e.g. 2025-01-01T00:00:00Z)'))
                );
                return;
            }
        }

        String whereClause = clauses.isEmpty() ? '' : ' WHERE ' + String.join(clauses, ' AND ');

        // Count query — uses same filters, no LIMIT/OFFSET
        Integer totalCount = Database.countQuery(
            'SELECT COUNT() FROM IndividualApplication' + whereClause,
            AccessLevel.USER_MODE
        );

        List<IndividualApplication> records = Database.query(
            'SELECT Id, Name,'
            + ' nepa_federal_unique_id__c,'
            + ' nepa_review_type__c,'
            + ' nepa_process_status__c,'
            + ' nepa_process_stage__c,'
            + ' nepa_agency_id__c,'
            + ' nepa_start_date__c,'
            + ' nepa_target_completion_date__c,'
            + ' nepa_sla_due_date__c,'
            + ' nepa_sla_overdue__c,'
            + ' nepa_risk_score__c,'
            + ' nepa_risk_tier__c,'
            + ' nepa_record_completeness__c,'
            + ' nepa_last_stage_transition__c,'
            + ' LastModifiedDate'
            + ' FROM IndividualApplication'
            + whereClause
            + ' ORDER BY nepa_start_date__c DESC NULLS LAST, Id ASC'
            + ' LIMIT :pageSize OFFSET :offset',
            AccessLevel.USER_MODE
        );

        List<Map<String, Object>> dtos = new List<Map<String, Object>>();
        for (IndividualApplication r : records) {
            dtos.add(toDto(r));
        }

        res.statusCode = 200;
        res.responseBody = Blob.valueOf(
            JSON.serialize(new Map<String, Object>{
                'success'    => true,
                'data'       => dtos,
                'totalCount' => totalCount,
                'page'       => page,
                'pageSize'   => pageSize
            })
        );
    }

    // ── DTO ───────────────────────────────────────────────────────────────────

    private static Map<String, Object> toDto(IndividualApplication r) {
        return new Map<String, Object>{
            'id'                   => r.Id,
            'name'                 => r.Name,
            'federalUniqueId'      => r.nepa_federal_unique_id__c,
            'reviewType'           => r.nepa_review_type__c,
            'processStatus'        => r.nepa_process_status__c,
            'processStage'         => r.nepa_process_stage__c,
            'agencyId'             => r.nepa_agency_id__c,
            'startDate'            => r.nepa_start_date__c,
            'targetCompletionDate' => r.nepa_target_completion_date__c,
            'slaDueDate'           => r.nepa_sla_due_date__c,
            'slaOverdue'           => r.nepa_sla_overdue__c,
            'riskScore'            => r.nepa_risk_score__c,
            'riskTier'             => r.nepa_risk_tier__c,
            'recordCompleteness'   => r.nepa_record_completeness__c,
            'lastStageTransition'  => r.nepa_last_stage_transition__c,
            'lastModified'         => r.LastModifiedDate
        };
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    private static Map<String, Object> errorResponse(String code, String message) {
        return new Map<String, Object>{
            'success'   => false,
            'errorCode' => code,
            'message'   => message
        };
    }

    private static Integer parseIntParam(String raw, Integer defaultVal, Integer maxVal) {
        if (String.isBlank(raw)) { return defaultVal; }
        try {
            Integer v = Integer.valueOf(raw);
            if (v < 1) { return defaultVal; }
            if (maxVal != null && v > maxVal) { return maxVal; }
            return v;
        } catch (Exception e) {
            return defaultVal;
        }
    }
}
