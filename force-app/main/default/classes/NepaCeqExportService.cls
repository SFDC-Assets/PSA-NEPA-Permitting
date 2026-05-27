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
            NEPA_Error_Event__e evt = new NEPA_Error_Event__e(
                Flow_Name__c      = 'NepaCeqExportService',
                Error_Message__c  = e.getMessage() + '\n' + e.getStackTraceString(),
                Running_User_Id__c = UserInfo.getUserId(),
                Occurred_At__c    = Datetime.now(),
                Error_Context__c  = 'URI:' + req.requestURI
            );
            EventBus.publish(evt);
        }
    }

    // ── Single record ─────────────────────────────────────────────────────────

    private static void handleSingleRecord(String idOrFuid, RestResponse res) {
        // sfge-disable-next-line MissingNullCheckOnSoqlVariable -- caller (doGet) guards isNotBlank before invoking
        List<IndividualApplication> records = [
            SELECT Id, Name,
                   nepa_federal_unique_id__c, nepa_review_type__c,
                   nepa_process_status__c, nepa_process_stage__c,
                   nepa_agency_id__c, nepa_start_date__c,
                   nepa_completion_date__c, nepa_target_completion_date__c,
                   nepa_process_outcome__c, nepa_purpose_need__c, nepa_description__c,
                   nepa_public_comment_period_start__c, nepa_public_comment_period_end_date__c,
                   nepa_joint_lead_agency__c, nepa_cooperating_agencies__c,
                   nepa_process_code__c, nepa_related_project__c,
                   nepa_record_owner_agency__c, nepa_data_source_agency__c, nepa_data_source_system__c,
                   nepa_sla_due_date__c, nepa_sla_overdue__c,
                   nepa_risk_score__c, nepa_risk_tier__c,
                   nepa_record_completeness__c, nepa_last_stage_transition__c,
                   LastModifiedDate, CreatedDate,
                   nepa_related_project__r.nepa_project_id__c,
                   nepa_related_project__r.nepa_lead_agency__r.Name,
                   nepa_related_project__r.nepa_record_owner_agency__c,
                   nepa_related_project__r.nepa_data_source_agency__c,
                   nepa_related_project__r.nepa_data_source_system__c,
                   (SELECT Id, Name,
                           nepa_permit_status__c, nepa_lead_agency__c,
                           nepa_regulatory_citation__c, nepa_is_critical_path__c,
                           nepa_sla_due_date__c, nepa_expected_completion__c,
                           nepa_actual_completion__c, nepa_external_federal_id__c,
                           nepa_last_synced__c
                    FROM Required_Permits__r
                    ORDER BY nepa_is_critical_path__c DESC, Name ASC)
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
            + ' nepa_federal_unique_id__c, nepa_review_type__c,'
            + ' nepa_process_status__c, nepa_process_stage__c,'
            + ' nepa_agency_id__c, nepa_start_date__c,'
            + ' nepa_completion_date__c, nepa_target_completion_date__c,'
            + ' nepa_process_outcome__c, nepa_purpose_need__c, nepa_description__c,'
            + ' nepa_public_comment_period_start__c, nepa_public_comment_period_end_date__c,'
            + ' nepa_joint_lead_agency__c, nepa_cooperating_agencies__c,'
            + ' nepa_process_code__c, nepa_related_project__c,'
            + ' nepa_record_owner_agency__c, nepa_data_source_agency__c, nepa_data_source_system__c,'
            + ' nepa_sla_due_date__c, nepa_sla_overdue__c,'
            + ' nepa_risk_score__c, nepa_risk_tier__c,'
            + ' nepa_record_completeness__c, nepa_last_stage_transition__c,'
            + ' LastModifiedDate, CreatedDate,'
            + ' nepa_related_project__r.nepa_project_id__c,'
            + ' nepa_related_project__r.nepa_lead_agency__r.Name,'
            + ' nepa_related_project__r.nepa_record_owner_agency__c,'
            + ' nepa_related_project__r.nepa_data_source_agency__c,'
            + ' nepa_related_project__r.nepa_data_source_system__c,'
            + ' (SELECT Id, Name,'
            + '         nepa_permit_status__c, nepa_lead_agency__c,'
            + '         nepa_regulatory_citation__c, nepa_is_critical_path__c,'
            + '         nepa_sla_due_date__c, nepa_expected_completion__c,'
            + '         nepa_actual_completion__c, nepa_external_federal_id__c,'
            + '         nepa_last_synced__c'
            + '  FROM Required_Permits__r'
            + '  ORDER BY nepa_is_critical_path__c DESC, Name ASC)'
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

    // CEQ Data Standard v1.2 process_instance shape.
    // Standard fields use snake_case per the spec; NEPA-operational fields are nested under "other".
    private static Map<String, Object> toDto(IndividualApplication r) {
        String leadAgency = r.nepa_related_project__r != null && r.nepa_related_project__r.nepa_lead_agency__r != null
            ? r.nepa_related_project__r.nepa_lead_agency__r.Name
            : null;

        return new Map<String, Object>{
            // ── CEQ standard fields ───────────────────────────────────────────
            'federal_id'              => r.nepa_federal_unique_id__c,
            'parent_project_id'       => r.nepa_related_project__r != null
                                            ? r.nepa_related_project__r.nepa_project_id__c : null,
            'agency_id'               => r.nepa_agency_id__c,
            'type'                    => r.nepa_review_type__c,
            'status'                  => r.nepa_process_status__c,
            'stage'                   => r.nepa_process_stage__c,
            'start_date'              => r.nepa_start_date__c,
            'complete_date'           => r.nepa_completion_date__c,
            'estimated_completion'    => r.nepa_target_completion_date__c,
            'outcome'                 => r.nepa_process_outcome__c,
            'purpose_need'            => r.nepa_purpose_need__c,
            'description'             => r.nepa_description__c,
            'comment_start'           => r.nepa_public_comment_period_start__c,
            'comment_end'             => r.nepa_public_comment_period_end_date__c,
            'lead_agency'             => leadAgency,
            'joint_lead_agency'       => r.nepa_joint_lead_agency__c,
            'cooperating_agencies'    => r.nepa_cooperating_agencies__c,
            'process_code'            => r.nepa_process_code__c,
            'created_at'              => r.CreatedDate,
            // ── Provenance ────────────────────────────────────────────────────
            'record_owner_agency'     => r.nepa_record_owner_agency__c != null
                                            ? r.nepa_record_owner_agency__c
                                            : (r.nepa_related_project__r != null
                                                ? r.nepa_related_project__r.nepa_record_owner_agency__c : null),
            'data_source_agency'      => r.nepa_data_source_agency__c != null
                                            ? r.nepa_data_source_agency__c
                                            : (r.nepa_related_project__r != null
                                                ? r.nepa_related_project__r.nepa_data_source_agency__c : null),
            'data_source_system'      => r.nepa_data_source_system__c != null
                                            ? r.nepa_data_source_system__c
                                            : (r.nepa_related_project__r != null
                                                ? r.nepa_related_project__r.nepa_data_source_system__c : null),
            'data_record_version'     => '1.0',
            'last_updated'            => r.LastModifiedDate,
            'retrieved_timestamp'     => Datetime.now(),
            // ── NEPA-operational (non-standard, nested per CEQ "other" field) ─
            'other'                   => new Map<String, Object>{
                'salesforce_id'           => r.Id,
                'salesforce_name'         => r.Name,
                'sla_due_date'            => r.nepa_sla_due_date__c,
                'sla_overdue'             => r.nepa_sla_overdue__c,
                'risk_score'              => r.nepa_risk_score__c,
                'risk_tier'               => r.nepa_risk_tier__c,
                'record_completeness_pct' => r.nepa_record_completeness__c,
                'last_stage_transition'   => r.nepa_last_stage_transition__c,
                'required_permits'        => toPermitDtos(r.Required_Permits__r)
            }
        };
    }

    private static List<Map<String, Object>> toPermitDtos(List<nepa_required_permit__c> permits) {
        List<Map<String, Object>> dtos = new List<Map<String, Object>>();
        if (permits == null) { return dtos; }
        for (nepa_required_permit__c p : permits) {
            dtos.add(new Map<String, Object>{
                'id'                 => p.Id,
                'name'               => p.Name,
                'permitStatus'       => p.nepa_permit_status__c,
                'leadAgency'         => p.nepa_lead_agency__c,
                'regulatoryCitation' => p.nepa_regulatory_citation__c,
                'isCriticalPath'     => p.nepa_is_critical_path__c,
                'slaDueDate'         => p.nepa_sla_due_date__c,
                'expectedCompletion' => p.nepa_expected_completion__c,
                'actualCompletion'   => p.nepa_actual_completion__c,
                'externalFederalId'  => p.nepa_external_federal_id__c,
                'lastSynced'         => p.nepa_last_synced__c
            });
        }
        return dtos;
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

    // ── CEQ Data Standard export ──────────────────────────────────────────────

    /**
     * Returns CEQ Data Standard v1.2 JSON for one process (or all active processes).
     * Reuses the same DTO shape as the REST endpoint so the export is machine-readable
     * by CEQ tooling that already consumes /nepa/v1/processes/.
     *
     * @param processId  IndividualApplication Id to scope to one record; null = all active
     * @return           JSON string — array when processId is null, single object when scoped
     */
    @AuraEnabled(cacheable=false)
    public static String generateCeqExport(Id processId) {
        if (processId != null) {
            List<IndividualApplication> records = [
                SELECT Id, Name,
                       nepa_federal_unique_id__c, nepa_review_type__c,
                       nepa_process_status__c, nepa_process_stage__c,
                       nepa_agency_id__c, nepa_start_date__c,
                       nepa_completion_date__c, nepa_target_completion_date__c,
                       nepa_process_outcome__c, nepa_purpose_need__c, nepa_description__c,
                       nepa_public_comment_period_start__c, nepa_public_comment_period_end_date__c,
                       nepa_joint_lead_agency__c, nepa_cooperating_agencies__c,
                       nepa_process_code__c, nepa_related_project__c,
                       nepa_record_owner_agency__c, nepa_data_source_agency__c, nepa_data_source_system__c,
                       nepa_sla_due_date__c, nepa_sla_overdue__c,
                       nepa_risk_score__c, nepa_risk_tier__c,
                       nepa_record_completeness__c, nepa_last_stage_transition__c,
                       LastModifiedDate, CreatedDate,
                       nepa_related_project__r.nepa_project_id__c,
                       nepa_related_project__r.nepa_lead_agency__r.Name,
                       nepa_related_project__r.nepa_record_owner_agency__c,
                       nepa_related_project__r.nepa_data_source_agency__c,
                       nepa_related_project__r.nepa_data_source_system__c,
                       (SELECT Id, Name, nepa_permit_status__c, nepa_lead_agency__c,
                               nepa_regulatory_citation__c, nepa_is_critical_path__c,
                               nepa_sla_due_date__c, nepa_expected_completion__c,
                               nepa_actual_completion__c, nepa_external_federal_id__c,
                               nepa_last_synced__c
                        FROM Required_Permits__r
                        ORDER BY nepa_is_critical_path__c DESC, Name ASC)
                FROM IndividualApplication
                WHERE Id = :processId
                WITH SECURITY_ENFORCED
                LIMIT 1
            ];
            if (records.isEmpty()) { return JSON.serialize(new Map<String, Object>{ 'error' => 'Record not found' }); }
            return JSON.serialize(toDto(records[0]));
        }

        List<IndividualApplication> records = [
            SELECT Id, Name,
                   nepa_federal_unique_id__c, nepa_review_type__c,
                   nepa_process_status__c, nepa_process_stage__c,
                   nepa_agency_id__c, nepa_start_date__c,
                   nepa_completion_date__c, nepa_target_completion_date__c,
                   nepa_process_outcome__c, nepa_purpose_need__c, nepa_description__c,
                   nepa_public_comment_period_start__c, nepa_public_comment_period_end_date__c,
                   nepa_joint_lead_agency__c, nepa_cooperating_agencies__c,
                   nepa_process_code__c, nepa_related_project__c,
                   nepa_record_owner_agency__c, nepa_data_source_agency__c, nepa_data_source_system__c,
                   nepa_sla_due_date__c, nepa_sla_overdue__c,
                   nepa_risk_score__c, nepa_risk_tier__c,
                   nepa_record_completeness__c, nepa_last_stage_transition__c,
                   LastModifiedDate, CreatedDate,
                   nepa_related_project__r.nepa_project_id__c,
                   nepa_related_project__r.nepa_lead_agency__r.Name,
                   nepa_related_project__r.nepa_record_owner_agency__c,
                   nepa_related_project__r.nepa_data_source_agency__c,
                   nepa_related_project__r.nepa_data_source_system__c,
                   (SELECT Id, Name, nepa_permit_status__c, nepa_lead_agency__c,
                           nepa_regulatory_citation__c, nepa_is_critical_path__c,
                           nepa_sla_due_date__c, nepa_expected_completion__c,
                           nepa_actual_completion__c, nepa_external_federal_id__c,
                           nepa_last_synced__c
                    FROM Required_Permits__r
                    ORDER BY nepa_is_critical_path__c DESC, Name ASC)
            FROM IndividualApplication
            WHERE nepa_process_status__c NOT IN ('Closed', 'Withdrawn', 'completed')
            WITH SECURITY_ENFORCED
            ORDER BY nepa_start_date__c DESC NULLS LAST, Id ASC
        ];
        List<Map<String, Object>> dtos = new List<Map<String, Object>>();
        for (IndividualApplication r : records) { dtos.add(toDto(r)); }
        return JSON.serialize(dtos);
    }

    // ── FPISC / FAST-41 export ─────────────────────────────────────────────────

    /** Per-process row for FPISC dashboard export. */
    public class FPISCRow {
        @AuraEnabled public String  projectName;
        @AuraEnabled public String  federalUniqueId;
        @AuraEnabled public String  leadAgency;
        @AuraEnabled public String  reviewType;
        @AuraEnabled public Integer daysElapsed;
        @AuraEnabled public Integer ofdTargetDays;
        @AuraEnabled public Integer ofdVarianceDays;
        @AuraEnabled public String  stage;
        @AuraEnabled public String  status;
    }

    /**
     * Returns FPISC export rows for all active FAST-41-covered NEPA processes.
     * When programId is provided, scopes to child processes of that Program.
     * @param programId  Optional Program (project) Id to scope to one project
     * @return           List of FPISCRow, one per covered IndividualApplication
     */
    @AuraEnabled(cacheable=false)
    public static List<FPISCRow> generateFPISCExport(Id programId) {
        List<IndividualApplication> records = queryFast41Records(programId);
        List<FPISCRow> rows = new List<FPISCRow>();
        for (IndividualApplication ia : records) {
            FPISCRow row       = new FPISCRow();
            row.projectName    = ia.Name;
            row.federalUniqueId = ia.nepa_federal_unique_id__c;
            row.leadAgency     = ia.nepa_data_source_agency__c;
            row.reviewType     = ia.nepa_review_type__c;
            row.daysElapsed    = ia.nepa_days_elapsed__c != null
                ? ia.nepa_days_elapsed__c.intValue() : 0;
            row.ofdTargetDays  = ia.nepa_ofd_target_days__c != null
                ? ia.nepa_ofd_target_days__c.intValue() : null;
            row.ofdVarianceDays = (row.ofdTargetDays != null)
                ? row.daysElapsed - row.ofdTargetDays : null;
            row.stage          = ia.nepa_process_stage__c;
            row.status         = ia.nepa_process_status__c;
            rows.add(row);
        }
        return rows;
    }

    @SuppressWarnings('PMD.ApexCRUDViolation')
    private static List<IndividualApplication> queryFast41Records(Id programId) {
        if (programId != null) {
            return [
                SELECT Id, Name, nepa_federal_unique_id__c,
                       nepa_data_source_agency__c, nepa_review_type__c,
                       nepa_days_elapsed__c, nepa_ofd_target_days__c,
                       nepa_process_stage__c, nepa_process_status__c
                FROM IndividualApplication
                WHERE nepa_fast41_covered__c = true
                  AND nepa_related_project__c = :programId
                ORDER BY Name ASC
            ];
        }
        return [
            SELECT Id, Name, nepa_federal_unique_id__c,
                   nepa_data_source_agency__c, nepa_review_type__c,
                   nepa_days_elapsed__c, nepa_ofd_target_days__c,
                   nepa_process_stage__c, nepa_process_status__c
            FROM IndividualApplication
            WHERE nepa_fast41_covered__c = true
              AND nepa_process_status__c NOT IN ('Closed', 'Withdrawn', 'completed')
            ORDER BY Name ASC
        ];
    }

    // ── Year-over-year trend ───────────────────────────────────────────────────

    /** One year-by-review-type trend bucket. */
    public class YoYTrendBucket {
        @AuraEnabled public Integer calendarYear;
        @AuraEnabled public String  reviewType;
        @AuraEnabled public Integer processCount;
        @AuraEnabled public Decimal avgDaysToCompletion;
    }

    /**
     * Returns aggregate year-over-year trend data for completed NEPA processes,
     * grouped by calendar year and review type.
     * @param years  Number of years back from today to include (e.g. 5)
     * @return       List of YoYTrendBucket
     */
    @AuraEnabled(cacheable=true)
    public static List<YoYTrendBucket> getYearOverYearTrend(Integer years) {
        if (years == null || years < 1) { years = 5; }
        Date cutoff = Date.today().addYears(-years);

        List<AggregateResult> results = [
            SELECT CALENDAR_YEAR(nepa_completion_date__c) yr,
                   nepa_review_type__c reviewType,
                   COUNT(Id) cnt,
                   AVG(nepa_days_elapsed__c) avgDays
            FROM IndividualApplication
            WHERE nepa_process_status__c IN ('completed', 'Closed')
              AND nepa_completion_date__c != null
              AND nepa_completion_date__c >= :cutoff
            WITH USER_MODE
            GROUP BY CALENDAR_YEAR(nepa_completion_date__c), nepa_review_type__c
            ORDER BY CALENDAR_YEAR(nepa_completion_date__c) ASC, nepa_review_type__c ASC
        ];

        List<YoYTrendBucket> buckets = new List<YoYTrendBucket>();
        for (AggregateResult ar : results) {
            YoYTrendBucket b    = new YoYTrendBucket();
            b.calendarYear      = (Integer) ar.get('yr');
            b.reviewType        = (String)  ar.get('reviewType');
            b.processCount      = (Integer) ar.get('cnt');
            b.avgDaysToCompletion = ar.get('avgDays') != null
                ? ((Decimal) ar.get('avgDays')).setScale(1) : null;
            buckets.add(b);
        }
        return buckets;
    }
}
