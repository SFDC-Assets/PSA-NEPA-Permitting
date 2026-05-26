@SuppressWarnings('PMD.ApexAssertionsShouldIncludeMessage,PMD.MethodNamingConventions,PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest
private class NepaGISProximityServiceTest {

    // ── HttpCalloutMocks ──────────────────────────────────────────────────────

    private class HitMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HTTPResponse res = new HTTPResponse();
            res.setStatusCode(200);
            res.setBody('{"features":[{"attributes":{"GEN_STAT":"Designated Critical Habitat","COMNAME":"Pygmy Rabbit"}}],"exceededTransferLimit":false}');
            return res;
        }
    }

    private class NoHitMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HTTPResponse res = new HTTPResponse();
            res.setStatusCode(200);
            res.setBody('{"features":[],"exceededTransferLimit":false}');
            return res;
        }
    }

    private class ErrorMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HTTPResponse res = new HTTPResponse();
            res.setStatusCode(500);
            res.setBody('{"error":{"code":500,"message":"Service unavailable"}}');
            return res;
        }
    }

    private class MultiFeatureMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HTTPResponse res = new HTTPResponse();
            res.setStatusCode(200);
            res.setBody('{"features":['
                + '{"attributes":{"GEN_STAT":"Designated Critical Habitat"}},'
                + '{"attributes":{"GEN_STAT":"Proposed Critical Habitat"}},'
                + '{"attributes":{"GEN_STAT":"Experimental Population"}}'
                + ']}');
            return res;
        }
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    private static Program insertProjectWithCoords(String pid, Decimal lat, Decimal lon) {
        Program proj = NepaTestFactory.insertProgram(pid, 'GIS Test ' + pid, 'BLM');
        proj.nepa_location_lat__c = lat;
        proj.nepa_location_lon__c = lon;
        update proj;
        return proj;
    }

    private static NepaGISProximityService.Result invokeOne(String projectId) {
        NepaGISProximityService.Request req = new NepaGISProximityService.Request();
        req.projectId = projectId;
        List<NepaGISProximityService.Result> results =
            NepaGISProximityService.invoke(new List<NepaGISProximityService.Request>{ req });
        System.assertEquals(1, results.size(), 'Must return one result');
        System.assertNotEquals(null, results[0], 'Result must not be null');
        return results[0];
    }

    // ── @InvocableMethod contract ─────────────────────────────────────────────

    @IsTest
    static void invoke_emptyList_returnsEmptyResults() {
        Test.startTest();
        List<NepaGISProximityService.Result> results =
            NepaGISProximityService.invoke(new List<NepaGISProximityService.Request>());
        Test.stopTest();

        System.assertEquals(0, results.size());
    }

    @IsTest
    static void invoke_nullProjectId_returnsFailedResult() {
        NepaGISProximityService.Request req = new NepaGISProximityService.Request();
        req.projectId = null;

        Test.startTest();
        List<NepaGISProximityService.Result> results =
            NepaGISProximityService.invoke(new List<NepaGISProximityService.Request>{ req });
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals(false, results[0].success);
        System.assertNotEquals(null, results[0].errorMessage);
    }

    @IsTest
    static void invoke_validProjectId_enqueuedSuccessfully() {
        Program proj = NepaTestFactory.insertProgram('GIS-INV-001', 'Invoke Test', 'BLM');
        Test.setMock(HttpCalloutMock.class, new HitMock());

        Test.startTest();
        NepaGISProximityService.Result result = invokeOne(proj.Id);
        Test.stopTest();

        System.assertEquals(true, result.success);
        System.assertEquals(null, result.errorMessage);
    }

    @IsTest
    static void invoke_bulkTwoRequests_returnsTwoResults() {
        Program p1 = NepaTestFactory.insertProgram('GIS-BULK-001', 'Bulk GIS 1', 'BLM');
        Program p2 = NepaTestFactory.insertProgram('GIS-BULK-002', 'Bulk GIS 2', 'FWS');
        NepaGISProximityService.Request r1 = new NepaGISProximityService.Request();
        r1.projectId = p1.Id;
        NepaGISProximityService.Request r2 = new NepaGISProximityService.Request();
        r2.projectId = p2.Id;
        Test.setMock(HttpCalloutMock.class, new HitMock());

        Test.startTest();
        List<NepaGISProximityService.Result> results =
            NepaGISProximityService.invoke(new List<NepaGISProximityService.Request>{ r1, r2 });
        Test.stopTest();

        System.assertEquals(2, results.size());
        for (NepaGISProximityService.Result r : results) {
            System.assertNotEquals(null, r);
        }
    }

    // ── Queueable integration ─────────────────────────────────────────────────

    @IsTest
    static void queueable_hitMock_writesGisRecord() {
        Program proj = insertProjectWithCoords('GIS-Q-HIT-001', 43.4917, -111.8833);
        Test.setMock(HttpCalloutMock.class, new HitMock());

        Test.startTest();
        System.enqueueJob(new NepaGISProximityService.GISProximityQueueable(proj.Id));
        Test.stopTest();

        List<nepa_gis_data__c> recs = [
            SELECT Id, nepa_parent_project__c, nepa_description__c
            FROM nepa_gis_data__c
            WHERE nepa_parent_project__c = :proj.Id
        ];
        System.assert(recs.size() >= 1, 'At least one gis_data record must be written on a hit');
    }

    @IsTest
    static void queueable_hitMock_stampsProtectionAreas() {
        Program proj = insertProjectWithCoords('GIS-Q-PROT-001', 43.4917, -111.8833);
        Test.setMock(HttpCalloutMock.class, new HitMock());

        Test.startTest();
        System.enqueueJob(new NepaGISProximityService.GISProximityQueueable(proj.Id));
        Test.stopTest();

        Program result = [SELECT nepa_protection_areas__c, nepa_gis_proximity_complete__c FROM Program WHERE Id = :proj.Id];
        System.assertNotEquals(null, result.nepa_protection_areas__c, 'protection_areas must be populated on hit');
        System.assertEquals(true, result.nepa_gis_proximity_complete__c);
    }

    @IsTest
    static void queueable_ecKeywordHit_setsExtraordinaryCircumstances() {
        Program proj = insertProjectWithCoords('GIS-Q-EC-001', 43.4917, -111.8833);
        // HitMock returns "Designated Critical Habitat" — FWS_Critical_Habitat CMT has
        // Extraordinary_Circumstances_Keyword__c = 'CRITICAL HABITAT,DESIGNATED,PROPOSED'
        Test.setMock(HttpCalloutMock.class, new HitMock());

        Test.startTest();
        System.enqueueJob(new NepaGISProximityService.GISProximityQueueable(proj.Id));
        Test.stopTest();

        Program result = [SELECT nepa_extraordinary_circumstances__c FROM Program WHERE Id = :proj.Id];
        System.assertEquals(true, result.nepa_extraordinary_circumstances__c,
            'Extraordinary circumstances must be set when EC keyword is found');
    }

    @IsTest
    static void queueable_noHitMock_noGisRecordsWritten() {
        Program proj = insertProjectWithCoords('GIS-Q-NOHIT-001', 39.7392, -104.9903);
        Test.setMock(HttpCalloutMock.class, new NoHitMock());

        Test.startTest();
        System.enqueueJob(new NepaGISProximityService.GISProximityQueueable(proj.Id));
        Test.stopTest();

        List<nepa_gis_data__c> recs = [
            SELECT Id FROM nepa_gis_data__c WHERE nepa_parent_project__c = :proj.Id
        ];
        System.assertEquals(0, recs.size(), 'No gis_data records should be written when no features returned');

        Program result = [SELECT nepa_extraordinary_circumstances__c, nepa_gis_proximity_complete__c FROM Program WHERE Id = :proj.Id];
        System.assertEquals(false, result.nepa_extraordinary_circumstances__c);
        System.assertEquals(true, result.nepa_gis_proximity_complete__c, 'gis_proximity_complete must be true even on no-hit run');
    }

    @IsTest
    static void queueable_errorMock_doesNotThrow() {
        Program proj = insertProjectWithCoords('GIS-Q-ERR-001', 37.7749, -122.4194);
        Test.setMock(HttpCalloutMock.class, new ErrorMock());

        Test.startTest();
        System.enqueueJob(new NepaGISProximityService.GISProximityQueueable(proj.Id));
        Test.stopTest();

        // HTTP 500 must be swallowed gracefully — no unhandled exception.
        // GIS complete flag may or may not be set depending on whether any layers succeeded.
        List<nepa_gis_data__c> recs = [SELECT Id FROM nepa_gis_data__c WHERE nepa_parent_project__c = :proj.Id];
        System.assertEquals(0, recs.size(), 'Error responses must not produce gis_data records');
    }

    @IsTest
    static void queueable_missingCoordinates_doesNotThrow() {
        Program proj = NepaTestFactory.insertProgram('GIS-Q-NOCRD-001', 'No Coord', 'BLM');
        Test.setMock(HttpCalloutMock.class, new HitMock());

        Test.startTest();
        System.enqueueJob(new NepaGISProximityService.GISProximityQueueable(proj.Id));
        Test.stopTest();

        List<nepa_gis_data__c> recs = [SELECT Id FROM nepa_gis_data__c WHERE nepa_parent_project__c = :proj.Id];
        System.assertEquals(0, recs.size(), 'Missing coordinates must produce no gis_data records');
    }

    @IsTest
    static void queueable_unknownProjectId_doesNotThrow() {
        Test.setMock(HttpCalloutMock.class, new HitMock());

        Test.startTest();
        System.enqueueJob(new NepaGISProximityService.GISProximityQueueable('001000000000001AAA'));
        Test.stopTest();
        // No assertion needed — test passes if no unhandled exception.
    }

    @IsTest
    static void queueable_stampsGisLastChecked() {
        Program proj = insertProjectWithCoords('GIS-Q-TS-001', 43.4917, -111.8833);
        Test.setMock(HttpCalloutMock.class, new HitMock());

        Test.startTest();
        System.enqueueJob(new NepaGISProximityService.GISProximityQueueable(proj.Id));
        Test.stopTest();

        Program result = [SELECT nepa_gis_last_checked__c FROM Program WHERE Id = :proj.Id];
        System.assertNotEquals(null, result.nepa_gis_last_checked__c, 'gis_last_checked must be set after a run');
    }

    // ── Unit: URL builder ─────────────────────────────────────────────────────

    @IsTest
    static void buildFullUrl_arcgisLayer_includesGeometryParams() {
        NEPA_GIS_Layer__mdt layer = new NEPA_GIS_Layer__mdt(
            Service_URL__c  = 'https://services.arcgis.com/QVENGdaPbd4LUkLV/ArcGIS/rest/services/USFWS_Critical_Habitat/FeatureServer',
            Layer_Number__c = 0,
            Buffer_Miles__c = 1.0,
            Query_Template__c = null
        );

        String url = NepaGISProximityService.buildFullUrl(layer, 43.4917, -111.8833);

        System.assert(url.contains('geometry='), 'URL must contain geometry param');
        System.assert(url.contains('geometryType=esriGeometryPoint'), 'URL must specify point geometry');
        System.assert(url.contains('f=json'), 'URL must request JSON format');
        System.assert(url.contains('distance='), 'URL must contain distance param');
    }

    @IsTest
    static void buildFullUrl_queryTemplate_substitutesLatLon() {
        NEPA_GIS_Layer__mdt layer = new NEPA_GIS_Layer__mdt(
            Query_Template__c = 'https://api.example.gov/query?lat={lat}&lon={lon}&radius=1',
            Service_URL__c    = null,
            Layer_Number__c   = null,
            Buffer_Miles__c   = null
        );

        String url = NepaGISProximityService.buildFullUrl(layer, 43.4917, -111.8833);

        System.assert(url.contains('43.4917'), 'Latitude must be substituted');
        System.assert(url.contains('-111.8833'), 'Longitude must be substituted');
        System.assert(!url.contains('{lat}'), '{lat} placeholder must be replaced');
        System.assert(!url.contains('{lon}'), '{lon} placeholder must be replaced');
    }

    @IsTest
    static void buildFullUrl_nullServiceUrl_returnsNull() {
        NEPA_GIS_Layer__mdt layer = new NEPA_GIS_Layer__mdt(
            Service_URL__c    = null,
            Query_Template__c = null,
            Layer_Number__c   = 0,
            Buffer_Miles__c   = 1.0
        );

        String url = NepaGISProximityService.buildFullUrl(layer, 43.4917, -111.8833);
        System.assertEquals(null, url);
    }

    @IsTest
    static void extractBase_standardHttpsUrl_returnsHostOnly() {
        System.assertEquals('https://services.arcgis.com',
            NepaGISProximityService.extractBase('https://services.arcgis.com/path/to/service'));
    }

    // ── Unit: feature parsing ─────────────────────────────────────────────────

    @IsTest
    static void parseFeatures_validBody_returnsFeatures() {
        String body = '{"features":[{"attributes":{"GEN_STAT":"Designated"}},{"attributes":{"GEN_STAT":"Proposed"}}]}';
        List<Map<String, Object>> features = NepaGISProximityService.parseFeatures(body);
        System.assertEquals(2, features.size());
    }

    @IsTest
    static void parseFeatures_emptyFeatures_returnsEmptyList() {
        String body = '{"features":[]}';
        List<Map<String, Object>> features = NepaGISProximityService.parseFeatures(body);
        System.assertEquals(0, features.size());
    }

    @IsTest
    static void parseFeatures_malformedJson_returnsEmptyList() {
        List<Map<String, Object>> features = NepaGISProximityService.parseFeatures('not json at all');
        System.assertEquals(0, features.size());
    }

    @IsTest
    static void parseFeatures_noFeaturesKey_returnsEmptyList() {
        List<Map<String, Object>> features = NepaGISProximityService.parseFeatures('{"other":"value"}');
        System.assertEquals(0, features.size());
    }

    @IsTest
    static void extractSummary_multipleFeatures_deduplicatesValues() {
        List<Map<String, Object>> features = new List<Map<String, Object>>{
            new Map<String, Object>{'attributes' => new Map<String, Object>{'GEN_STAT' => 'Designated'}},
            new Map<String, Object>{'attributes' => new Map<String, Object>{'GEN_STAT' => 'Designated'}},
            new Map<String, Object>{'attributes' => new Map<String, Object>{'GEN_STAT' => 'Proposed'}}
        };
        String summary = NepaGISProximityService.extractSummary(features, 'GEN_STAT');
        System.assert(!summary.contains('Designated; Designated'), 'Duplicate values must be deduplicated');
    }

    @IsTest
    static void extractSummary_noKeyField_returnsFeatureCount() {
        List<Map<String, Object>> features = new List<Map<String, Object>>{
            new Map<String, Object>{'attributes' => new Map<String, Object>{'FIELD' => 'val'}}
        };
        String summary = NepaGISProximityService.extractSummary(features, null);
        System.assert(summary.contains('1'), 'Summary must include feature count when no key field');
    }

    // ── Unit: EC keyword matching ─────────────────────────────────────────────

    @IsTest
    static void hasEcKeyword_matchingKeyword_returnsTrue() {
        System.assertEquals(true,
            NepaGISProximityService.hasEcKeyword('Designated Critical Habitat', 'CRITICAL HABITAT,WETLANDS'));
    }

    @IsTest
    static void hasEcKeyword_noMatch_returnsFalse() {
        System.assertEquals(false,
            NepaGISProximityService.hasEcKeyword('Experimental Population', 'WETLANDS,FLOODPLAIN'));
    }

    @IsTest
    static void hasEcKeyword_nullKeywords_returnsFalse() {
        System.assertEquals(false,
            NepaGISProximityService.hasEcKeyword('Wetlands found', null));
    }

    @IsTest
    static void hasEcKeyword_nullSummary_returnsFalse() {
        System.assertEquals(false,
            NepaGISProximityService.hasEcKeyword(null, 'WETLANDS'));
    }

    @IsTest
    static void hasEcKeyword_caseInsensitive_returnsTrue() {
        System.assertEquals(true,
            NepaGISProximityService.hasEcKeyword('wetlands found nearby', 'WETLANDS'));
    }

    // ── CMT integrity (carried over from NepaGISProximityCheckTest) ───────────

    @IsTest
    static void gisLayerCmt_hasActiveRecords() {
        List<NEPA_GIS_Layer__mdt> layers = [
            SELECT Label FROM NEPA_GIS_Layer__mdt WHERE Active__c = true
        ];
        System.assert(layers.size() >= 1, 'At least one active NEPA_GIS_Layer__mdt record must exist');
    }

    @IsTest
    static void gisLayerCmt_allActiveLayersHaveRequiredFields() {
        List<NEPA_GIS_Layer__mdt> layers = [
            SELECT DeveloperName, Buffer_Miles__c, Layer_Label__c, Named_Credential__c
            FROM NEPA_GIS_Layer__mdt WHERE Active__c = true
        ];
        for (NEPA_GIS_Layer__mdt l : layers) {
            System.assertNotEquals(null, l.Buffer_Miles__c, l.DeveloperName + ': Buffer_Miles__c must not be null');
            System.assert(String.isNotBlank(l.Layer_Label__c), l.DeveloperName + ': Layer_Label__c must not be blank');
            System.assert(String.isNotBlank(l.Named_Credential__c), l.DeveloperName + ': Named_Credential__c must not be blank');
        }
    }

    @IsTest
    static void gisLayerCmt_fwsCriticalHabitatExists() {
        List<NEPA_GIS_Layer__mdt> layers = [
            SELECT DeveloperName, Active__c, Extraordinary_Circumstances_Keyword__c
            FROM NEPA_GIS_Layer__mdt WHERE DeveloperName = 'FWS_Critical_Habitat'
        ];
        System.assertEquals(1, layers.size(), 'FWS_Critical_Habitat CMT record must exist');
        System.assertEquals(true, layers[0].Active__c, 'FWS_Critical_Habitat must be active');
        System.assert(String.isNotBlank(layers[0].Extraordinary_Circumstances_Keyword__c),
            'FWS_Critical_Habitat must have EC keywords set');
    }

    @IsTest
    static void gisLayerCmt_bufferDistancesAreNonNegative() {
        // Buffer_Miles__c = 0 is valid for point-in-polygon containment layers (e.g. EPA Air Nonattainment)
        // where proximity radius is irrelevant and the query tests whether the point falls inside the polygon.
        List<NEPA_GIS_Layer__mdt> layers = [
            SELECT DeveloperName, Buffer_Miles__c FROM NEPA_GIS_Layer__mdt WHERE Active__c = true
        ];
        for (NEPA_GIS_Layer__mdt l : layers) {
            System.assert(l.Buffer_Miles__c >= 0, l.DeveloperName + ': Buffer_Miles__c must be >= 0; got: ' + l.Buffer_Miles__c);
        }
    }
}
