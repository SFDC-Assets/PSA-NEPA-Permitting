/** Controller exposing public engagement events to Experience Cloud portal visitors. */
public with sharing class NepaEngagementController {

    /** Single engagement event row returned to LWC. */
    public class EngagementRecord {
        @AuraEnabled public String id;
        @AuraEnabled public String title;
        @AuraEnabled public String engagementType;
        @AuraEnabled public String startDatetime;
        @AuraEnabled public String endDatetime;
        @AuraEnabled public String locationFormat;
        @AuraEnabled public String location;
    }

    /**
     * Returns all public engagement events for the given process, ordered by start date.
     * @param processId Id of the IndividualApplication record
     * @return List of EngagementRecord DTOs for publicly accessible engagement events
     */
    @AuraEnabled(cacheable=true)
    public static List<EngagementRecord> getPublicEngagements(String processId) {
        if (String.isBlank(processId)) {
            throw new AuraHandledException('processId is required');
        }

        // sfge-disable-next-line MissingNullCheckOnSoqlVariable -- String.isBlank guard at top of method
        List<nepa_engagement__c> engagements = [
            SELECT Id,
                   Name,
                   nepa_engagement_type__c,
                   nepa_start_datetime__c,
                   nepa_end_datetime__c,
                   nepa_location_format__c,
                   nepa_location__c,
                   nepa_location__r.Name
            FROM nepa_engagement__c
            WHERE nepa_process__c = :processId
              AND nepa_public_access__c = true
            WITH USER_MODE
            ORDER BY nepa_start_datetime__c ASC
            LIMIT 200
        ];

        List<EngagementRecord> results = new List<EngagementRecord>();
        for (nepa_engagement__c e : engagements) {
            EngagementRecord r = new EngagementRecord();
            r.id             = e.Id;
            r.title          = e.nepa_engagement_type__c;
            r.engagementType = e.nepa_engagement_type__c;
            r.startDatetime  = e.nepa_start_datetime__c != null
                ? String.valueOf(e.nepa_start_datetime__c) : null;
            r.endDatetime    = e.nepa_end_datetime__c != null
                ? String.valueOf(e.nepa_end_datetime__c) : null;
            r.locationFormat = e.nepa_location_format__c;
            r.location       = e.nepa_location__r?.Name;
            results.add(r);
        }
        return results;
    }
}
