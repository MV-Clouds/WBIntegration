global with sharing class WhatsAppMessageBatchSchedulable implements Schedulable {

    global String templateId;
    global List<Chat__c> chatRecs;
    global String broadcastId;
    global String objectApiName;
    global String phoneField;
    
    global WhatsAppMessageBatchSchedulable(String tempId, List<Chat__c> chats, String broadcastRecId, String objName, String phoneFieldName) {
        this.templateId = tempId;
        this.chatRecs = chats;
        this.broadcastId = broadcastRecId;
        this.objectApiName = objName;
        this.phoneField = phoneFieldName;
    }
    
    global void execute(SchedulableContext context){
        WhatsAppMessageBatch batchJob = new WhatsAppMessageBatch(this.templateId, this.chatRecs, this.broadcastId, this.objectApiName, this.phoneField);
        Database.executeBatch(batchJob, 1);
    }
}