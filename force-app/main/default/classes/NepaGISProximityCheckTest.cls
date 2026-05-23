@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs,PMD.CyclomaticComplexity,PMD.ApexDoc')
@IsTest
private class NepaGISProximityCheckTest {

    // ── HttpCalloutMock implementations ──────────────────────────────────────

    private class GisHitMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HTTPResponse res = new HTTPResponse();
            res.setStatusCode(200);
            res.setBody('{' +
                '"features":[{' +
                    '"attributes":{"GEN_STAT":"Designated Critical Habitat","COMNAME":"Pygmy Rabbit"}' +
                '}],' +
                '"exceededTransferLimit":false' +
            '}');
            return res;
        }
    }

    private class GisNoHitMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HTTPResponse res = new HTTPResponse();
            res.setStatusCode(200);
            res.setBody('{"features":[],"exceededTransferLimit":false}');
            return res;
        }
    }

    private class GisEndpointDownMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HTTPResponse res = new HTTPResponse();
            res.setStatusCode(500);
            res.setBody('{"error":{"code":500,"message":"Service unavailable"}}');
            return res;
        }
    }

    private class GisMultiFeatureMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HTTPResponse res = new HTTPResponse();
            res.setStatusCode(200);
            res.setBody('{' +
                '"features":[' +
                    '{"attributes":{"GEN_STAT":"Designated Critical Habitat"}},' +
                    '{"attributes":{"GEN_STAT":"Proposed Critical Habitat"}},' +
                    '{"attributes":{"GEN_STAT":"Experimental Population"}}' +
                ']' +
            '}');
            return res;
        }
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    private static Program insertProjectWithCoordinates(
        String projectId, Decimal lat, Decimal lon
    ) {
        Program proj = NepaTestFactory.insertProgram(projectId, 'GIS Test Project ' + projectId, 'BLM');
        proj.nepa_location_lat__c = lat;
        proj.nepa_location_lon__c = lon;
        update proj;
        return proj;
    }

    private static Program insertProjectWithoutCoordinates(String projectId) {
        return NepaTestFactory.insertProgram(projectId, 'GIS No Coord ' + projectId, 'BLM');
    }

    /**
     * Invokes the IP and returns the first result, failing the test if the invoker
     * itself throws. OmniStudio IPs do not run in Apex test context — if the IP
     * service is unavailable the invoker returns success=false with an errorMessage.
     * A thrown exception means the Apex invoker bridge is broken, which is a real failure.
     */
    private static NepaGISProximityIPInvoker.InvokerResult invokeAndRequireResult(String projectId) {
        NepaGISProximityIPInvoker.InvokerRequest req = new NepaGISProximityIPInvoker.InvokerRequest();
        req.projectId = projectId;
        List<NepaGISProximityIPInvoker.InvokerResult> results =
            NepaGISProximityIPInvoker.invoke(
                new List<NepaGISProximityIPInvoker.InvokerRequest>{ req }
            );
        System.assertEquals(1, results.size(), 'Invoker must return exactly one result per request');
        System.assertNotEquals(null, results[0], 'Invoker result must never be null');
        return results[0];
    }

    // ── Invoker contract ──────────────────────────────────────────────────────

    @IsTest
    static void invoker_validProjectId_returnsOneResult() {
        Program proj = NepaTestFactory.insertProgram('GIS-INV-001', 'Invoker Test', 'BLM');

        Test.startTest();
        NepaGISProximityIPInvoker.InvokerResult result = invokeAndRequireResult(proj.Id);
        Test.stopTest();

        // success=false is acceptable when IP service is unavailable in sandbox,
        // but the result object itself must be present and errorMessage must be set
        // on any failure path — a null errorMessage on a failed result is a bug.
        if (!result.success) {
            System.assertNotEquals(null, result.errorMessage,
                'Failed InvokerResult must carry an errorMessage, not null');
        }
    }

    @IsTest
    static void invoker_emptyList_returnsEmptyResults() {
        Test.startTest();
        List<NepaGISProximityIPInvoker.InvokerResult> results =
            NepaGISProximityIPInvoker.invoke(
                new List<NepaGISProximityIPInvoker.InvokerRequest>()
            );
        Test.stopTest();

        System.assertEquals(0, results.size(), 'Empty input list must produce empty result list');
    }

    @IsTest
    static void invoker_nullProjectId_setsErrorMessage() {
        NepaGISProximityIPInvoker.InvokerRequest req = new NepaGISProximityIPInvoker.InvokerRequest();
        req.projectId = null;

        Test.startTest();
        List<NepaGISProximityIPInvoker.InvokerResult> results =
            NepaGISProximityIPInvoker.invoke(
                new List<NepaGISProximityIPInvoker.InvokerRequest>{ req }
            );
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Must return one result for one request');
        System.assertNotEquals(null, results[0], 'Result must not be null');
        // Null projectId must either succeed (IP skips gracefully) or fail with a message.
        // What it must NOT do is return success=false with a null errorMessage.
        if (results[0].success == false) {
            System.assertNotEquals(null, results[0].errorMessage,
                'Null projectId fault path must populate errorMessage');
        }
    }

    @IsTest
    static void invoker_bulkTwoRequests_returnsTwoResults() {
        Program p1 = NepaTestFactory.insertProgram('GIS-BULK-001', 'Bulk GIS 1', 'BLM');
        Program p2 = NepaTestFactory.insertProgram('GIS-BULK-002', 'Bulk GIS 2', 'FWS');
        NepaGISProximityIPInvoker.InvokerRequest r1 = new NepaGISProximityIPInvoker.InvokerRequest();
        r1.projectId = p1.Id;
        NepaGISProximityIPInvoker.InvokerRequest r2 = new NepaGISProximityIPInvoker.InvokerRequest();
        r2.projectId = p2.Id;

        Test.startTest();
        List<NepaGISProximityIPInvoker.InvokerResult> results =
            NepaGISProximityIPInvoker.invoke(
                new List<NepaGISProximityIPInvoker.InvokerRequest>{ r1, r2 }
            );
        Test.stopTest();

        System.assertEquals(2, results.size(), 'Two requests must produce exactly two results');
        for (NepaGISProximityIPInvoker.InvokerResult r : results) {
            System.assertNotEquals(null, r, 'Each result must be non-null');
            if (!r.success) {
                System.assertNotEquals(null, r.errorMessage,
                    'Failed bulk result must carry an errorMessage');
            }
        }
    }

    // ── GIS callout response: hit vs. no-hit ─────────────────────────────────

    @IsTest
    static void gisHit_invokerReturnsWithoutUnhandledException() {
        // Verifies the full invoker path does not throw when a GIS hit mock is set.
        // OmniStudio IPs do not execute in Apex test context, so we cannot assert
        // on field values written by the IP here — that requires an integration test.
        // What we CAN assert: the invoker boundary does not propagate an unhandled exception.
        Program proj = insertProjectWithCoordinates('GIS-HIT-001', 43.4917, -111.8833);
        Test.setMock(HttpCalloutMock.class, new GisHitMock());

        Test.startTest();
        NepaGISProximityIPInvoker.InvokerResult result = invokeAndRequireResult(proj.Id);
        Test.stopTest();

        if (!result.success) {
            System.assertNotEquals(null, result.errorMessage,
                'Failed result from hit path must carry errorMessage');
        }
    }

    @IsTest
    static void gisNoHit_invokerReturnsWithoutUnhandledException() {
        Program proj = insertProjectWithCoordinates('GIS-NOHIT-001', 39.7392, -104.9903);
        Test.setMock(HttpCalloutMock.class, new GisNoHitMock());

        Test.startTest();
        NepaGISProximityIPInvoker.InvokerResult result = invokeAndRequireResult(proj.Id);
        Test.stopTest();

        if (!result.success) {
            System.assertNotEquals(null, result.errorMessage,
                'Failed result from no-hit path must carry errorMessage');
        }
    }

    @IsTest
    static void gisEndpointDown_doesNotPropagateUnhandledException() {
        Program proj = insertProjectWithCoordinates('GIS-DOWN-001', 37.7749, -122.4194);
        Test.setMock(HttpCalloutMock.class, new GisEndpointDownMock());

        Test.startTest();
        NepaGISProximityIPInvoker.InvokerResult result = invokeAndRequireResult(proj.Id);
        Test.stopTest();

        // HTTP 500 must not surface as an unhandled exception from the invoker.
        // The invoker's catch block must populate errorMessage on the failure path.
        if (!result.success) {
            System.assertNotEquals(null, result.errorMessage,
                'Endpoint-down fault must be captured in errorMessage, not swallowed silently');
        }
    }

    // ── Flow trigger ──────────────────────────────────────────────────────────

    @IsTest
    static void flow_coordinatesSet_dmlSucceedsAndFieldsPersist() {
        Program proj = NepaTestFactory.insertProgram('GIS-FLOW-001', 'Flow Trigger Test', 'BLM');
        Test.setMock(HttpCalloutMock.class, new GisHitMock());

        Test.startTest();
        proj.nepa_location_lat__c = 44.0582;
        proj.nepa_location_lon__c = -121.3153;
        update proj;
        Test.stopTest();

        Program result = [
            SELECT nepa_location_lat__c, nepa_location_lon__c
            FROM Program WHERE Id = :proj.Id
        ];
        System.assertEquals(44.0582, result.nepa_location_lat__c,
            'Latitude must be persisted after update');
        System.assertEquals(-121.3153, result.nepa_location_lon__c,
            'Longitude must be persisted after update');
    }

    @IsTest
    static void flow_onlyLatSet_doesNotThrow() {
        Program proj = NepaTestFactory.insertProgram('GIS-LATONLY-001', 'Lat Only', 'BLM');
        Test.setMock(HttpCalloutMock.class, new GisHitMock());

        Test.startTest();
        proj.nepa_location_lat__c = 44.0582;
        update proj;
        Test.stopTest();

        Program result = [SELECT nepa_location_lat__c FROM Program WHERE Id = :proj.Id];
        System.assertEquals(44.0582, result.nepa_location_lat__c,
            'Latitude must be persisted even when longitude is absent');
    }

    @IsTest
    static void flow_noCoordinates_doesNotThrow() {
        Program proj = insertProjectWithoutCoordinates('GIS-NOCOORD-001');

        Test.startTest();
        proj.nepa_project_title__c = 'Updated title — no coordinates';
        update proj;
        Test.stopTest();

        Program result = [SELECT nepa_project_title__c FROM Program WHERE Id = :proj.Id];
        System.assertEquals('Updated title — no coordinates', result.nepa_project_title__c,
            'Non-coordinate update must persist without error');
    }

    // ── Extraordinary circumstances ───────────────────────────────────────────

    @IsTest
    static void extraordinaryCircumstances_invokerDoesNotThrowOnHit() {
        Program proj = insertProjectWithCoordinates('GIS-EC-001', 43.4917, -111.8833);
        Test.setMock(HttpCalloutMock.class, new GisHitMock());

        Test.startTest();
        NepaGISProximityIPInvoker.InvokerResult result = invokeAndRequireResult(proj.Id);
        Test.stopTest();

        // IP does not execute in Apex test context; assert invoker boundary only.
        if (!result.success) {
            System.assertNotEquals(null, result.errorMessage,
                'EC hit path fault must populate errorMessage');
        }
    }

    @IsTest
    static void extraordinaryCircumstances_invokerDoesNotThrowOnNoHit() {
        Program proj = insertProjectWithCoordinates('GIS-NOEC-001', 39.7392, -104.9903);
        Test.setMock(HttpCalloutMock.class, new GisNoHitMock());

        Test.startTest();
        NepaGISProximityIPInvoker.InvokerResult result = invokeAndRequireResult(proj.Id);
        Test.stopTest();

        if (!result.success) {
            System.assertNotEquals(null, result.errorMessage,
                'EC no-hit path fault must populate errorMessage');
        }
    }

    // ── Detected protection layer records ─────────────────────────────────────

    @IsTest
    static void detectedLayerRecords_invokerCompletesWithoutThrowingOnHit() {
        Program proj = insertProjectWithCoordinates('GIS-DPL-001', 43.4917, -111.8833);
        Test.setMock(HttpCalloutMock.class, new GisHitMock());

        Test.startTest();
        NepaGISProximityIPInvoker.InvokerResult result = invokeAndRequireResult(proj.Id);
        Test.stopTest();

        // IP does not execute in Apex test context — nepa_detected_protection_layer__c
        // records are written by OmniStudio at runtime. Verify invoker boundary only.
        if (!result.success) {
            System.assertNotEquals(null, result.errorMessage,
                'Detected-layer path fault must populate errorMessage');
        }
    }

    @IsTest
    static void detectedLayerRecords_idempotentRerun_doesNotThrow() {
        Program proj = insertProjectWithCoordinates('GIS-IDEM-001', 43.4917, -111.8833);
        Test.setMock(HttpCalloutMock.class, new GisHitMock());

        NepaGISProximityIPInvoker.InvokerRequest req = new NepaGISProximityIPInvoker.InvokerRequest();
        req.projectId = proj.Id;
        List<NepaGISProximityIPInvoker.InvokerRequest> reqs =
            new List<NepaGISProximityIPInvoker.InvokerRequest>{ req };

        Test.startTest();
        List<NepaGISProximityIPInvoker.InvokerResult> r1 = NepaGISProximityIPInvoker.invoke(reqs);
        List<NepaGISProximityIPInvoker.InvokerResult> r2 = NepaGISProximityIPInvoker.invoke(reqs);
        Test.stopTest();

        System.assertEquals(1, r1.size(), 'First run must return one result');
        System.assertEquals(1, r2.size(), 'Second run must return one result');
        System.assertNotEquals(null, r1[0], 'First result must not be null');
        System.assertNotEquals(null, r2[0], 'Second result must not be null');
    }

    // ── Null coordinates via invoker (IP guard path) ─────────────────────────

    @IsTest
    static void nullCoordinates_viaInvoker_guardPathDoesNotThrow() {
        // The IP's GuardCoordinates ConditionalBlock → Stop path is exercised when
        // the project has no lat/lon. The invoker must not propagate an exception;
        // it must return success=false with a populated errorMessage, or success=true
        // if the IP exits cleanly via the Stop element.
        Program proj = insertProjectWithoutCoordinates('GIS-NULLCOORD-INVOKER-001');

        Test.startTest();
        NepaGISProximityIPInvoker.InvokerResult result = invokeAndRequireResult(proj.Id);
        Test.stopTest();

        if (!result.success) {
            System.assertNotEquals(null, result.errorMessage,
                'Null-coordinates guard path must populate errorMessage, not swallow silently');
        }
    }

    @IsTest
    static void onlyLongitudeSet_viaInvoker_doesNotThrow() {
        Program proj = NepaTestFactory.insertProgram('GIS-LONONLY-001', 'Lon Only', 'BLM');
        proj.nepa_location_lon__c = -111.8833;
        update proj;

        Test.startTest();
        NepaGISProximityIPInvoker.InvokerResult result = invokeAndRequireResult(proj.Id);
        Test.stopTest();

        if (!result.success) {
            System.assertNotEquals(null, result.errorMessage,
                'Partial-coordinate fault path must populate errorMessage');
        }
    }

    // ── GIS layer CMT integrity ───────────────────────────────────────────────

    @IsTest
    static void gisLayerCmt_hasActiveRecords() {
        List<NEPA_GIS_Layer__mdt> layers = [
            SELECT Label, DeveloperName, Active__c
            FROM NEPA_GIS_Layer__mdt WHERE Active__c = true
        ];
        System.assert(layers.size() >= 1,
            'At least one active NEPA_GIS_Layer__mdt record must exist for the proximity check to function');
    }

    @IsTest
    static void gisLayerCmt_allActiveLayersHaveRequiredFields() {
        List<NEPA_GIS_Layer__mdt> layers = [
            SELECT DeveloperName, Label, Active__c,
                   Buffer_Miles__c, Layer_Label__c, Named_Credential__c
            FROM NEPA_GIS_Layer__mdt WHERE Active__c = true
        ];
        System.assert(!layers.isEmpty(), 'Active GIS layer CMT records must exist');
        for (NEPA_GIS_Layer__mdt l : layers) {
            System.assertNotEquals(null, l.Buffer_Miles__c,
                l.DeveloperName + ': Buffer_Miles__c must not be null');
            System.assert(String.isNotBlank(l.Layer_Label__c),
                l.DeveloperName + ': Layer_Label__c must not be blank');
            System.assert(String.isNotBlank(l.Named_Credential__c),
                l.DeveloperName + ': Named_Credential__c must not be blank');
        }
    }

    @IsTest
    static void gisLayerCmt_extraordinaryCircumstancesKeywordsExistOnSomeLayers() {
        List<NEPA_GIS_Layer__mdt> ecLayers = [
            SELECT DeveloperName, Extraordinary_Circumstances_Keyword__c
            FROM NEPA_GIS_Layer__mdt
            WHERE Active__c = true AND Extraordinary_Circumstances_Keyword__c != null
        ];
        System.assert(ecLayers.size() >= 1,
            'At least one active GIS layer must have Extraordinary_Circumstances_Keyword__c set');
    }

    @IsTest
    static void gisLayerCmt_fwsCriticalHabitatLayerExists() {
        List<NEPA_GIS_Layer__mdt> fwsLayers = [
            SELECT DeveloperName, Layer_Label__c, Active__c,
                   Extraordinary_Circumstances_Keyword__c, Buffer_Miles__c
            FROM NEPA_GIS_Layer__mdt
            WHERE DeveloperName = 'FWS_Critical_Habitat'
        ];
        System.assertEquals(1, fwsLayers.size(),
            'FWS_Critical_Habitat CMT record must exist');
        System.assertEquals(true, fwsLayers[0].Active__c,
            'FWS_Critical_Habitat CMT record must be active');
        System.assert(String.isNotBlank(fwsLayers[0].Extraordinary_Circumstances_Keyword__c),
            'FWS_Critical_Habitat must have Extraordinary_Circumstances_Keyword__c set');
    }

    @IsTest
    static void gisLayerCmt_bufferDistancesArePositive() {
        List<NEPA_GIS_Layer__mdt> layers = [
            SELECT DeveloperName, Buffer_Miles__c
            FROM NEPA_GIS_Layer__mdt WHERE Active__c = true
        ];
        for (NEPA_GIS_Layer__mdt l : layers) {
            System.assert(l.Buffer_Miles__c > 0,
                l.DeveloperName + ': Buffer_Miles__c must be > 0; got: ' + l.Buffer_Miles__c);
        }
    }

    // ── DR activation guard ───────────────────────────────────────────────────

    @IsTest
    static void drExtractNEPAProject_isActive() {
        // DRExtractNEPAProject must be active or the GISProximityIP GetProjectLocation
        // step returns nothing, silently leaving Latitude/Longitude null and causing
        // every ArcGIS query to fire with a null geometry payload.
        // This test catches a regression where the DR was inadvertently deactivated.
        List<OmniDataTransform> drs = [
            SELECT Id, Name, IsActive
            FROM OmniDataTransform
            WHERE UniqueName = 'DRExtractNEPAProject_1'
            LIMIT 1
        ];
        if (drs.isEmpty()) {
            // DR not yet deployed to this org — skip rather than false-fail
            return;
        }
        System.assertEquals(true, drs[0].IsActive,
            'DRExtractNEPAProject must be active — if inactive the GIS proximity check ' +
            'silently fires with null coordinates and returns no results');
    }
}
