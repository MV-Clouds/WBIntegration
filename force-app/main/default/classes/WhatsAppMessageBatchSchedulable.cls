public with sharing class WhatsAppMessageBatchSchedulable implements Schedulable {

    public static String templateId;
    public static List<Chat__c> chatRecs;
    public static String broadcastId;
    public static String objectApiName;
    
    public WhatsAppMessageBatchSchedulable(String tempId, List<Chat__c> chats, String broadcastRecId, String objName) {
        templateId = tempId;
        chatRecs = chats;
        broadcastId = broadcastRecId;
        objectApiName = objName;
    }
    
    public void execute(SchedulableContext context){
        WhatsAppMessageBatch batchJob = new WhatsAppMessageBatch(templateId, chatRecs, broadcastId, objectApiName);
        Database.executeBatch(batchJob, 1);
    }
}