/**
* Class Name: WhatsAppChatTriggerHandler
* Test Class: BroadcastMessageControllerTest
* Description: This class is used to handle the WhatsApp chat records and update broadcast records for total count.
* Created Date: 03 April 2025
* Created By: Rachit Shah
*--------------------------------------------------------------------------------
**/

public without sharing class WhatsAppChatTriggerHandler {
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

    
    /*
    *********************************************************
    @description     : This method is used to update the broadcast records for total counts.
    @param           :  None
    @return          : void
    ********************************************************
    */
    public void handleAfterUpdateOrInsert() {
        updateBroadcastCounts();
    }

    /*
    *********************************************************
    @description     : This method is used to update the broadcast records for total counts.
    @param           :  None
    @return          : void
    ********************************************************
    */

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
                                               WHERE Id IN :broadcastIds]) {
                    broadcast.Total_Sent__c = broadcast.Total_Sent__c == null ? 0 : broadcast.Total_Sent__c;
                    broadcast.Total_Delivered__c = broadcast.Total_Delivered__c == null ? 0 : broadcast.Total_Delivered__c;
                    broadcast.Total_Read__c = broadcast.Total_Read__c == null ? 0 : broadcast.Total_Read__c;
                    broadcast.Total_Failed__c = broadcast.Total_Failed__c == null ? 0 : broadcast.Total_Failed__c;
                                
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
                        Id = chat.WB_Broadcast__c, Total_Sent__c = 0, Total_Delivered__c = 0, Total_Read__c = 0,Total_Failed__c = 0
                    ));
                }
                
                Broadcast__c broadcast = broadcastsToUpdate.get(chat.WB_Broadcast__c);

                broadcast.Total_Sent__c += chat.Message_Status__c == 'Sent' ? 1 : 0;
                broadcast.Total_Delivered__c += chat.Message_Status__c == 'Delivered' ? 1 : 0;
                broadcast.Total_Read__c += chat.Message_Status__c == 'Seen' ? 1 : 0;
                broadcast.Total_Failed__c += chat.Message_Status__c == 'Failed' ? 1 : 0;
            }
    
            // Perform bulk update
            if (!broadcastsToUpdate.isEmpty()) {
                List<Broadcast__c> broadcastList = new List<Broadcast__c>(broadcastsToUpdate.values()); // Convert map values to list
                Database.update(broadcastList, false); // Use the list in Database.update()
            }
        }
        catch(Exception e){
            ExceptionHandler.logException(new Map<String, Object>{'className' => CLASS_NAME,'methodName' => 'updateBroadcastCounts','exceptionObj' => e,'isApiException' => false,'statusCode' => null,'chatId' => null,'moreDetails' => e.getMessage(),'apiResponse' => null});
        }
    }
        
}