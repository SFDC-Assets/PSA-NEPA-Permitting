/*
 * Copyright (c) 2026, salesforce.com, inc.
 * All rights reserved.
 * Licensed under the BSD 3-Clause license.
 */
public with sharing class NepaMapCreateCtr {

    public String apiKey { get; set; }
    public String defaultlat { get; set; }
    public String defaultlng { get; set; }
    public String communityUrl { get; set; }

    public String strLat {
        get { return String.isBlank(strLat) ? NEPA_Map_Config__mdt.getInstance('Default_Latitude').Value__c : strLat; }
        set;
    }
    public String strLon {
        get { return String.isBlank(strLon) ? NEPA_Map_Config__mdt.getInstance('Default_Longitude').Value__c : strLon; }
        set;
    }

    public NepaMapCreateCtr() {
        apiKey = NEPA_Map_Config__mdt.getInstance('ApiKey').Value__c;
        defaultlat = ApexPages.currentPage().getParameters().get('latitude');
        defaultlng = ApexPages.currentPage().getParameters().get('longitude');
        communityUrl = fetchCommunityURL();
    }

    @AuraEnabled(cacheable=true)
    @SuppressWarnings('PMD.ApexCRUDViolation')
    public static String fetchCommunityURL() {
        String siteName = NEPA_Map_Config__mdt.getInstance('SiteName') != null
            ? NEPA_Map_Config__mdt.getInstance('SiteName').Value__c
            : null;
        if (siteName != null) {
            List<Site> sites = [SELECT Id FROM Site WHERE Name = :siteName WITH USER_MODE LIMIT 1];
            if (!sites.isEmpty()) {
                List<SiteDetail> details = [SELECT SecureURL FROM SiteDetail WHERE DurableId = :sites[0].Id WITH USER_MODE LIMIT 1];
                if (!details.isEmpty()) {
                    return details[0].SecureURL.removeEnd('/');
                }
            }
        }
        return Site.getBaseSecureUrl() != null ? Site.getBaseSecureUrl().removeEnd('/') : '';
    }

    @AuraEnabled(cacheable=true)
    public static String fetchVFDomainURL() {
        return 'https://' + DomainCreator.getVisualforceHostname('');
    }

    @AuraEnabled(cacheable=true)
    public static String defaultAddressCoordinates(String inputAddress) {
        return NEPA_Map_Config__mdt.getInstance('Default_Longitude').Value__c
            + '|' + NEPA_Map_Config__mdt.getInstance('Default_Latitude').Value__c;
    }
}
