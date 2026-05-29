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

    private static NEPA_Map_Config__mdt cfg {
        get {
            if (cfg == null) {
                cfg = NEPA_Map_Config__mdt.getInstance('Default');
            }
            return cfg;
        }
        set;
    }

    public String strLat {
        get { return String.isBlank(strLat) ? (cfg != null && cfg.Default_Latitude__c != null ? String.valueOf(cfg.Default_Latitude__c) : null) : strLat; }
        set;
    }
    public String strLon {
        get { return String.isBlank(strLon) ? (cfg != null && cfg.Default_Longitude__c != null ? String.valueOf(cfg.Default_Longitude__c) : null) : strLon; }
        set;
    }

    public NepaMapCreateCtr() {
        apiKey = cfg != null ? cfg.Api_Key__c : null;
        defaultlat = ApexPages.currentPage().getParameters().get('latitude');
        defaultlng = ApexPages.currentPage().getParameters().get('longitude');
        communityUrl = fetchCommunityURL();
    }

    @AuraEnabled(cacheable=true)
    @SuppressWarnings('PMD.ApexCRUDViolation')
    public static String fetchCommunityURL() {
        NEPA_Map_Config__mdt config = NEPA_Map_Config__mdt.getInstance('Default');
        String siteName = config != null ? config.Site_Name__c : null;
        if (String.isNotBlank(siteName)) {
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
        NEPA_Map_Config__mdt config = NEPA_Map_Config__mdt.getInstance('Default');
        if (config == null || config.Default_Longitude__c == null || config.Default_Latitude__c == null) {
            return '-98.35|39.5';
        }
        return String.valueOf(config.Default_Longitude__c) + '|' + String.valueOf(config.Default_Latitude__c);
    }
}
