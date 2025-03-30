public with sharing class WhatsAppChatTriggerHandler {
    private List<Chat__c> recordNewList = new List<Chat__c>();
    private List<Chat__c> recordOldList = new List<Chat__c>();
    private Map<Id, Chat__c> recordNewMap = new Map<Id, Chat__c>();
    private Map<Id, Chat__c> recordOldMap = new Map<Id, Chat__c>();
    private Boolean isInsert;
    private Boolean isUpdate;
    private Boolean isDelete = false;
    private Boolean isUndelete = false;
    private static final String CLASS_NAME = 'WhatsAppChatTriggerHandler';

    public WhatsAppChatTriggerHandler( List<Chat__c> newList,  List<Chat__c> oldList, Map<Id, Chat__c> newMap, Map<Id, Chat__c> oldMap, Boolean isInsert, Boolean isUpdate, Boolean isDelete, Boolean isUndelete) {
        this.recordNewList = newList;
        this.recordOldList = oldList;
        this.recordNewMap = newMap;
        this.recordOldMap = oldMap;
        this.isInsert = isInsert;
        this.isUpdate = isUpdate;
        this.isDelete = isDelete;
        this.isUndelete = isUndelete;
    }

    public void handleAfterUpdateOrInsert() {
        updateBroadcastCounts();
    }

    private void updateBroadcastCounts() {

        try{
            Set<Id> broadcastIds = new Set<Id>();

            // Collect all WB_Broadcast__c IDs
            for (Chat__c chat : recordNewList) {
                if (chat.WB_Broadcast__c != null && chat.Message_Status__c != null) {
                    broadcastIds.add(chat.WB_Broadcast__c);
                }
            }
    
            // Query existing Broadcast__c records
            Map<Id, Broadcast__c> broadcastsToUpdate = new Map<Id, Broadcast__c>();
            if (!broadcastIds.isEmpty()) {
                for (Broadcast__c broadcast : [SELECT Id, Total_Sent__c, Total_Delivered__c, Total_Read__c, Total_Failed__c 
                                               FROM Broadcast__c 
                                               WHERE Id IN :broadcastIds
                                               WITH SECURITY_ENFORCED]) {
                    broadcastsToUpdate.put(broadcast.Id, broadcast);
                }
            }
    
            // Update counts based on message status
            for (Chat__c chat : recordNewList) {
                if (chat.WB_Broadcast__c == null || chat.Message_Status__c == null) {
                    continue;
                }
    
                if (!broadcastsToUpdate.containsKey(chat.WB_Broadcast__c)) {
                    broadcastsToUpdate.put(chat.WB_Broadcast__c, new Broadcast__c(
                        Id = chat.WB_Broadcast__c,
                        Total_Sent__c = 0,
                        Total_Delivered__c = 0,
                        Total_Read__c = 0,
                        Total_Failed__c = 0
                    ));
                }
    
                Broadcast__c broadcast = broadcastsToUpdate.get(chat.WB_Broadcast__c);
    
                // Increment the appropriate counter
                if (chat.Message_Status__c == 'Sent') {
                    broadcast.Total_Sent__c += 1;
                } else if (chat.Message_Status__c == 'Delivered') {
                    broadcast.Total_Delivered__c += 1;
                } else if (chat.Message_Status__c == 'Seen') {
                    broadcast.Total_Read__c += 1;
                } else if (chat.Message_Status__c == 'Failed') {
                    broadcast.Total_Failed__c += 1;
                }
            }
    
            // Perform bulk update
            if (!broadcastsToUpdate.isEmpty()) {
                List<Broadcast__c> broadcastList = new List<Broadcast__c>(broadcastsToUpdate.values()); // Convert map values to list
                Database.update(broadcastList, false, AccessLevel.USER_MODE); // Use the list in Database.update()
            }
        }
        catch(Exception e){
            ExceptionHandler.logException(new Map<String, Object>{
                'className' => CLASS_NAME,
                'methodName' => 'updateBroadcastCounts',
                'exceptionObj' => e,
                'isApiException' => false,
                'statusCode' => null,
                'chatId' => null,
                'moreDetails' => e.getMessage(),
                'apiResponse' => null
            });
        }
    }
        
}
