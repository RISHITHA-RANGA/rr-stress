trigger PropertyTriggerListedBy on Property__c (before insert,after insert,before update) {
    if(Trigger.isBefore){
            PropertyHandlerListedBy.beforeInsertUpdate(Trigger.new);
    }
    if(Trigger.isAfter){
            PropertyHandlerListedBy.afterInsert(Trigger.new);
    }
}

//this is a test comment to check whether the agent is working fine to push changes to github or not 
//this is test2
//this is test3