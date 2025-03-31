public with sharing class WhatsAppMessageBatch implements Database.Batchable<SObject>, Database.AllowsCallouts, Database.Stateful {
    
    public static List<Chat__c> chatsToProcess;
    public static String jsonData;
    public static String broadcastId;
    public static List<Chat__c> chatsToUpdate = new List<Chat__c>();
    public static List<String> failedMessages = new List<String>();
    public static List<MVWB__WBConnect_Configuration__mdt> wbConfig = MVWB__WBConnect_Configuration__mdt.getAll().values(); 

    // Constructor to pass Chat__c list and template data
    public WhatsAppMessageBatch(List<Chat__c> chats, String jsonData, String broadcastId) {
        chatsToProcess = chats;
        jsonData = jsonData;
        broadcastId = broadcastId;
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([SELECT Id, Phone__c, WhatsAppMessageId__c, Message_Status__c FROM Chat__c WHERE Id IN :chatsToProcess]);
    }

    public void execute(Database.BatchableContext bc, List<Chat__c> chatList) {
        for (Chat__c chat : chatList) {
            sendWhatsAppMessage(chat.Id);
        }
    }

    public void finish(Database.BatchableContext bc) {
        if (!chatsToUpdate.isEmpty()) {
            update chatsToUpdate;
        }

        if(broadcastId != null){
            Broadcast__c br = new Broadcast__c(Id = broadcastId);
            br.Status__c = 'Completed';
            update br;
        }
    }

    @future(callout=true)
    public static void sendWhatsAppMessage(String chatId) {
        try {
            Chat__c chat = [SELECT Id, Phone__c, WhatsAppMessageId__c, Message_Status__c FROM Chat__c WHERE Id = :chatId LIMIT 1];
    
            HttpRequest httpReq = new HttpRequest();
            String accessToken = wbConfig[0].MVWB__Access_Token__c;
            String endpoint = 'https://graph.facebook.com/v21.0/' + wbConfig[0].MVWB__Phone_Number_Id__c + '/messages';
            httpReq.setEndpoint(endpoint);
            httpReq.setMethod('POST');
            httpReq.setHeader('Content-Type', 'application/json');
            httpReq.setHeader('Authorization', 'Bearer ' + accessToken);
            httpReq.setBody(jsonData);
            Http http = new Http();
            HttpResponse response = http.send(httpReq);
            Integer statusCode = response.getStatusCode();
            if(response != null && statusCode == 200){
                String responseBody = response.getBody();
                Map<String, Object> jsonMap = (Map<String, Object>)JSON.deserializeUntyped(responseBody);
                List<Object> messages = (List<Object>)jsonMap.get('messages');
                Map<String, Object> firstMessage = (Map<String, Object>)messages[0];
                String whatsAppMessageID = (String) firstMessage.get('id');
                System.debug('WhatsApp Message ID: ' + whatsAppMessageID);
                // Update the chat record
                chat.WhatsAppMessageId__c = whatsAppMessageID;
                chat.Message_Status__c = 'Sent';
            }else{
                System.debug('Error sending WhatsApp Message: '+response.getBody());
                chat.Message_Status__c = 'Failed';
                ExceptionHandler.logException(new Map<String, Object>{'className' => 'WhatsAppMessageBatch', 'methodName' => 'sendWhatsAppMessage', 'exceptionObj' => null, 'isApiException' => true, 'statusCode' => statusCode, 'chatId' => chatId, 'moreDetails' => 'API Exception while sending a message', 'apiResponse' => JSON.serialize(response.getBody()) });
            }
            chatsToUpdate.add(chat);
        } catch (Exception e) {
            ExceptionHandler.logException(new Map<String, Object>{'className' => 'WhatsAppMessageBatch', 'methodName' => 'sendWhatsAppMessage', 'exceptionObj' => e, 'isApiException' => false, 'statusCode' => '', 'chatId' => chatId, 'moreDetails' => '', 'apiResponse' => '' });
        }
    }
}