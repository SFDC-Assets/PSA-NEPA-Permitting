/** Controller exposing the public NEPA process timeline to Experience Cloud portal visitors. */
public with sharing class NepaTimelineController {

    /** Single timeline event row returned to LWC. */
    public class TimelineEvent {
        @AuraEnabled public String eventType;
        @AuraEnabled public String stage;
        @AuraEnabled public String startDate;
        @AuraEnabled public String endDate;
        @AuraEnabled public String status;
        @AuraEnabled public String source;
    }

    /**
     * Returns all public timeline events for the given process, ordered by start date.
     * @param processId Id of the IndividualApplication record
     * @return List of TimelineEvent DTOs for publicly accessible case events
     */
    @AuraEnabled(cacheable=true)
    public static List<TimelineEvent> getProcessTimeline(String processId) {
        if (String.isBlank(processId)) {
            throw new AuraHandledException('processId is required');
        }

        // sfge-disable-next-line MissingNullCheckOnSoqlVariable -- String.isBlank guard at top of method
        List<ApplicationTimeline> events = [
            SELECT Id,
                   nepa_event_type__c,
                   nepa_tier__c,
                   nepa_start_date__c,
                   nepa_end_date__c,
                   nepa_status__c,
                   nepa_source__c
            FROM ApplicationTimeline
            WHERE nepa_related_process__c = :processId
              AND nepa_public_access__c = true
            WITH USER_MODE
            ORDER BY nepa_start_date__c ASC NULLS LAST
            LIMIT 200
        ];

        List<TimelineEvent> results = new List<TimelineEvent>();
        for (ApplicationTimeline evt : events) {
            TimelineEvent t = new TimelineEvent();
            t.eventType = evt.nepa_event_type__c;
            t.stage     = evt.nepa_tier__c;
            t.startDate = evt.nepa_start_date__c != null
                ? String.valueOf(evt.nepa_start_date__c) : null;
            t.endDate   = evt.nepa_end_date__c != null
                ? String.valueOf(evt.nepa_end_date__c) : null;
            t.status    = evt.nepa_status__c;
            t.source    = evt.nepa_source__c;
            results.add(t);
        }
        return results;
    }
}