/**
 * Post-load script: re-fire all IsChanged-gated flows on IndividualApplication and ContentVersion.
 *
 * Why this is needed: record-triggered flows in this package guard their entry
 * conditions with IsChanged checks. Bulk API v2 CSV import sets these fields on
 * insert — IsChanged evaluates to false in flow context so the flows never fire.
 * This script performs two targeted toggles:
 *
 * Toggle A — IndividualApplication fields (fires):
 *   NEPA_Litigation_Risk_Scorer      → nepa_risk_score_factors__c, nepa_risk_score_updated__c, nepa_risk_score_is_ai__c
 *   NEPA_CE_Screener                 → nepa_screening_confidence__c, nepa_ce_pathway_recommendation__c, nepa_classification_basis__c
 *   NEPA_SLA_Due_Date_Setter         → nepa_sla_due_date__c, nepa_sla_warning_sent__c, nepa_sla_overdue__c
 *   NEPA_Timeline_Risk_Assessor      → nepa_timeline_risk_tier__c, nepa_estimated_completion_date__c
 *   NEPA_Stage_Gate / Orchestrator   → nepa_last_stage_transition__c
 *
 * Toggle B — ContentVersion fields (fires):
 *   NEPA_Defensibility_Trigger_ContentVersion → nepa_defensibility_gaps__c, nepa_defensibility_updated__c
 *   NEPA_Administrative_Record_Checker        → nepa_missing_documents__c (fires on CV IsChanged)
 *
 * Run AFTER 18_postload_polymorphic.apex (all records must exist).
 * Run via: sf apex run --file demo/import_data/23_postload_flow_refresh.apex --target-org <alias>
 */

// ── Wire nepa_related_case_event__c on ContentVersions ───────────────────────
// Defensibility and AdminRecord flows require each CV to have a case event link
// so they can traverse to the IndividualApplication. Wire to the appropriate
// ApplicationTimeline event type: FONSI Issued for decision docs, Scoping
// Complete for supporting analysis, Comment Period Closed for comment response.

Id appId = [
    SELECT Id FROM IndividualApplication
    WHERE nepa_federal_unique_id__c = 'IDI-38709' LIMIT 1
].Id;

ApplicationTimeline evtFONSI = null;
ApplicationTimeline evtScoping = null;
ApplicationTimeline evtCommentClosed = null;
for (ApplicationTimeline at : [
    SELECT Id, nepa_event_type__c
    FROM ApplicationTimeline
    WHERE nepa_related_process__c = :appId
    AND nepa_event_type__c IN ('FONSI Issued', 'Scoping Complete', 'Comment Period Closed')
    ORDER BY CreatedDate ASC
    LIMIT 10
]) {
    if (evtFONSI == null && at.nepa_event_type__c == 'FONSI Issued') evtFONSI = at;
    if (evtScoping == null && at.nepa_event_type__c == 'Scoping Complete') evtScoping = at;
    if (evtCommentClosed == null && at.nepa_event_type__c == 'Comment Period Closed') evtCommentClosed = at;
}
// Fallback: use any event if specific types not found
if (evtFONSI == null && evtScoping == null && evtCommentClosed == null) {
    ApplicationTimeline fallback = [
        SELECT Id FROM ApplicationTimeline
        WHERE nepa_related_process__c = :appId
        ORDER BY CreatedDate ASC LIMIT 1
    ];
    evtFONSI = fallback; evtScoping = fallback; evtCommentClosed = fallback;
}
Map<String, Id> cvCaseEventMap = new Map<String, Id>{
    'Carrie Placer Mine Plan of Operations - Environmental Assessment' =>
        evtScoping != null ? evtScoping.Id : (evtFONSI != null ? evtFONSI.Id : null),
    'Finding of No Significant Impact - Carrie Placer Mine' =>
        evtFONSI != null ? evtFONSI.Id : null,
    'Decision Record - Carrie Placer Mine Plan of Operations' =>
        evtFONSI != null ? evtFONSI.Id : null,
    'Affected Environment and Environmental Consequences Summary - Carrie Placer Mine' =>
        evtScoping != null ? evtScoping.Id : (evtFONSI != null ? evtFONSI.Id : null),
    'Section 106 Tribal Consultation Certification - Shoshone-Paiute Tribes' =>
        evtScoping != null ? evtScoping.Id : (evtFONSI != null ? evtFONSI.Id : null),
    'Public Comment Response Summary - Carrie Placer Mine EA' =>
        evtCommentClosed != null ? evtCommentClosed.Id : (evtFONSI != null ? evtFONSI.Id : null)
};
List<ContentVersion> cvsToWire = [
    SELECT Id, Title, nepa_related_case_event__c
    FROM ContentVersion
    WHERE Title IN :cvCaseEventMap.keySet()
    AND IsLatest = true
    AND nepa_related_case_event__c = null
];
for (ContentVersion cv : cvsToWire) {
    Id evtId = cvCaseEventMap.get(cv.Title);
    if (evtId != null) cv.nepa_related_case_event__c = evtId;
}
if (!cvsToWire.isEmpty()) {
    update cvsToWire;
    System.debug('ContentVersion.nepa_related_case_event__c wired: ' + cvsToWire.size());
}

// ── Toggle A: IndividualApplication ──────────────────────────────────────────

IndividualApplication app = [
    SELECT Id, nepa_review_type__c, nepa_process_stage__c,
           nepa_action_type__c, nepa_disturbance_acres__c
    FROM IndividualApplication
    WHERE nepa_federal_unique_id__c = 'IDI-38709'
    LIMIT 1
];

String origReviewType    = app.nepa_review_type__c;
String origProcessStage  = app.nepa_process_stage__c;
String origActionType    = app.nepa_action_type__c;
Decimal origAcres        = app.nepa_disturbance_acres__c;

// Step A1: set placeholder values so step A2 registers genuine IsChanged hits
// on nepa_review_type__c (Risk Scorer, SLA), nepa_process_stage__c (Stage Gate, Timeline),
// nepa_action_type__c (CE Screener), nepa_disturbance_acres__c (CE Screener)
app.nepa_review_type__c      = 'Other Authorization';
app.nepa_process_stage__c    = 'Scoping';
app.nepa_action_type__c      = 'Research or Study';
app.nepa_disturbance_acres__c = 0;
update app;
System.debug('Toggle A Step 1 — placeholder values written');

// Step A2: restore originals — all IsChanged gates fire
app.nepa_review_type__c      = origReviewType;
app.nepa_process_stage__c    = origProcessStage;
app.nepa_action_type__c      = origActionType;
app.nepa_disturbance_acres__c = origAcres;
update app;
System.debug('Toggle A Step 2 — original values restored; IA flows queued');

// ── Toggle B: ContentVersion (fires Defensibility + AdminRecord triggers) ──

ContentVersion cv = [
    SELECT Id, nepa_document_type__c, nepa_status__c
    FROM ContentVersion
    WHERE Title = 'Carrie Placer Mine Plan of Operations - Environmental Assessment'
    AND IsLatest = true
    LIMIT 1
];

if (cv != null) {
    String origDocType = cv.nepa_document_type__c;
    String origStatus  = cv.nepa_status__c;

    // Toggle document_type to trigger Defensibility and AdminRecord flows
    cv.nepa_document_type__c = 'Other';
    cv.nepa_status__c        = 'Draft';
    update cv;
    System.debug('Toggle B Step 1 — CV placeholder written');

    cv.nepa_document_type__c = origDocType;
    cv.nepa_status__c        = origStatus;
    update cv;
    System.debug('Toggle B Step 2 — CV original values restored; CV flows queued');
}

// ── Verify (async flows may not be reflected immediately) ─────────────────────

System.debug('NOTE: AsyncAfterCommit flows execute after this transaction completes.');
System.debug('Wait 10-15 seconds then query IndividualApplication to confirm field population.');
System.debug('Expected populated: nepa_risk_score_factors__c, nepa_screening_confidence__c,');
System.debug('  nepa_ce_pathway_recommendation__c, nepa_classification_basis__c,');
System.debug('  nepa_sla_due_date__c, nepa_timeline_risk_tier__c, nepa_defensibility_gaps__c,');
System.debug('  nepa_missing_documents__c');
System.debug('=== Flow-refresh complete ===');
