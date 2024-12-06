/**
* Class Name: ChatWindowController
* Test Class: ChatWindowControllerTest
* @description: Used for handling various actions for the chat
* Created Date: 22 Nov, 2024
* Created By: Kevin Suvagiya
*--------------------------------------------------------------------------------
* Last Modified By: Kevin Suvagiya
* Last Modified Date: 06 Dec 2024
* Last Modification Description: Added implementation for the theme preference logic
*--------------------------------------------------------------------------------
* Modification History:
* Date Modified - Developer Name - Description
* 25 Nov, 2024  - Kevin Suvagiya - Added a method to link the chat record with the exception
* 05 Dec, 2024  - Kevin Suvagiya - Updated the createChat to create the contentDistribution record for the files
* 06 Dec, 2024  - Kevin Suvagiya - Added implementation for the theme preference logic
**/
public with sharing class ChatWindowController {
    
    /*
    *********************************************************
    @description     : Method is used to fetch all the chats 
    @param           : contactId - {String} - Id of the contact to fetch related chats only
    @return          : combinedData - {Map<String, Object>} - Map containing all the chats and theme preference
    ********************************************************
    */
    @AuraEnabled
    public static Map<String, Object> getCombinedData(String contactId){
        Map<String, Object> combinedData = new Map<String, Object>();
        try {
            List<Chat__c> chats = new List<Chat__c>();
            UserThemePreference__c userPreference = UserThemePreference__c.getInstance(UserInfo.getUserId());
            String theme = userPreference != null && userPreference.Theme__c != null ? userPreference.Theme__c : 'light'; // Default to Light
            chats = [SELECT Id,Type_of_Message__c, Message__c, Message_Status__c, Message_Type__c, Reply_To__c, Message_By__c, Reaction__c, CreatedDate, Contact__r.FirstName FROM Chat__c WHERE Contact__c =:contactId WITH SECURITY_ENFORCED ORDER BY CreatedDate asc];
            combinedData.put('chats', chats);
            combinedData.put('theme', theme);
        } catch (Exception e) {
            ExceptionHandler.createExceptionLog(new Map<String, Object>{'className' => 'ChatWindowController', 'methodName' => 'fetchAllChats', 'exceptionObj' => e, 'isApiException' => false, 'statusCode' => null, 'chatId' => null, 'moreDetails' => e.getMessage(), 'apiResponse' => null});
        }
        return combinedData;
    }

    /*
    *********************************************************
    @description     : Method is used to create a new chat message
    @param           : chatData - {Map<String, String>} - Map containing all the data to create a new chat
    @return          : chat - {Chat__c} - the newly created chat
    ********************************************************
    */
    @AuraEnabled
    public static Chat__c createChat(Map<String, String> chatData ){
        try {

            String message = chatData.get('message');
            String templateId = chatData.get('templateId');
            String messageType = chatData.get('messageType');
            String recordId = chatData.get('recordId');
            String replyToChatId = chatData.get('replyToChatId');

            Chat__c chat = new Chat__c();
            // DateTime now = DateTime.now();
            chat.Message__c = (messageType == 'Image') ? '/sfc/servlet.shepherd/version/download/'+ message : message;
            chat.Whatsapp_Template__c = templateId;
            chat.Contact__c = recordId;
            chat.Type_of_Message__c	= 'OutBound Messages';
            chat.Message_Status__c = null;
            // chat.Time_of_Message__c	= now.hour()+':'+now.minute();
            // chat.Date_of_Message__c  = now.date();
            chat.Message_Type__c = messageType;
            chat.Reply_To__c = replyToChatId;

            if(messageType == 'Image'){
                List<ContentVersion> cv = [SELECT Id, Title FROM ContentVersion WHERE Id =: message WITH SECURITY_ENFORCED];
                if(cv.size() < 1) {return null;}
                ContentDistribution cd = new ContentDistribution();
                cd.Name = cv[0].Title;
                cd.ContentVersionId = message;
                cd.PreferencesAllowViewInBrowser= true;
                cd.PreferencesLinkLatestVersion=true;
                cd.PreferencesNotifyOnVisit=false;
                cd.PreferencesPasswordRequired=false;
                cd.PreferencesAllowOriginalDownload= true;
                insert as user cd;
            }

            insert as user chat;
            chat = [SELECT Id,Type_of_Message__c, Message__c, Message_Status__c, Message_Type__c, Reply_To__c, Message_By__c, Reaction__c, CreatedDate, Contact__r.FirstName FROM Chat__c WHERE Id =:chat.Id WITH SECURITY_ENFORCED];
            return chat;
        } catch (Exception e) {
            ExceptionHandler.createExceptionLog(new Map<String, Object>{'className' => 'ChatWindowController', 'methodName' => 'createChat', 'exceptionObj' => e, 'isApiException' => false, 'statusCode' => null, 'chatId' => null, 'moreDetails' =>  e.getMessage(), 'apiResponse' => null});
            return null;
        }
    }


    /*
    *********************************************************
    @description     : Method is used to update the reaction of any chat message
    @param           : chatId - {String} - Id of the chat to update
    @param           : reaction - {String} - reaction to be updated
    @return          : chat - {Chat__c} - the updated chat
    ********************************************************
    */
    @AuraEnabled
    public static Chat__c updateReaction(String chatId, String reaction){
        try{
            Chat__c chat = new Chat__c();
            chat.Id = chatId;
            chat.Reaction__c = reaction;
            update as user chat;
            return chat;
        }catch(Exception e){
            ExceptionHandler.createExceptionLog(new Map<String, Object>{'className' => 'ChatWindowController', 'methodName' => 'updateReaction', 'exceptionObj' => e, 'isApiException' => false, 'statusCode' => null, 'chatId' => chatId, 'moreDetails' =>  e.getMessage(), 'apiResponse' => null});
            return null;
        }
    }

    /*
    *********************************************************
    @description     : Method is used to update the theme preference for the current user
    @param           : theme - {String} - The new theme preference ('Light' or 'Dark')
    @return          : isSuccess - {Boolean} - success message for js controller
    ********************************************************
    */
    @AuraEnabled
    public static Boolean updateThemePreference(String theme) {
        Boolean isSuccess = false;
        try {
            List<UserThemePreference__c> userPreferences = [SELECT Theme__c FROM UserThemePreference__c WHERE SetupOwnerId =: UserInfo.getUserId() WITH SECURITY_ENFORCED];
            UserThemePreference__c userPreference = new UserThemePreference__c();
            if (userPreferences.isEmpty()) {
                userPreference.SetupOwnerId = UserInfo.getUserId();
            }else{
                userPreference = userPreferences[0];
            }
            userPreference.Theme__c = theme;
            upsert as User userPreference;
            isSuccess = true;
        } catch (Exception e) {
            ExceptionHandler.createExceptionLog(new Map<String, Object>{'className' => 'ChatWindowController', 'methodName' => 'updateThemePreference', 'exceptionObj' => e, 'isApiException' => false, 'statusCode' => null, 'chatId' => null, 'moreDetails' => e.getMessage(), 'apiResponse' => null });
        }
        return isSuccess;
    }

}