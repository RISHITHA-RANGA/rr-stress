trigger PropertyTriggerListedBy on Property__c (before insert,after insert,before update) {
    if(Trigger.isBefore){
            PropertyHandlerListedBy.beforeInsertUpdate(Trigger.new);
    }
    if(Trigger.isAfter){
            PropertyHandlerListedBy.afterInsert(Trigger.new);
    }
}