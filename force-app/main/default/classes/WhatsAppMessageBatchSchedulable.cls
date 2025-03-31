public with sharing class WhatsAppMessageBatchSchedulable implements Schedulable {

    public static List<Chat__c> chatRecs;
    public static String jsonData;
    public static String broadcastId;
    
    public WhatsAppMessageBatchSchedulable(List<Chat__c> chats, String jsonDataBody, String broadcastRecId) {
        chatRecs = chats;
        jsonData = jsonDataBody;
        broadcastId = broadcastRecId;
    }
    public void execute(SchedulableContext context){
        WhatsAppMessageBatch batchJob = new WhatsAppMessageBatch(chatRecs, jsonData, broadcastId);
        Database.executeBatch(batchJob, 1);
    }
}