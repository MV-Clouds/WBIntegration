/**
* Class Name: ChatWindowController
* Test Class: -
* @description: Used for handling various actions for the chat
* Date: 22 Nov, 2024
* Created By: Kevin Suvagiya
*--------------------------------------------------------------------------------
* Last Modified By: Kevin Suvagiya
* Last Modified Date: 25 Nov, 2024
* Last Modification Description: added a method to retrieve all the chats for a contact
*--------------------------------------------------------------------------------
* Modification History:
* Date Modified - Developer Name - Description
* 25 Nov, 2024  - Kevin Suvagiya - Added a method to link the chat record with the exception
**/
public with sharing class ChatWindowController {
    
    @AuraEnabled
    public static List<Chat__c> fetchAllChats(String contactId){
        List<Chat__c> chats = new List<Chat__c>();
        try {
            chats = [SELECT Id FROM Chat__c WHERE Contact__c =:contactId WITH SECURITY_ENFORCED];
            if(chats != null){
                System.debug('the data is :: ' + chats[0].Id + 5);
            }
        } catch (Exception e) {
            ExceptionHandler.logException(e, 'a039I00000HYMuwQAH');
            // throw new AuraHandledException(e.getMessage());
        }
        return chats;
    }
}