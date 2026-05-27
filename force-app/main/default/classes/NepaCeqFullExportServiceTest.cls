@SuppressWarnings('PMD.ApexAssertionsShouldIncludeMessage,PMD.MethodNamingConventions,PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest
private class NepaCeqFullExportServiceTest {

    // ── Helpers ───────────────────────────────────────────────────────────────

    private static RestRequest buildPostRequest(String projectId) {
        RestRequest req = new RestRequest();
        req.httpMethod   = 'POST';
        req.requestURI   = '/services/apexrest/nepa/v1/export/project';
        req.requestBody  = Blob.valueOf(
            projectId != null ? '{"projectId":"' + projectId + '"}' : '{}'
        );
        return req;
    }

    private static Map<String, Object> parseBody() {
        return (Map<String, Object>) JSON.deserializeUntyped(
            RestContext.response.responseBody.toString()
        );
    }

    private static Map<String, Object> callExport(String projectId) {
        RestContext.request  = buildPostRequest(projectId);
        RestContext.response = new RestResponse();
        Test.startTest();
        NepaCeqFullExportService.doPost();
        Test.stopTest();
        return parseBody();
    }

    // ── 400 / 404 guard rails ─────────────────────────────────────────────────

    @IsTest
    static void export_missingProjectId_returns400() {
        RestContext.request  = new RestRequest();
        RestContext.request.httpMethod  = 'POST';
        RestContext.request.requestURI  = '/services/apexrest/nepa/v1/export/project';
        RestContext.request.requestBody = Blob.valueOf('{}');
        RestContext.response = new RestResponse();

        Test.startTest();
        NepaCeqFullExportService.doPost();
        Test.stopTest();

        System.assertEquals(400, RestContext.response.statusCode);
        Map<String, Object> body = parseBody();
        System.assertEquals(false, body.get('success'));
        System.assertEquals('MISSING_PARAM', (String) body.get('errorCode'));
    }

    @IsTest
    static void export_unknownProjectId_returns404() {
        Map<String, Object> body = callExport('001000000000001AAA');

        System.assertEquals(404, RestContext.response.statusCode);
        System.assertEquals(false, body.get('success'));
        System.assertEquals('NOT_FOUND', (String) body.get('errorCode'));
    }

    @IsTest
    static void export_invalidId_returns400() {
        RestContext.request  = new RestRequest();
        RestContext.request.httpMethod  = 'POST';
        RestContext.request.requestURI  = '/services/apexrest/nepa/v1/export/project';
        RestContext.request.requestBody = Blob.valueOf('{"projectId":"not-an-id"}');
        RestContext.response = new RestResponse();

        Test.startTest();
        NepaCeqFullExportService.doPost();
        Test.stopTest();

        System.assertEquals(400, RestContext.response.statusCode);
        Map<String, Object> body = parseBody();
        System.assertEquals(false, body.get('success'));
        System.assertEquals('INVALID_PARAM', (String) body.get('errorCode'));
    }

    // ── Schema version ────────────────────────────────────────────────────────

    @IsTest
    static void export_schemaVersionIs12() {
        Program proj = NepaTestFactory.insertProgram('CEQ-SV-001', 'Schema Version Test', 'BLM');

        Map<String, Object> body = callExport(proj.Id);

        System.assertEquals(200, RestContext.response.statusCode);
        System.assertEquals(true, body.get('success'));
        Map<String, Object> data = (Map<String, Object>) body.get('data');
        System.assertEquals('1.2', (String) data.get('schema_version'));
        System.assertEquals('CEQ NEPA and Permitting Data and Technology Standard',
            (String) data.get('standard'));
        System.assertNotEquals(null, data.get('exported_at'));
    }

    // ── Empty project ─────────────────────────────────────────────────────────

    @IsTest
    static void export_emptyProject_noProcesses_returnsEmptyArray() {
        Program proj = NepaTestFactory.insertProgram('CEQ-EMPTY-001', 'Empty Project', 'NPS');

        Map<String, Object> body = callExport(proj.Id);

        System.assertEquals(200, RestContext.response.statusCode);
        Map<String, Object> data = (Map<String, Object>) body.get('data');
        Map<String, Object> project = (Map<String, Object>) data.get('project');
        System.assertEquals(String.valueOf(proj.Id), (String) project.get('id'));
        List<Object> processes = (List<Object>) project.get('processes');
        System.assertNotEquals(null, processes);
        System.assertEquals(0, processes.size());
    }

    // ── Full payload shape ────────────────────────────────────────────────────

    @IsTest
    static void export_validProject_returnsFullPayload() {
        Program proj = NepaTestFactory.insertProgram('CEQ-FULL-001', 'Full Payload Test', 'BLM');
        IndividualApplication ia = NepaTestFactory.insertOpenProcess(proj.Id, 'EIS');
        ia.nepa_federal_unique_id__c = 'FUID-FULL-001';
        update ia;

        ContentVersion cv = NepaTestFactory.insertPublicContentVersion(ia.Id, 'Draft EIS');
        NepaTestFactory.insertPublicEngagement(ia.Id);
        NepaTestFactory.insertPublicTimelineEvent(ia.Id);
        NepaTestFactory.insertRequiredPermit(ia.Id, 'Not Started', true, Date.today().addDays(90));
        NepaTestFactory.insertTeamMember(ia.Id, null, 'Reviewer');
        NepaTestFactory.insertGisData(proj.Id, ia.Id);

        Map<String, Object> body = callExport(proj.Id);

        System.assertEquals(200, RestContext.response.statusCode);
        System.assertEquals(true, body.get('success'));

        Map<String, Object> data    = (Map<String, Object>) body.get('data');
        Map<String, Object> project = (Map<String, Object>) data.get('project');
        System.assertEquals(String.valueOf(proj.Id), (String) project.get('id'));

        List<Object> processes = (List<Object>) project.get('processes');
        System.assertEquals(1, processes.size());

        Map<String, Object> process = (Map<String, Object>) processes[0];
        System.assertEquals(String.valueOf(ia.Id), (String) process.get('id'));

        System.assert(process.containsKey('documents'));
        System.assert(process.containsKey('public_engagement_events'));
        System.assert(process.containsKey('case_events'));
        System.assert(process.containsKey('team_members'));
        System.assert(process.containsKey('legal_structure'));
        System.assert(process.containsKey('gis_data'));
        System.assert(process.containsKey('permits'));

        List<Object> docs = (List<Object>) process.get('documents');
        System.assertEquals(1, docs.size());
        List<Object> engagements = (List<Object>) process.get('public_engagement_events');
        System.assertEquals(1, engagements.size());
        List<Object> caseEvents = (List<Object>) process.get('case_events');
        System.assertEquals(1, caseEvents.size());
        List<Object> team = (List<Object>) process.get('team_members');
        System.assertEquals(1, team.size());
        List<Object> permits = (List<Object>) process.get('permits');
        System.assertEquals(1, permits.size());
    }

    // ── CEQ property names (snake_case) ───────────────────────────────────────

    @IsTest
    static void export_processFields_mapToCeqNames() {
        Program proj = NepaTestFactory.insertProgram('CEQ-NAMES-001', 'CEQ Names Test', 'USFS');
        IndividualApplication ia = NepaTestFactory.insertOpenProcess(proj.Id, 'EA');
        ia.nepa_federal_unique_id__c = 'FUID-NAMES-001';
        ia.nepa_agency_id__c         = 'USFS-2026-001';
        ia.nepa_description__c       = 'Test process description for the Big Timber EA. '
            + 'This project involves commercial timber harvest across approximately 1,500 acres '
            + 'of existing National Forest land. The purpose is to improve forest health and '
            + 'reduce wildfire risk through selective harvest and prescribed burning activities.';
        update ia;

        Map<String, Object> body = callExport(proj.Id);

        System.assertEquals(200, RestContext.response.statusCode);
        Map<String, Object> data    = (Map<String, Object>) body.get('data');
        Map<String, Object> project = (Map<String, Object>) data.get('project');
        List<Object> processes      = (List<Object>) project.get('processes');
        Map<String, Object> process = (Map<String, Object>) processes[0];

        System.assertEquals('FUID-NAMES-001', (String) process.get('federal_unique_id'),
            'Must use CEQ property name federal_unique_id, not federalUniqueId');
        System.assertEquals('EA', (String) process.get('nepa_review_type'),
            'Must use CEQ property name nepa_review_type, not reviewType');
        System.assert(String.isNotBlank((String) process.get('process_description')),
            'Must use CEQ property name process_description, not description');
        System.assertEquals('USFS-2026-001', (String) process.get('agency_process_id'),
            'Must use CEQ property name agency_process_id, not agencyId');

        System.assert(!process.containsKey('federalUniqueId'), 'Must NOT contain camelCase federalUniqueId');
        System.assert(!process.containsKey('reviewType'), 'Must NOT contain camelCase reviewType');
    }

    @IsTest
    static void export_projectFields_mapToCeqNames() {
        Program proj = NepaTestFactory.insertProgram('CEQ-PROJ-001', 'My Project Title', 'BLM');

        Map<String, Object> body = callExport(proj.Id);

        System.assertEquals(200, RestContext.response.statusCode);
        Map<String, Object> data    = (Map<String, Object>) body.get('data');
        Map<String, Object> project = (Map<String, Object>) data.get('project');

        System.assertEquals(String.valueOf(proj.Id), (String) project.get('id'));
        System.assertEquals('CEQ-PROJ-001', (String) project.get('project_id'));
        System.assertEquals('My Project Title', (String) project.get('project_title'));
        System.assertEquals('My Project Title', (String) project.get('name'));
        System.assert(project.containsKey('status'));
        System.assert(project.containsKey('lead_agency'));
        System.assert(project.containsKey('last_updated'));
    }

    // ── Multiple processes ─────────────────────────────────────────────────────

    @IsTest
    static void export_multipleProcesses_allIncluded() {
        Program proj = NepaTestFactory.insertProgram('CEQ-MULTI-001', 'Multi Process Test', 'DOE');
        NepaTestFactory.insertOpenProcess(proj.Id, 'EIS');
        NepaTestFactory.insertOpenProcess(proj.Id, 'EA');
        NepaTestFactory.insertOpenProcess(proj.Id, 'CE');

        Map<String, Object> body = callExport(proj.Id);

        System.assertEquals(200, RestContext.response.statusCode);
        Map<String, Object> data    = (Map<String, Object>) body.get('data');
        Map<String, Object> project = (Map<String, Object>) data.get('project');
        List<Object> processes      = (List<Object>) project.get('processes');
        System.assertEquals(3, processes.size());
    }

    // ── Comments nested under documents ──────────────────────────────────────

    @IsTest
    static void export_commentsNestedUnderDocument() {
        Program proj = NepaTestFactory.insertProgram('CEQ-CMT-001', 'Comment Test', 'BLM');
        IndividualApplication ia = NepaTestFactory.insertOpenProcess(proj.Id, 'EIS');
        ContentVersion cv = NepaTestFactory.insertPublicContentVersion(ia.Id, 'Draft EIS');

        // Insert comment linked to document via nepa_parent_document__c
        PublicComplaint pc = new PublicComplaint();
        pc.LastName                  = 'Test Commenter';
        pc.IncidentDate              = Date.today();
        pc.nepa_parent_document__c   = cv.Id;
        pc.nepa_organization__c      = 'Sierra Club';
        pc.nepa_comment_body__c      = 'Test comment body';
        insert pc;

        Map<String, Object> body = callExport(proj.Id);

        System.assertEquals(200, RestContext.response.statusCode);
        Map<String, Object> data    = (Map<String, Object>) body.get('data');
        Map<String, Object> project = (Map<String, Object>) data.get('project');
        List<Object> processes      = (List<Object>) project.get('processes');
        Map<String, Object> process = (Map<String, Object>) processes[0];
        List<Object> docs           = (List<Object>) process.get('documents');
        System.assertEquals(1, docs.size());

        Map<String, Object> doc = (Map<String, Object>) docs[0];
        System.assert(doc.containsKey('comments'), 'Document must have comments key');
        List<Object> comments = (List<Object>) doc.get('comments');
        System.assertEquals(1, comments.size(), 'Document must have 1 nested comment');

        Map<String, Object> comment = (Map<String, Object>) comments[0];
        System.assertEquals(String.valueOf(pc.Id), (String) comment.get('id'));
        System.assertEquals('Sierra Club', (String) comment.get('organization'));
        System.assertEquals(String.valueOf(cv.Id), (String) comment.get('parent_document_id'));
    }

    // ── documents array always present ───────────────────────────────────────

    @IsTest
    static void export_processWithNoDocuments_documentsArrayEmpty() {
        Program proj = NepaTestFactory.insertProgram('CEQ-NODOC-001', 'No Doc Test', 'EPA');
        NepaTestFactory.insertOpenProcess(proj.Id, 'CE');

        Map<String, Object> body = callExport(proj.Id);

        System.assertEquals(200, RestContext.response.statusCode);
        Map<String, Object> data    = (Map<String, Object>) body.get('data');
        Map<String, Object> project = (Map<String, Object>) data.get('project');
        List<Object> processes      = (List<Object>) project.get('processes');
        Map<String, Object> process = (Map<String, Object>) processes[0];

        List<Object> docs = (List<Object>) process.get('documents');
        System.assertNotEquals(null, docs, 'documents must not be null');
        System.assertEquals(0, docs.size(), 'documents must be empty when none exist');

        List<Object> engagements = (List<Object>) process.get('public_engagement_events');
        System.assertNotEquals(null, engagements);
        System.assertEquals(0, engagements.size());

        List<Object> caseEvents = (List<Object>) process.get('case_events');
        System.assertNotEquals(null, caseEvents);
        System.assertEquals(0, caseEvents.size());

        List<Object> permits = (List<Object>) process.get('permits');
        System.assertNotEquals(null, permits);
        System.assertEquals(0, permits.size());
    }

    // ── GIS data ──────────────────────────────────────────────────────────────

    @IsTest
    static void export_gisData_presentAtProjectAndProcessLevel() {
        Program proj = NepaTestFactory.insertProgram('CEQ-GIS-001', 'GIS Test', 'BLM');
        IndividualApplication ia = NepaTestFactory.insertOpenProcess(proj.Id, 'EIS');
        NepaTestFactory.insertGisData(proj.Id, ia.Id);

        Map<String, Object> body = callExport(proj.Id);

        System.assertEquals(200, RestContext.response.statusCode);
        Map<String, Object> data    = (Map<String, Object>) body.get('data');
        Map<String, Object> project = (Map<String, Object>) data.get('project');

        List<Object> projGis = (List<Object>) project.get('gis_data');
        System.assertNotEquals(null, projGis, 'project gis_data must not be null');
        System.assertEquals(1, projGis.size(), 'Expected 1 project-level GIS record');

        List<Object> processes = (List<Object>) project.get('processes');
        Map<String, Object> process = (Map<String, Object>) processes[0];
        List<Object> procGis = (List<Object>) process.get('gis_data');
        System.assertNotEquals(null, procGis, 'process gis_data must not be null');
        System.assertEquals(1, procGis.size(), 'Expected 1 process-level GIS record');
    }

    // ── Permit DTO field names ─────────────────────────────────────────────────

    @IsTest
    static void export_permitFields_mapToCeqNames() {
        Program proj = NepaTestFactory.insertProgram('CEQ-PERMIT-001', 'Permit Field Test', 'USACE');
        IndividualApplication ia = NepaTestFactory.insertOpenProcess(proj.Id, 'EA');
        NepaTestFactory.insertRequiredPermit(ia.Id, 'In Progress', true, Date.today().addDays(60));

        Map<String, Object> body = callExport(proj.Id);

        System.assertEquals(200, RestContext.response.statusCode);
        Map<String, Object> data    = (Map<String, Object>) body.get('data');
        Map<String, Object> project = (Map<String, Object>) data.get('project');
        List<Object> processes      = (List<Object>) project.get('processes');
        Map<String, Object> process = (Map<String, Object>) processes[0];
        List<Object> permits        = (List<Object>) process.get('permits');
        System.assertEquals(1, permits.size());

        Map<String, Object> permit = (Map<String, Object>) permits[0];
        System.assert(permit.containsKey('id'));
        System.assert(permit.containsKey('permit_type'));
        System.assert(permit.containsKey('permit_status'));
        System.assert(permit.containsKey('is_critical_path'));
        System.assert(permit.containsKey('lead_agency'));
        System.assert(permit.containsKey('regulatory_citation'));
        System.assert(permit.containsKey('process_id'));
        System.assert(permit.containsKey('last_updated'));
        System.assertEquals(true, (Boolean) permit.get('is_critical_path'));
    }
}