global with sharing class WhatsAppMessageBatchSchedulable implements Schedulable {

    global String templateId;
    global List<Chat__c> chatRecs;
    global String broadcastId;
    global String objectApiName;
    
    global WhatsAppMessageBatchSchedulable(String tempId, List<Chat__c> chats, String broadcastRecId, String objName) {
        this.templateId = tempId;
        this.chatRecs = chats;
        this.broadcastId = broadcastRecId;
        this.objectApiName = objName;
    }
    
    global void execute(SchedulableContext context){
        WhatsAppMessageBatch batchJob = new WhatsAppMessageBatch(this.templateId, this.chatRecs, this.broadcastId, this.objectApiName);
        Database.executeBatch(batchJob, 1);
    }
}