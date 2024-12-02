/**
* Class Name: ChatWindowController
* Test Class: -
* @description: Used for handling various actions for the chat
* Created Date: 22 Nov, 2024
* Created By: Kevin Suvagiya
*--------------------------------------------------------------------------------
* Last Modified By: Kevin Suvagiya
* Last Modified Date: 02 Dec 2024
* Last Modification Description: Updated the fetchAllChats method to retrieve the contact first name
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
            // Your Code
            chats = [SELECT Id,Type_of_Message__c, Message__c, Time_of_Message__c, Message_Status__c, CreatedDate, Contact__r.FirstName FROM Chat__c WHERE Contact__c =:contactId WITH SECURITY_ENFORCED ORDER BY CreatedDate asc];
            // Integer result = 10 / 0;
        } catch (Exception e) {
            // To Log The Exception
            // ExceptionHandler.logException(e);

            ExceptionHandler.ExceptionWrapper exceptionData = new ExceptionHandler.ExceptionWrapper();
            exceptionData.className = 'ChatWindowController';
            exceptionData.methodName = 'fetchAllChats';
            exceptionData.exceptionObj = e;
            exceptionData.isApiException = true; // Set true if it's an API exception
            exceptionData.statusCode = 200; // Set if applicable (e.g., HTTP status code)
            exceptionData.chatId = 'a039I00000HaEFbQAN'; // Replace with actual Chat ID if available
            exceptionData.moreDetails = 'This is the more details provided by the api error';
            exceptionData.apiResponse = '{This:{"this":"testing"}, {"testing" : "testing 2"}}';
        
            // Log the exception
            ExceptionHandler.createExceptionLog(exceptionData);
        }
        return chats;
    }

    @AuraEnabled
    public static Chat__c createChat(String message, String templateId, String messageType, String recordId ){
        try {
            Chat__c chat = new Chat__c();
            DateTime now = DateTime.now();
            chat.Message__c = message;
            chat.Whatsapp_Template__c = templateId;
            chat.Contact__c = recordId;
            chat.Type_of_Message__c = 'Action';
            chat.Type_of_Message__c	= 'OutBound Messages';
            chat.Message_Status__c = null;
            chat.Time_of_Message__c	= now.hour()+':'+now.minute();
            chat.Date_of_Message__c  = now.date();
            chat.Message_Type__c = messageType;

            insert as user chat;

            chat = [SELECT Id,Type_of_Message__c, Message__c, Time_of_Message__c, Message_Status__c, CreatedDate FROM Chat__c WHERE Id =:chat.Id WITH SECURITY_ENFORCED];
            return chat;
        } catch (Exception e) {

            ExceptionHandler.ExceptionWrapper exceptionData = new ExceptionHandler.ExceptionWrapper();
            exceptionData.className = 'ChatWindowController';
            exceptionData.methodName = 'createChat';
            exceptionData.exceptionObj = e;
            exceptionData.moreDetails = e.getMessage();
        
            // Log the exception
            ExceptionHandler.createExceptionLog(exceptionData);
            return null;
        }
    }
}