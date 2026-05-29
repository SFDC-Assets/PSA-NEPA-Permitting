/**
 * PIC v1.2 schema enum conformance tests.
 *
 * Verifies that the NepaCeqFullExportService and NepaCeqExportService output values
 * that conform to the CEQ NEPA and Permitting Data and Technology Standard v1.2
 * JSON schema enum constraints, as defined in pic-standards/src/jsonschema/nepa.schema.json.
 *
 * Enum constraints tested:
 *   process_instance.status  : ["planned","underway","paused","completed"]
 *   project.current_status   : ["pre-application","underway","paused","completed"]
 *   gis_data_element.purpose : ["bespoke","analysis","base map"]  (future — field uses richer values)
 *   case_event.datetime      : required ISO 8601 string
 *
 * Does NOT modify existing NepaCeqComplianceTest — runs independently.
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs,PMD.ApexDoc')
@IsTest(SeeAllData=false)
private class NepaCeqStandardsConformanceTest {

    private static final Set<String> PIC_PROCESS_STATUS = new Set<String>{
        'planned', 'underway', 'paused', 'completed'
    };

    private static final Set<String> PIC_PROJECT_STATUS = new Set<String>{
        'pre-application', 'underway', 'paused', 'completed'
    };

    private static final Set<String> PIC_REVIEW_TYPE = new Set<String>{
        'EIS', 'EA', 'CE', 'Other'
    };

    // ── @TestSetup: one record per internal status/type value ──────────────────

    @TestSetup
    static void setup() {
        Account acct = new Account(Name = 'ConformanceTestAgency');
        insert acct;

        // Create one project per internal status value to cover full mapping table
        for (String rawStatus : new List<String>{
                'planned', 'pre-application', 'in progress', 'paused', 'completed', 'cancelled'}) {
            Program p = new Program();
            p.Name                        = 'ConformanceProj-' + rawStatus;
            p.nepa_project_id__c          = 'CONF-PROJ-' + rawStatus.replaceAll(' ', '-');
            p.nepa_project_title__c       = 'ConformanceProj-' + rawStatus;
            p.nepa_lead_agency__c         = acct.Id;
            p.nepa_project_sector__c      = 'Energy';
            p.nepa_project_type__c        = 'EA';
            p.nepa_current_status__c      = rawStatus;
            p.nepa_project_description__c = 'Conformance test project for status: ' + rawStatus;
            p.nepa_record_owner_agency__c = 'TestAgency';
            p.nepa_data_source_agency__c  = 'TestAgency';
            p.nepa_data_source_system__c  = 'test';
            p.nepa_data_record_version__c = '1.2';
            p.nepa_retrieved_timestamp__c = DateTime.now();
            insert p;

            // One process per project/status so we can verify process status mapping
            IndividualApplication ia = new IndividualApplication();
            ia.Category                              = 'Permit';
            ia.LicenseTypeId                         = getLicenseTypeId();
            ia.nepa_related_project__c               = p.Id;
            ia.nepa_federal_unique_id__c             = 'CONF-IA-' + rawStatus.replaceAll(' ', '-');
            ia.nepa_review_type__c                   = 'EA';
            ia.nepa_process_status__c                = rawStatus;
            ia.nepa_process_stage__c                 = 'Scoping';
            ia.nepa_climate_assessment_required__c   = true;
            ia.nepa_climate_assessment_complete__c   = true;
            ia.nepa_description__c                   = 'Conformance test process for status: ' + rawStatus
                + '. This description is intentionally padded to exceed the 200-character minimum'
                + ' required by the NEPA_ProcessDescription_MinLength validation rule so that'
                + ' this record inserts successfully in all org configurations.';
            ia.nepa_public_comment_period_end_date__c = DateTime.now().addYears(10);
            ia.nepa_record_owner_agency__c           = 'TestAgency';
            ia.nepa_data_source_agency__c            = 'TestAgency';
            ia.nepa_data_source_system__c            = 'test';
            ia.nepa_data_record_version__c           = '1.2';
            ia.nepa_retrieved_timestamp__c           = DateTime.now();
            insert ia;

            // One case event per process so we can verify datetime formatting
            ApplicationTimeline evt = new ApplicationTimeline();
            evt.nepa_related_process__c    = ia.Id;
            evt.Name                       = 'Conformance Event';
            evt.nepa_event_type__c         = 'Scoping Open';
            evt.nepa_tier__c               = '1';
            evt.nepa_status__c             = 'Completed';
            evt.nepa_retrieved_timestamp__c = DateTime.now();
            evt.nepa_data_record_version__c = '1.2';
            evt.nepa_data_source_agency__c  = 'TestAgency';
            evt.nepa_data_source_system__c  = 'test';
            evt.nepa_record_owner_agency__c = 'TestAgency';
            insert evt;
        }

        // One process with review type "Other Authorization" to verify type mapping
        Program projOther = [SELECT Id FROM Program WHERE nepa_project_id__c = 'CONF-PROJ-planned' LIMIT 1];
        IndividualApplication iaOther = new IndividualApplication();
        iaOther.Category                             = 'Permit';
        iaOther.LicenseTypeId                        = getLicenseTypeId();
        iaOther.nepa_related_project__c              = projOther.Id;
        iaOther.nepa_federal_unique_id__c            = 'CONF-IA-other-auth';
        iaOther.nepa_review_type__c                  = 'Other Authorization';
        iaOther.nepa_process_status__c               = 'planned';
        iaOther.nepa_process_stage__c                = 'Pre-Application';
        iaOther.nepa_climate_assessment_required__c  = true;
        iaOther.nepa_climate_assessment_complete__c  = true;
        iaOther.nepa_description__c                  = 'Conformance test for Other Authorization type mapping. This description is'
            + ' padded to 200+ characters to satisfy the NEPA_ProcessDescription_MinLength'
            + ' validation rule in environments where that rule is active.';
        iaOther.nepa_public_comment_period_end_date__c = DateTime.now().addYears(10);
        iaOther.nepa_record_owner_agency__c          = 'TestAgency';
        iaOther.nepa_data_source_agency__c           = 'TestAgency';
        iaOther.nepa_data_source_system__c           = 'test';
        iaOther.nepa_data_record_version__c          = '1.2';
        insert iaOther;
    }

    // ── Process status mapping ─────────────────────────────────────────────────

    @IsTest
    static void processStatus_inProgress_exportedAsUnderway() {
        IndividualApplication ia = [
            SELECT Id FROM IndividualApplication
            WHERE nepa_federal_unique_id__c = 'CONF-IA-in-progress' LIMIT 1
        ];
        Map<String, Object> dto = callSingleProcessExport(ia.Id);
        System.assertEquals('underway', dto.get('status'),
            '"in progress" must map to PIC "underway" in export; got: ' + dto.get('status'));
    }

    @IsTest
    static void processStatus_preApplication_exportedAsPlanned() {
        IndividualApplication ia = [
            SELECT Id FROM IndividualApplication
            WHERE nepa_federal_unique_id__c = 'CONF-IA-pre-application' LIMIT 1
        ];
        Map<String, Object> dto = callSingleProcessExport(ia.Id);
        System.assertEquals('planned', dto.get('status'),
            '"pre-application" must map to PIC "planned" in export; got: ' + dto.get('status'));
    }

    @IsTest
    static void processStatus_cancelled_exportedAsCompleted() {
        IndividualApplication ia = [
            SELECT Id FROM IndividualApplication
            WHERE nepa_federal_unique_id__c = 'CONF-IA-cancelled' LIMIT 1
        ];
        Map<String, Object> dto = callSingleProcessExport(ia.Id);
        System.assertEquals('completed', dto.get('status'),
            '"cancelled" must map to PIC "completed" in export; got: ' + dto.get('status'));
    }

    @IsTest
    static void processStatus_planned_exportedUnchanged() {
        IndividualApplication ia = [
            SELECT Id FROM IndividualApplication
            WHERE nepa_federal_unique_id__c = 'CONF-IA-planned' LIMIT 1
        ];
        Map<String, Object> dto = callSingleProcessExport(ia.Id);
        System.assertEquals('planned', dto.get('status'),
            '"planned" must pass through unchanged; got: ' + dto.get('status'));
    }

    @IsTest
    static void processStatus_paused_exportedUnchanged() {
        IndividualApplication ia = [
            SELECT Id FROM IndividualApplication
            WHERE nepa_federal_unique_id__c = 'CONF-IA-paused' LIMIT 1
        ];
        Map<String, Object> dto = callSingleProcessExport(ia.Id);
        System.assertEquals('paused', dto.get('status'),
            '"paused" must pass through unchanged; got: ' + dto.get('status'));
    }

    @IsTest
    static void processStatus_completed_exportedUnchanged() {
        IndividualApplication ia = [
            SELECT Id FROM IndividualApplication
            WHERE nepa_federal_unique_id__c = 'CONF-IA-completed' LIMIT 1
        ];
        Map<String, Object> dto = callSingleProcessExport(ia.Id);
        System.assertEquals('completed', dto.get('status'),
            '"completed" must pass through unchanged; got: ' + dto.get('status'));
    }

    @IsTest
    static void allExportedProcessStatuses_areInPicEnum() {
        List<IndividualApplication> ias = [
            SELECT Id FROM IndividualApplication
            WHERE nepa_federal_unique_id__c LIKE 'CONF-IA-%'
        ];
        for (IndividualApplication ia : ias) {
            Map<String, Object> dto = callSingleProcessExport(ia.Id);
            String status = (String) dto.get('status');
            System.assert(PIC_PROCESS_STATUS.contains(status),
                'Exported status "' + status + '" is not in PIC v1.2 enum '
                + PIC_PROCESS_STATUS + ' for IA ' + ia.Id);
        }
    }

    // ── Process type mapping ───────────────────────────────────────────────────

    @IsTest
    static void reviewType_otherAuthorization_exportedAsOther() {
        IndividualApplication ia = [
            SELECT Id FROM IndividualApplication
            WHERE nepa_federal_unique_id__c = 'CONF-IA-other-auth' LIMIT 1
        ];
        Map<String, Object> dto = callSingleProcessExport(ia.Id);
        System.assertEquals('Other', dto.get('type'),
            '"Other Authorization" must map to PIC "Other" in export; got: ' + dto.get('type'));
    }

    @IsTest
    static void reviewType_ea_exportedUnchanged() {
        IndividualApplication ia = [
            SELECT Id FROM IndividualApplication
            WHERE nepa_federal_unique_id__c = 'CONF-IA-planned' LIMIT 1
        ];
        Map<String, Object> dto = callSingleProcessExport(ia.Id);
        System.assertEquals('EA', dto.get('type'),
            '"EA" must pass through unchanged; got: ' + dto.get('type'));
    }

    @IsTest
    static void allExportedReviewTypes_areInPicEnum() {
        List<IndividualApplication> ias = [
            SELECT Id FROM IndividualApplication
            WHERE nepa_federal_unique_id__c LIKE 'CONF-IA-%'
        ];
        for (IndividualApplication ia : ias) {
            Map<String, Object> dto = callSingleProcessExport(ia.Id);
            String reviewType = (String) dto.get('type');
            if (reviewType != null) {
                System.assert(PIC_REVIEW_TYPE.contains(reviewType),
                    'Exported type "' + reviewType + '" is not in PIC v1.2 enum '
                    + PIC_REVIEW_TYPE + ' for IA ' + ia.Id);
            }
        }
    }

    // ── Raw values preserved in other{} ───────────────────────────────────────

    @IsTest
    static void rawStatus_preservedInOtherBlock() {
        IndividualApplication ia = [
            SELECT Id FROM IndividualApplication
            WHERE nepa_federal_unique_id__c = 'CONF-IA-in-progress' LIMIT 1
        ];
        Map<String, Object> dto = callSingleProcessExport(ia.Id);
        Map<String, Object> other = (Map<String, Object>) dto.get('other');
        System.assertNotEquals(null, other, 'other block must be present');
        System.assertEquals('in progress', other.get('raw_status'),
            'other.raw_status must preserve the original "in progress" value; got: '
            + other.get('raw_status'));
    }

    @IsTest
    static void rawReviewType_preservedInOtherBlock() {
        IndividualApplication ia = [
            SELECT Id FROM IndividualApplication
            WHERE nepa_federal_unique_id__c = 'CONF-IA-other-auth' LIMIT 1
        ];
        Map<String, Object> dto = callSingleProcessExport(ia.Id);
        Map<String, Object> other = (Map<String, Object>) dto.get('other');
        System.assertNotEquals(null, other, 'other block must be present');
        System.assertEquals('Other Authorization', other.get('raw_review_type'),
            'other.raw_review_type must preserve "Other Authorization"; got: '
            + other.get('raw_review_type'));
    }

    // ── Project status mapping (full export) ──────────────────────────────────

    @IsTest
    static void projectStatus_inProgress_exportedAsUnderway_fullExport() {
        Program proj = [
            SELECT Id FROM Program WHERE nepa_project_id__c = 'CONF-PROJ-in-progress' LIMIT 1
        ];
        Map<String, Object> projectDto = callFullExport(proj.Id);
        System.assertEquals('underway', projectDto.get('status'),
            'project "in progress" must map to PIC "underway" in full export; got: '
            + projectDto.get('status'));
    }

    @IsTest
    static void projectStatus_preApplication_exportedAsPreApplication_fullExport() {
        Program proj = [
            SELECT Id FROM Program WHERE nepa_project_id__c = 'CONF-PROJ-pre-application' LIMIT 1
        ];
        Map<String, Object> projectDto = callFullExport(proj.Id);
        System.assertEquals('pre-application', projectDto.get('status'),
            'project "pre-application" must map to PIC "pre-application"; got: '
            + projectDto.get('status'));
    }

    @IsTest
    static void allProjectStatuses_areInPicEnum_fullExport() {
        List<Program> projects = [
            SELECT Id FROM Program WHERE nepa_project_id__c LIKE 'CONF-PROJ-%'
        ];
        for (Program proj : projects) {
            Map<String, Object> projectDto = callFullExport(proj.Id);
            String status = (String) projectDto.get('status');
            if (status != null) {
                System.assert(PIC_PROJECT_STATUS.contains(status),
                    'Exported project status "' + status + '" is not in PIC v1.2 enum '
                    + PIC_PROJECT_STATUS + ' for project ' + proj.Id);
            }
        }
    }

    // ── Case event datetime format ─────────────────────────────────────────────

    @IsTest
    static void caseEvent_datetime_isIso8601Format() {
        Program proj = [
            SELECT Id FROM Program WHERE nepa_project_id__c = 'CONF-PROJ-in-progress' LIMIT 1
        ];
        Map<String, Object> projectDto = callFullExport(proj.Id);
        List<Object> processes = (List<Object>) projectDto.get('processes');
        System.assert(processes != null && !processes.isEmpty(), 'processes must be present');
        Map<String, Object> process = (Map<String, Object>) processes[0];
        List<Object> events = (List<Object>) process.get('case_events');
        System.assert(events != null && !events.isEmpty(),
            'case_events must be present for conformance test process');
        Map<String, Object> evt = (Map<String, Object>) events[0];
        System.assert(evt.containsKey('datetime'),
            'case_event DTO must contain "datetime" key (PIC v1.2 required field)');
        Object dtVal = evt.get('datetime');
        if (dtVal != null) {
            String dtStr = String.valueOf(dtVal);
            Pattern iso8601 = Pattern.compile('\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}Z');
            System.assert(iso8601.matcher(dtStr).matches(),
                'case_event.datetime must be ISO 8601 format (yyyy-MM-ddTHH:mm:ssZ); got: ' + dtStr);
        }
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    private static Map<String, Object> callSingleProcessExport(Id processId) {
        RestRequest req = new RestRequest();
        req.requestURI  = '/services/apexrest/nepa/v1/processes/' + processId;
        req.httpMethod  = 'GET';
        RestContext.request  = req;
        RestContext.response = new RestResponse();
        NepaCeqExportService.doGet();
        Map<String, Object> resp = (Map<String, Object>)
            JSON.deserializeUntyped(RestContext.response.responseBody.toString());
        return (Map<String, Object>) resp.get('data');
    }

    private static Map<String, Object> callFullExport(Id programId) {
        RestRequest req = new RestRequest();
        req.requestURI   = '/services/apexrest/nepa/v1/export/project';
        req.httpMethod   = 'POST';
        req.requestBody  = Blob.valueOf('{"projectId":"' + programId + '"}');
        RestContext.request  = req;
        RestContext.response = new RestResponse();
        NepaCeqFullExportService.doPost();
        Map<String, Object> resp = (Map<String, Object>)
            JSON.deserializeUntyped(RestContext.response.responseBody.toString());
        Map<String, Object> data = (Map<String, Object>) resp.get('data');
        return (Map<String, Object>) data.get('project');
    }

    private static Id getLicenseTypeId() {
        List<RegulatoryAuthorizationType> existing = [
            SELECT Id FROM RegulatoryAuthorizationType
            WHERE Name = 'NEPA Environmental Review' LIMIT 1
        ];
        if (!existing.isEmpty()) { return existing[0].Id; }
        RegulatoryAuthorizationType rat = new RegulatoryAuthorizationType(
            Name = 'NEPA Environmental Review', RegulatoryAuthCategory = 'Permit');
        insert rat;
        return rat.Id;
    }
}
