trigger NepaVisitAfterInsert on Visit (after insert) {
    NepaVisitActionPlanLauncher.createActionPlans(Trigger.new);
}
