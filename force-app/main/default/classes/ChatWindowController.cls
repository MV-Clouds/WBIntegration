/**
* Class Name: ChatWindowController
* Test Class: ChatWindowControllerTest
* @description: Used for handling various actions for the chat
* Created Date: 22 Nov, 2024
* Created By: Kevin Suvagiya
*--------------------------------------------------------------------------------
* Last Modified By: Kevin Suvagiya
* Last Modified Date: 06 Dec 2024
* Last Modification Description: Added a method to fetch the full template data with replaced variables
*--------------------------------------------------------------------------------
* Modification History:
* Date Modified - Developer Name - Description
* 25 Nov, 2024  - Kevin Suvagiya - Added a method to link the chat record with the exception
* 05 Dec, 2024  - Kevin Suvagiya - Updated the createChat to create the contentDistribution record for the files
* 06 Dec, 2024  - Kevin Suvagiya - Added implementation for the theme preference logic
* 09 Dec, 2024  - Kevin Suvagiya - Added method to send the message to the user with http request
* 11 Dec, 2024  - Kevin Suvagiya - Added a method to fetch the full template data with replaced variables
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
            List<Template__c> templates = new List<Template__c>();
            Contact recordData = new Contact();
            UserThemePreference__c userPreference = UserThemePreference__c.getInstance(UserInfo.getUserId());

            String theme = userPreference != null && userPreference.Theme__c != null ? userPreference.Theme__c : 'light'; // Default to Light

            chats = [SELECT Id,Type_of_Message__c, Message__c, Message_Status__c, Message_Type__c, Reply_To__c, Reaction__c, Whatsapp_Template__c, Whatsapp_Template__r.Name, CreatedDate, Last_Interaction_Date__c FROM Chat__c WHERE Contact__c =:contactId WITH SECURITY_ENFORCED ORDER BY CreatedDate asc];
            recordData = [SELECT Id, FirstName, MobilePhone FROM Contact WHERE Id=:contactId WITH SECURITY_ENFORCED LIMIT 1];
            templates = [SELECT Id, Name FROM Template__c WHERE Status__c = 'Active-Quality Pending' WITH SECURITY_ENFORCED ORDER BY LastModifiedDate desc];

            combinedData.put('chats', chats);
            combinedData.put('theme', theme);
            combinedData.put('templates', templates);
            combinedData.put('record', recordData);
        } catch (Exception e) {
            ExceptionHandler.logException(new Map<String, Object>{'className' => 'ChatWindowController', 'methodName' => 'fetchAllChats', 'exceptionObj' => e, 'isApiException' => false, 'statusCode' => null, 'chatId' => null, 'moreDetails' => e.getMessage(), 'apiResponse' => null});
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
            chat.Message__c = message;
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

                chat.Message__c = [SELECT ContentDownloadUrl FROM ContentDistribution WHERE Id=:cd.Id].ContentDownloadUrl;
            }
            insert as user chat;
            chat = [SELECT Id,Type_of_Message__c, Message__c, Message_Status__c, Message_Type__c, Reply_To__c, Reaction__c, Whatsapp_Template__c, Whatsapp_Template__r.Name, CreatedDate, Last_Interaction_Date__c FROM Chat__c WHERE Id =:chat.Id WITH SECURITY_ENFORCED];
            return chat;
        } catch (Exception e) {
            ExceptionHandler.logException(new Map<String, Object>{'className' => 'ChatWindowController', 'methodName' => 'createChat', 'exceptionObj' => e, 'isApiException' => false, 'statusCode' => null, 'chatId' => null, 'moreDetails' =>  e.getMessage(), 'apiResponse' => null});
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
            ExceptionHandler.logException(new Map<String, Object>{'className' => 'ChatWindowController', 'methodName' => 'updateReaction', 'exceptionObj' => e, 'isApiException' => false, 'statusCode' => null, 'chatId' => chatId, 'moreDetails' =>  e.getMessage(), 'apiResponse' => null});
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
            ExceptionHandler.logException(new Map<String, Object>{'className' => 'ChatWindowController', 'methodName' => 'updateThemePreference', 'exceptionObj' => e, 'isApiException' => false, 'statusCode' => null, 'chatId' => null, 'moreDetails' => e.getMessage(), 'apiResponse' => null });
        }
        return isSuccess;
    }

    /*
    *********************************************************
    @description     : Method to send the messages from the chat window
    @param           : theme - {String} - The new theme preference ('Light' or 'Dark')
    @return          : isSuccess - {Boolean} - success message for js controller
    ********************************************************
    */
    @AuraEnabled
    public static Chat__c sendWhatsappMessage(String jsonData, String chatId) {
        Chat__c chat = new Chat__c(Id = chatId);
        try {
            HttpRequest httpReq = new HttpRequest();
            String endpoint = 'https://graph.facebook.com/v21.0/397858113402150/messages';
            String accessToken = 'EAAHUUEnZB9J0BO7ybLPGXiLsapulqGefrR4wLrFKhr7u8l2jtZBk4n4ERz9CPgEJ8kdenfxJasSGC5xPWR8ip881IPn8cLyZB7Xj6AfV3XwzEeiRJE6leuVFRKSdOFibQZCsrZA5DxNHZARRYQqrTXI31YJ4XVgEiI6CiHnWePLogHsTtkRWV2TQQWyXYyVQ3C3QZDZD';
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
                ExceptionHandler.logException(new Map<String, Object>{'className' => 'ChatWindowController', 'methodName' => 'sendWhatsappMessage', 'exceptionObj' => null, 'isApiException' => true, 'statusCode' => statusCode, 'chatId' => chatId, 'moreDetails' => 'API Exception while sending a message', 'apiResponse' => response });
            }

            update as user chat;
            chat = [SELECT Id,Type_of_Message__c, Message__c, Message_Status__c, Message_Type__c, Reply_To__c, Reaction__c, Whatsapp_Template__c, Whatsapp_Template__r.Name, CreatedDate, Last_Interaction_Date__c FROM Chat__c WHERE Id =:chat.Id WITH SECURITY_ENFORCED];
            return chat;

        } catch (Exception e) {
            ExceptionHandler.logException(new Map<String, Object>{'className' => 'ChatWindowController', 'methodName' => 'sendWhatsappMessage', 'exceptionObj' => e, 'isApiException' => false, 'statusCode' => null, 'chatId' => chatId, 'moreDetails' => e.getMessage(), 'apiResponse' => null });
        }
        return chat;
    }

    /*
    *********************************************************
    @description     : Method to get the data for a specific template
    @param           : templateId - {String} - Id of the template to fetch
    @param           : contactId - {String} - Id of the contact to fetch related data for variables
    @return          : template - {Template__c} - Template object with full data of it
    ********************************************************
    */
    @AuraEnabled
    public static Template__c getTemplateData(String templateId, String contactId){
        try {
            List<Template__c> templates = new List<Template__c>();
            templates = [SELECT Id, Name, Button_Body__c, Button_Label__c, Button_Type__c, Footer_Body__c, Header_Body__c, Header_Type__c, Language__c, Template_Body__c, Template_Category__c, Template_SubCatagory__c, Template_Type__c, Template_Variable__c, (SELECT Id, Name, Field_Name__c, Object_Name__c, Type__c, Alternate_Text__c FROM WB_Template_Variables__r) FROM Template__c WHERE Id =: templateId WITH SECURITY_ENFORCED];
            if(templates.size() > 0 && templates[0].Template_Variable__c>0){
                Template__c template= templates[0];
                Set<String> fieldSelectionCause = new Set<String>();
                for(Template_Variable__c tv: template.WB_Template_Variables__r){
                    if(tv.Object_Name__c == 'Contact'){
                        fieldSelectionCause.add(tv.Field_Name__c);
                    }else{
                        fieldSelectionCause.add(tv.Object_Name__c + '.' + tv.Field_Name__c);
                    }
                }
                if(fieldSelectionCause.size() < 1){
                    return templates[0];
                }

                String query = 'SELECT Id, ' + String.join(fieldSelectionCause, ', ') + ' FROM Contact WHERE Id =:contactId';
                List<Contact> contacts = Database.query(String.escapeSingleQuotes(query));
                if(contacts.size() > 0){
                    Contact contactRecord = contacts[0];
                    for (Template_Variable__c tv: template.WB_Template_Variables__r) {
                        Object valueToReplace = '';
                        if(tv.Object_Name__c == 'Contact'){
                            valueToReplace = contactRecord.get(tv.Field_Name__c);
                        }else{
                            valueToReplace = contactRecord.getSObject(tv.Object_Name__c).get(tv.Field_Name__c);
                        }
                        if (tv.Type__c == 'Header') {
                            template.Header_Body__c = template.Header_Body__c.replace(tv.Name , valueToReplace != null ? valueToReplace.toString() : tv.Alternate_Text__c );
                        }else if(tv.Type__c == 'Body'){
                            template.Template_Body__c = template.Template_Body__c.replace(tv.Name , valueToReplace != null ? valueToReplace.toString() : tv.Alternate_Text__c );
                        }
                    }
                }
                return template;
            }
            return templates[0];
        } catch (Exception e) {
            ExceptionHandler.logException(new Map<String, Object>{'className' => 'ChatWindowController', 'methodName' => 'getTemplateData', 'exceptionObj' => e, 'isApiException' => false, 'statusCode' => null, 'chatId' => null, 'moreDetails' =>  e.getMessage(), 'apiResponse' => null});
        }
        return null;
    }

}