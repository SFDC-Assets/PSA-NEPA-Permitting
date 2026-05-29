/*
 * Copyright (c) 2026, salesforce.com, inc.
 * All rights reserved.
 * Licensed under the BSD 3-Clause license.
 */
@IsTest
private class NepaMapCreateCtrTest {

    @IsTest
    static void testFetchVFDomainURL() {
        Test.startTest();
        String domain = NepaMapCreateCtr.fetchVFDomainURL();
        Test.stopTest();
        System.assertNotEquals(null, domain, 'VF domain should not be null');
        System.assert(domain.startsWith('https://'), 'VF domain should start with https://');
    }

    @IsTest
    static void testFetchCommunityURL() {
        Test.startTest();
        String url = NepaMapCreateCtr.fetchCommunityURL();
        Test.stopTest();
        // In test context with no configured site, returns empty string or valid URL — both acceptable
        System.assertNotEquals(null, url, 'Community URL should not be null');
    }

    @IsTest
    static void testDefaultAddressCoordinates() {
        Test.startTest();
        String coords = NepaMapCreateCtr.defaultAddressCoordinates('1600 Pennsylvania Ave NW, Washington DC');
        Test.stopTest();
        System.assertNotEquals(null, coords, 'Coordinates should not be null');
        System.assert(coords.contains('|'), 'Coordinates should be pipe-delimited longitude|latitude');
    }

    @IsTest
    static void testDefaultAddressCoordinatesNullInput() {
        Test.startTest();
        String coords = NepaMapCreateCtr.defaultAddressCoordinates(null);
        Test.stopTest();
        System.assertNotEquals(null, coords, 'Null input should still return default coordinates');
        System.assert(coords.contains('|'), 'Default coordinates should be pipe-delimited');
    }

    @IsTest
    static void testConstructor() {
        PageReference pg = Page.NEPA_Site_Location_Page;
        pg.getParameters().put('latitude', '39.5');
        pg.getParameters().put('longitude', '-98.35');
        Test.setCurrentPage(pg);

        Test.startTest();
        NepaMapCreateCtr ctr = new NepaMapCreateCtr();
        Test.stopTest();

        System.assertEquals('39.5', ctr.defaultlat, 'Latitude should be read from page parameter');
        System.assertEquals('-98.35', ctr.defaultlng, 'Longitude should be read from page parameter');
        // apiKey is null until NEPA_Map_Config__mdt.Default.Api_Key__c is set post-deploy — test confirms constructor runs cleanly
        System.assertEquals(true, ctr.defaultlat != null, 'Constructor should complete successfully');
    }
}