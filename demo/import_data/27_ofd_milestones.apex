// Step 27: OFD Coordination Milestones for Carrie Placer Mine (IDI-38709)
// Requires: IndividualApplication with nepa_federal_unique_id__c = 'IDI-38709'
// and Accounts with nepa_agency_abbr__c = 'USFWS' and 'USACE' (loaded in 02_Account.csv)

IndividualApplication proc = [
    SELECT Id FROM IndividualApplication
    WHERE nepa_federal_unique_id__c = 'IDI-38709' LIMIT 1
];
Account usfws = [SELECT Id FROM Account WHERE nepa_agency_abbr__c = 'USFWS' LIMIT 1];
Account usace = [SELECT Id FROM Account WHERE nepa_agency_abbr__c = 'USACE' LIMIT 1];

// Base date: application received Mar 12, 2019 (day 0)
Date baseDate = Date.newInstance(2019, 3, 12);

List<ApplicationTimeline> milestones = new List<ApplicationTimeline>{
    buildMilestone(proc.Id, 'NEPA_Lead', 'Scoping Notice Published', null,
                   'Completed', baseDate.addDays(45), baseDate.addDays(30)),
    buildMilestone(proc.Id, 'Agency_Consultation', 'ESA Section 7 Initiation', usfws.Id,
                   'In Progress', baseDate.addDays(90), null),
    buildMilestone(proc.Id, 'Permit_Milestone', 'USACE Section 404 Pre-Application Meeting', usace.Id,
                   'Scheduled', baseDate.addDays(120), null),
    buildMilestone(proc.Id, 'Joint_ROD', 'Record of Decision', null,
                   'Pending', baseDate.addDays(243), null)
};
insert milestones;
System.debug('Inserted ' + milestones.size() + ' OFD milestones for IDI-38709');
for (ApplicationTimeline at : milestones) {
    System.debug('  ' + at.nepa_ofd_track__c + ' / ' + at.nepa_event_type__c + ' → ' + at.nepa_status__c);
}

ApplicationTimeline buildMilestone(Id procId, String track, String eventType,
                                    Id coordAgency, String status,
                                    Date targetDate, Date completedDate) {
    ApplicationTimeline at = new ApplicationTimeline();
    at.nepa_related_process__c     = procId;
    at.nepa_ofd_track__c           = track;
    at.nepa_event_type__c          = eventType;
    at.nepa_coordinating_agency__c = coordAgency;
    at.nepa_status__c              = status;
    at.nepa_target_date__c         = targetDate;
    if (completedDate != null) at.nepa_completed_date__c = completedDate;
    return at;
}
