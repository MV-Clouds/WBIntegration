/**
 * @description       : 
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             : 
 * @last modified on  : 12-03-2024
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
**/
public without sharing class WhatsAppChatController {

    public static String currentTime = System.now().format('yyyy-MM-dd HH:mm:ss');

	@AuraEnabled
    public static Boolean sendMessageWithText(String toPhone, String messageText, String contactId,String Message,String timeOfMessage,String fileData) {
        try {
            
            List<Map<String, Object>> messagesToSend = new List<Map<String, Object>>();
            Map<String, Object> messageMap = new Map<String, Object>();

            String formattedMessage = messageText.replaceAll('"','\'');
            String messageBody = '{'+
            '    "messaging_product": "whatsapp",'+
            '    "recipient_type": "individual",'+
            '    "to": "'+toPhone+'",'+
            '    "type": "text",'+
            '    "text": {'+
            '        "body": "'+formattedMessage+'"'+
            '    }'+
            '}';

            messageMap.put('phone',toPhone);
            messageMap.put('messageBody', messageBody);
            messageMap.put('contactId', contactId);
            messageMap.put('fileName', formattedMessage);
            messageMap.put('timeOfMessage', timeOfMessage);
            messageMap.put('fileData',fileData);
            messagesToSend.add(messageMap);

            sendWhatsAppMessageMap(messagesToSend);
            // sendWhatsAppMessage(toPhone, messageBody,contactId, formattedMessage,timeOfMessage,fileData);

            
            return true;
        } catch (Exception e) {
            System.debug('Error in sendMessageWithText: ' + e.getMessage() + '\n' + e + '\n Exception line no: ' + e.getLineNumber());
            return false;
        }
    }

    @AuraEnabled
    public static Map<String, String> createContentDistribution(List<String> contentDocumentIds, String contactId) {
        try {
            System.debug('contentDocumentIds-->'+contentDocumentIds);

            Map<String, String> contentDocumentToDistributionMap = new Map<String, String>();

            List<ContentVersion> contentVersions = [
                    SELECT Id, Title, VersionData, ContentDocumentId
                    FROM ContentVersion
                    WHERE ContentDocumentId IN :contentDocumentIds WITH SECURITY_ENFORCED
                    ORDER BY CreatedDate];

           System.debug('contentVersions-->'+contentVersions);         
            
            if (contentVersions.isEmpty()) {
                throw new AuraHandledException('No ContentVersion found for the given ContentDocumentId.');
            }
            // Check if the ContentDocumentLink already exists
            List<ContentDocumentLink> existingLinks;
            if(ContentDocumentLink.SObjectType.getDescribe().isAccessible() && Schema.SObjectType.ContentDocumentLink.fields.Id.isAccessible() 
                  && Schema.SObjectType.ContentDocumentLink.fields.ContentDocumentId.isAccessible() && Schema.SObjectType.ContentDocumentLink.fields.LinkedEntityId.isAccessible()) {
                existingLinks = [SELECT Id FROM ContentDocumentLink WHERE ContentDocumentId IN:contentDocumentIds AND LinkedEntityId = :contactId];
            
            }

            System.debug('existingLinks-->'+existingLinks);

            List<ContentDocumentLink> contentdoclinks = new List<ContentDocumentLink>();
            if (existingLinks.isEmpty()) {
                // Create a new ContentDocumentLink if not exists
                for(String contentdocId : contentDocumentIds){
                    ContentDocumentLink newLink = new ContentDocumentLink(
                        ContentDocumentId = contentdocId,
                        LinkedEntityId = contactId,
                        ShareType = 'V', 
                        Visibility = 'AllUsers' 
                    );
                    contentdoclinks.add(newLink);
                }
                if(Schema.sObjectType.ContentDocumentLink.isCreateable()){
                    insert contentdoclinks;
                }
            }
            
            System.debug('contentdoclinks-->'+contentdoclinks);

            List<contentDistribution> contentDistributionlst = new List<contentDistribution>();
            // ContentVersion contentVersion = contentVersions[0];

            for(ContentVersion cv : contentVersions){

                // Create ContentDistribution record
                ContentDistribution contentDistribution = new ContentDistribution(
                    Name = 'Public Link',
                    ContentVersionId = cv.Id,
                    PreferencesAllowOriginalDownload = true,
                    PreferencesAllowPDFDownload = true,
                    PreferencesAllowViewInBrowser = true,
                    PreferencesNotifyOnVisit = false
                );
                contentDistributionlst.add(contentDistribution);
            }            
            insert contentDistributionlst;

            System.debug('contentDistributionlst-->'+contentDistributionlst);

            List<ContentDistribution> ContentDistributionList = new List<ContentDistribution>();
            ContentDistributionList = [SELECT Id,ContentVersionId,ContentDownloadUrl FROM ContentDistribution WHERE Id IN:contentDistributionlst];
            
            for(ContentDistribution cndis : ContentDistributionList){
                for (ContentVersion cv : contentVersions) {
                    if (cndis.ContentVersionId == cv.Id) {
                        if(!contentDocumentToDistributionMap.containsKey(cv.ContentDocumentId)){
                            contentDocumentToDistributionMap.put(cv.ContentDocumentId, cndis.ContentDownloadUrl);
                        }
                        contentDocumentToDistributionMap.get(cv.ContentDocumentId);
                    }
                }                
            }
            System.debug('contentDocumentToDistributionMap-->'+contentDocumentToDistributionMap);
            return contentDocumentToDistributionMap;          
        } catch (Exception e) {
            System.debug('Error in createContentDistribution: ' + e.getMessage() + '\n' + e + '\n Exception line no: ' + e.getLineNumber());
            return null;
        }
    }

    @AuraEnabled
    public static void sendTemplateMessage(String tempId, String toPhone, String contactId, String timeOfMessage, String fileData,String headerMergeVal,List<String> mergeFieldValues){
        try {
            List<Template__c> waTemplst = [SELECT Id, Name, Button_Body__c,Button_Label__c, Button_Type__c, Footer_Body__c, Header_Body__c, Header_Type__c, Language__c, Template_Body__c, 
                                        Template_Category__c, Template_SubCatagory__c, Template_Type__c, Template_Variable__c FROM Template__c WHERE Id = :tempId WITH SECURITY_ENFORCED LIMIT 1];

            List<Contact> conlst = [SELECT Id,Name,Phone from Contact where id =: contactId WITH SECURITY_ENFORCED];

            String messageBody = '';

            Boolean hasCopyCodeButton = false;

            if(!waTemplst.isEmpty() && !conlst.isEmpty()){

                if (!String.isBlank(waTemplst[0].Button_Type__c)) {
                    List<String> buttonTypes = waTemplst[0].Button_Type__c.split('\n'); 
        
                    for (String buttonType : buttonTypes) {
                        if (buttonType.trim().contains('Copy offer code')) {
                            hasCopyCodeButton = true;
                        }
                    }
                }

                List<String> headerParameters = new List<String>();
                List<String> bodyParameters = new List<String>();
    
                if (waTemplst[0].Template_Variable__c > 0 && !String.isBlank(headerMergeVal)) {
                    headerParameters.add('{ "type": "text", "text": "' + headerMergeVal + '" }');
                }
                
        
                if (mergeFieldValues != null && mergeFieldValues.size() > 0) {
                    for (Integer i = 0; i < mergeFieldValues.size(); i++) {
                        String bodyValue = mergeFieldValues[i];
                        if (!String.isBlank(bodyValue)) {
                            bodyParameters.add('{ "type": "text", "text": "' + bodyValue + '" }');
                        }
                    }
                }

                if(String.isNotBlank(conlst[0].Phone) && String.isNotBlank(waTemplst[0].Name) && String.isNotBlank(waTemplst[0].Language__c)){
        
                    messageBody = '{ "messaging_product": "whatsapp", "to": "' + conlst[0].Phone + '", "type": "template", "template": { "name": "' + waTemplst[0].Name + '", "language": { "code": "' + waTemplst[0].Language__c + '" }, "components": [ ';
                }
    
                if (headerParameters.size() > 0) {
                    String headerParamsJson = '[' + String.join(headerParameters, ',') + ']';
                    messageBody += '{"type": "header", "parameters": ' + headerParamsJson + ' }';
                }
        
                if (bodyParameters.size() > 0) {
                    if (headerParameters.size() > 0) {
                        messageBody += ', '; 
                    }
                    String bodyParamsJson = '[' + String.join(bodyParameters, ',') + ']';
                    messageBody += '{"type": "body", "parameters": ' + bodyParamsJson + ' }';
                }

                if (hasCopyCodeButton) {
                    String couponCode = generateCouponCode(); 
                    messageBody += '{ "type": "button", "sub_type": "COPY_CODE", "index": 0, "parameters": [{ "type": "coupon_code", "coupon_code": "' + couponCode + '" }] }';
                }
        
                messageBody += '] } }';
            
            
                waTemplst[0].Name = String.isNotBlank(waTemplst[0].Name) ? waTemplst[0].Name : '';

                List<Map<String, Object>> messagesToSend = new List<Map<String, Object>>();
                Map<String,Object> whatsappMap = new Map<String,Object>();
                whatsappMap.put('toPhone',toPhone);                
                whatsappMap.put('messageBody',messageBody);                
                whatsappMap.put('contactId',contactId);
                whatsappMap.put('templateName',waTemplst[0].Name);
                whatsappMap.put('timeOfMessage',timeOfMessage);
                whatsappMap.put('fileData',fileData);
                messagesToSend.add(whatsappMap);
                // sendWhatsAppMessageMap(messagesToSend);

                sendWhatsAppMessage(toPhone, messageBody, contactId, waTemplst[0].Name, timeOfMessage , fileData);
            }

        } catch (Exception e) {
            // ErrorHandler.insert_errordata(e, 'WhatsAppIntegration', 'snedTemplateMessage', e.getMessage());
            System.debug('Error in snedTemplateMessage: ' + e.getMessage() + '\n' + e + '\n Exception line no: ' + e.getLineNumber());
        }
    }

    public static String generateOTP() {
        Integer otp = (Integer) (Math.random() * 900000) + 100000;
        return String.valueOf(otp);
    }

    public static String generateCouponCode() {

        try {
            List<Integer> possibleLengths = new List<Integer>{5, 8,10, 12, 15};
    
            Integer randomLength = possibleLengths[(Integer)(Math.floor(Math.random() * possibleLengths.size()))];       
        
            String characters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
            String couponCode = '';
        
            for (Integer i = 0; i < randomLength; i++) {
                Integer randomIndex = (Integer)(Math.floor(Math.random() * characters.length()));
                couponCode += characters.substring(randomIndex, randomIndex + 1); 
            }
        
            return couponCode; 
        } catch (Exception e) {
            // ErrorHandler.insert_errordata(e, 'WhatsAppIntegration', 'generateCouponCode', e.getMessage());
            System.debug('Error in generateCouponCode: ' + e.getMessage() + '\n' + e + '\n Exception line no: ' + e.getLineNumber());
            return null;
        }

    }
    
    public static Object getSettings() {
        return WhatsAppConfig__c.getOrgDefaults();
    }

    public static void sendWhatsAppMessage(String toPhone, String messageBody,String contactId,String messageText, String timeOfMessage, String fileData) {
        // String isTestApp = System.Label.Whatsapp_test_app_toggle;
        String accessToken = '';
        String endpoint = '';
        // if(isTestApp == 'true'){
        //     accessToken = System.Label.Test_WA_Accesstoken;
        //     endpoint = System.Label.Test_WA_endpoint;  
        // } else if(isTestApp == 'false'){
        //     accessToken = System.Label.access_token_for_whatsapp;
        //     endpoint = System.Label.whatsapp_endpoint;  
        // }
        WhatsAppConfig__c config = (WhatsAppConfig__c) getSettings();

        accessToken = config.WB_AccessToken__c;
        // endpoint = config.whatsapp_endpoint__c;
        if((accessToken != '') && (endpoint != '')){
            System.debug('Body ::' + messageBody);
            // Parse the JSON string
            Map<String, Object> parsedJson = (Map<String, Object>) JSON.deserializeUntyped(messageBody);
            String messagetypeValue = (String) parsedJson.get('type');
            System.debug('Type: ' + messagetypeValue);
            String templateName = '';
            Id templateId = null;

            if(messagetypeValue == 'template'){
                Map<String, Object> retrievedTemplateMap = (Map<String, Object>) parsedJson.get('template');
                templateName = (String) retrievedTemplateMap.get('name');
                System.debug(templateName);
                	Template__c templateRecord = [SELECT Id FROM Template__c WHERE Name = :templateName WITH SECURITY_ENFORCED LIMIT 1];
                if (templateRecord != null) {
                    templateId = templateRecord.Id;
                }
            }
            HttpRequest httpReq = new HttpRequest();
            httpReq.setEndpoint(endpoint);
            httpReq.setMethod('POST');
            httpReq.setHeader('Content-Type', 'application/json');
            httpReq.setHeader('Authorization', 'Bearer '+ accessToken);
            httpReq.setBody(messageBody);
            System.debug('request :: ' + httpReq);
            DateTime myDateTime = DateTime.now();
            Date formattedDate = myDateTime.date();

            Http http = new Http();
            try {
                HttpResponse response = http.send(httpReq);
                System.debug('Response Body ==>' + response.getBody());
                System.debug('Response Code ==>' + response.getStatusCode());
                Integer statusCode = response.getStatusCode();                
                if(response != null && statusCode == 200){
                    String reponseBody = response.getBody();
                    Map<String, Object> jsonMap = (Map<String, Object>) JSON.deserializeUntyped(reponseBody);
                    List<Object> messages = (List<Object>) jsonMap.get('messages');
                    Map<String, Object> firstMessage = (Map<String, Object>) messages[0];
                    String whatsAppMessageID = (String) firstMessage.get('id');
                    System.debug('WhatsApp Message ID: ' + whatsAppMessageID);

                    Chat__c whatsappMsg = new Chat__c(
                        Type_of_Message__c = 'Outbound Message',
                        Message__c = messageText,
                        Time_of_Message__c = timeOfMessage, 
                        Message_Type__c = messagetypeValue,
                        WhatsAppMessageID__c = whatsAppMessageID,
                        Contact__c = contactId,
                        Date_of_Message__c = formattedDate,
                        File_Data__c = fileData 
                    );
                    
                    if(templateName != '' && messagetypeValue == 'template'){
                        whatsappMsg.Whatsapp_Template__c = templateId;
                    }
                    if(Schema.sObjectType.Chat__c.isCreateable()){
                        insert whatsappMsg;
                    }
                    System.debug('whatsappMsg ==> ' + whatsappMsg);
                }else{
                    System.debug('Error in sending the message.');
                    // Contact contact = [SELECT Id, Name, OwnerId FROM Contact WHERE Id = :contactId LIMIT 1];
                    // sendNotificationForContact(contact);
                }
            } catch (Exception e) {
                // ErrorHandler.insert_errordata(e, 'WhatsAppIntegration', 'sendWhatsAppMessage', e.getMessage());
                System.debug('Error in sendWhatsAppMessage: ' + e.getMessage() + '\n' + e + '\n Exception line no: ' + e.getLineNumber());
            }
        } else{
            System.debug('Failed fetched access token and endpoint from custom labels');
        }
    }

    public static void sendNotificationForContact(Contact con) {
        try {
            List<CustomNotificationType> cnType = [SELECT Id FROM CustomNotificationType WHERE DeveloperName = 'WhatsappNotification' WITH SECURITY_ENFORCED];
            System.debug('custom notification===> '+cnType);
            
            // Id userId = Userinfo.getUserId();
            String messageContent = 'Message has not been sent to '+ con.Name;
            System.debug('messageContent==> '+messageContent);
            // Prepare the custom notification object
            Set<String> addressee = new Set<String>();
            addressee.add(con.OwnerId);
            Messaging.CustomNotification customNotificationObj = new Messaging.CustomNotification();
            customNotificationObj.setBody(messageContent); 
            customNotificationObj.setTitle('Sending message failed.'); 
            if(!cnType.isEmpty()){
                customNotificationObj.setNotificationTypeId(cnType[0].Id); 
            }
            // customNotificationObj.setSenderId(userId); 
            customNotificationObj.setTargetId(con.Id); 
            customNotificationObj.send(addressee);

        } catch (Exception e) {
            // ErrorHandler.insert_errordata(e, 'WhatsAppIntegration', 'sendNotificationForContact', e.getMessage());
            System.debug('Error in sendNotificationForContact: ' + e.getMessage() + '\n' + e + '\n Exception line no: ' + e.getLineNumber());
        }
    }


    @AuraEnabled
    public static Boolean sendDocumentByUrl1(List<Map<String, Object>> documents) {
        try {

            List<Map<String, Object>> messagesToSend = new List<Map<String, Object>>();

            String toPhone = '';
            String fileName = '';
            String documentUrl = '';
            String contactId = '';
            String message = '';
            String timeOfMessage = '';
            String fileData = '';       
            String messageBody = '';     

            for (Map<String, Object> doc : documents) {
                System.debug('doc--->'+doc);
                Map<String,Object> whatsappMap = new Map<String,Object>();

                toPhone = (String) doc.get('toPhone');
                // Map<String,Object> fileDataMap = new Map<String,Object>();                
                // fileName = (String) fileDataMap.get('fileName');
                documentUrl = (String) doc.get('documentUrl');
                contactId = (String) doc.get('contactId');
                message = (String) doc.get('message');
                timeOfMessage = (String) doc.get('timeOfMessage');
                fileData = (String) doc.get('fileData');     
                Map<String, Object> fileDataMap = (Map<String, Object>) JSON.deserializeUntyped(fileData);
                fileName = (String) fileDataMap.get('fileName');
                messageBody = '{'+
                '    "messaging_product": "whatsapp",'+
                '    "recipient_type": "individual",'+
                '    "to": "'+toPhone+'",'+
                '    "type": "document",'+
                '    "document": {'+
                '        "link": "'+documentUrl+'",'+
                '        "filename": "' + fileName + '"' +
                '    }'+
                '}';  
                whatsappMap.put('toPhone',toPhone);
                whatsappMap.put('fileName',fileName);
                whatsappMap.put('documentUrl',documentUrl);
                whatsappMap.put('contactId',contactId);
                whatsappMap.put('message',message);
                whatsappMap.put('timeOfMessage',timeOfMessage);
                whatsappMap.put('fileData',fileData);
                whatsappMap.put('messageBody',messageBody);

                messagesToSend.add(whatsappMap);
                
            }
            
            sendWhatsAppMessageMap(messagesToSend);
            // sendWhatsAppMessage(toPhone, messageBody, contactId, fileName, timeOfMessage, fileData);
            return true;
        } catch (Exception e) {
            // ErrorHandler.insert_errordata(e, 'WhatsAppIntegration', 'sendDocumentByUrl', e.getMessage());
            System.debug('Error in sendDocumentByUrl: ' + e.getMessage() + '\n' + e + '\n Exception line no: ' + e.getLineNumber());
            return false;
        }
    }

    @AuraEnabled
    public static Boolean sendAudioByUrl1(List<Map<String, Object>> documents) {
        try {

            List<Map<String, Object>> messagesToSend = new List<Map<String, Object>>();

            String toPhone = '';
            String fileName = '';
            String audiourl = '';
            String contactId = '';
            String timeOfMessage = '';
            String fileData = '';       
            String messageBody = '';     
            String message = '';     

            for (Map<String, Object> doc : documents) {

                Map<String,Object> whatsappMap = new Map<String,Object>();

                toPhone = (String) doc.get('toPhone');
                fileName = (String) doc.get('fileName');
                audiourl = (String) doc.get('audioUrl');
                contactId = (String) doc.get('contactId');                
                timeOfMessage = (String) doc.get('timeOfMessage');
                fileData = (String) doc.get('fileData');       
                message = (String) doc.get('message');
                messageBody = '{'+
                '    "messaging_product": "whatsapp",'+
                '    "recipient_type": "individual",'+
                '    "to": "'+toPhone+'",'+
                '    "type": "audio",'+
                '    "audio": {'+
                '        "link": "'+audiourl+'"'+                       
                '    }'+
                '}';  
                whatsappMap.put('toPhone',toPhone);                
                whatsappMap.put('audiourl',audiourl);
                whatsappMap.put('contactId',contactId);
                whatsappMap.put('message',message);
                whatsappMap.put('timeOfMessage',timeOfMessage);
                whatsappMap.put('fileData',fileData);
                whatsappMap.put('messageBody',messageBody);
                

                messagesToSend.add(whatsappMap);
                
            }
            
            sendWhatsAppMessageMap(messagesToSend);

            // String messageBody = '{'+
            // '    "messaging_product": "whatsapp",'+
            // '    "recipient_type": "individual",'+
            // // '    "to": "'+toPhone+'",'+
            // '    "type": "audio",'+
            // '    "audio": {'+
            // // '        "link": "'+audioUrl+'"'+
            // '    }'+
            // '}';
            // sendWhatsAppMessage(toPhone, messageBody, contactId, fileName, timeOfMessage, fileData);
            return true;
        } catch (Exception e) {
            // ErrorHandler.insert_errordata(e, 'WhatsAppIntegration', 'sendAudioByUrl', e.getMessage());
            System.debug('Error in sendAudioByUrl: ' + e.getMessage() + '\n' + e + '\n Exception line no: ' + e.getLineNumber());
            return false;
        }
    }

    public static void sendWhatsAppMessageMap(List<Map<String, Object>> documents) {

        try{
 
        String accessToken = '';
        String endpoint = '';
        String messageText = '';
    
        WhatsAppConfig__c config = (WhatsAppConfig__c) getSettings();

        accessToken = config.WB_AccessToken__c;
        // endpoint = config.whatsapp_endpoint__c;
        
        String whatsapptemplateName = '';
        List<Template__c> templateReclst = new List<Template__c>();
        Map<String,Id> templateMap = new Map<String,Id>();
        Set<String> templateNames = new Set<String>();
        
        List<Chat__c> chatReclst = new List<Chat__c>();
        
        for(Map<String, Object> doc : documents){
            String messageBody = (String)doc.get('messageBody');
            
            System.debug('messageBody-->'+messageBody);
            Map<String, Object> parsedJson = (Map<String, Object>) JSON.deserializeUntyped(messageBody);
            String messagetypeValue = (String) parsedJson.get('type');
            if(messagetypeValue == 'template'){
                Map<String, Object> retrievedTemplateMap = (Map<String, Object>) parsedJson.get('template');
                messageText = (String)doc.get('templateName');
                whatsapptemplateName = (String) retrievedTemplateMap.get('name');
                System.debug('whatsapptemplateName--->'+whatsapptemplateName);
                if(String.isNotBlank(whatsapptemplateName)){
                    templateNames.add(whatsapptemplateName);
                }                
            }
        }

        if(!templateNames.isEmpty()){
            templateReclst = [SELECT Id,Name FROM Template__c WHERE Name IN: templateNames WITH SECURITY_ENFORCED ORDER BY CreatedDate DESC LIMIT 1 ];
            if(!templateReclst.isEmpty()){
                for(Template__c template : templateReclst){
                    if(!templateMap.containsKey(template.Name)){
                        templateMap.put(template.Name, template.Id);
                    }
                    templateMap.get(template.Name);
                }
            }
        }

        for(Map<String, Object> doc : documents){
            if((accessToken != '') && (endpoint != '')){
                String messageBody = (String)doc.get('messageBody');
                System.debug('Body ::' + messageBody);
                messageText = (String)doc.get('fileName');
                System.debug('messageText ::' + messageText);
                String timeOfMessage = (String)doc.get('timeOfMessage');
                System.debug('timeOfMessage ::' + timeOfMessage);
                String contactId = (String)doc.get('contactId');
                System.debug('contactId ::' + contactId);
                String fileData = (String)doc.get('fileData');
                System.debug('fileData ::' + fileData);
                
                // Parse the JSON string
                Map<String, Object> parsedJson = (Map<String, Object>) JSON.deserializeUntyped(messageBody);
                String messagetypeValue = (String) parsedJson.get('type');
                System.debug('Type: ' + messagetypeValue);
                String templateName = '';
                Id templateId = null;

                if(messagetypeValue == 'template'){
                    // Map<String, Object> retrievedTemplateMap = (Map<String, Object>) parsedJson.get('template');
                    // templateName = (String) retrievedTemplateMap.get('name');
                    
                    // Template__c templateRecord = [SELECT Id FROM 	Template__c WHERE Name = :templateName WITH SECURITY_ENFORCED LIMIT 1];

                    if (!templateReclst.isEmpty()) {
                        templateId = templateMap.get(templateName);
                    }
                }
                HttpRequest httpReq = new HttpRequest();
                httpReq.setEndpoint(endpoint);
                httpReq.setMethod('POST');
                httpReq.setHeader('Content-Type', 'application/json');
                httpReq.setHeader('Authorization', 'Bearer '+ accessToken);
                httpReq.setBody(messageBody);
                System.debug('request :: ' + httpReq);
                DateTime myDateTime = DateTime.now();
                Date formattedDate = myDateTime.date();

                Http http = new Http();
                try {
                    HttpResponse response = http.send(httpReq);
                    System.debug('Response Body ==>' + response.getBody());
                    System.debug('Response Code ==>' + response.getStatusCode());
                    Integer statusCode = response.getStatusCode();                
                    if(response != null && statusCode == 200){
                        String reponseBody = response.getBody();
                        Map<String, Object> jsonMap = (Map<String, Object>) JSON.deserializeUntyped(reponseBody);
                        List<Object> messages = (List<Object>) jsonMap.get('messages');
                        Map<String, Object> firstMessage = (Map<String, Object>) messages[0];
                        String whatsAppMessageID = (String) firstMessage.get('id');
                        System.debug('WhatsApp Message ID: ' + whatsAppMessageID);

                        Chat__c whatsappMsg = new Chat__c(
                            Type_of_Message__c = 'Outbound Message',
                            Message__c = messageText,
                            Time_of_Message__c = timeOfMessage, 
                            Message_Type__c = messagetypeValue,
                            WhatsAppMessageID__c = whatsAppMessageID,
                            Contact__c = contactId,
                            Date_of_Message__c = formattedDate,
                            File_Data__c = fileData 
                        );
                        chatReclst.add(whatsappMsg);
                        
                        if(templateName != '' && messagetypeValue == 'template'){
                            whatsappMsg.Whatsapp_Template__c = templateId;
                        }
                        // if(Schema.sObjectType.Chat__c.isCreateable()){
                        //     insert whatsappMsg;
                        // }
                        System.debug('whatsappMsg ==> ' + whatsappMsg);
                    }else{
                        System.debug('Error in sending the message.');
                        // Contact contact = [SELECT Id, Name, OwnerId FROM Contact WHERE Id = :contactId LIMIT 1];
                        // sendNotificationForContact(contact);
                    }
                } catch (Exception e) {
                    // ErrorHandler.insert_errordata(e, 'WhatsAppIntegration', 'sendWhatsAppMessage', e.getMessage());
                    System.debug('Error in sendWhatsAppMessage: ' + e.getMessage() + '\n' + e + '\n Exception line no: ' + e.getLineNumber());
                }
            } else{
                System.debug('Failed fetched access token and endpoint from custom labels');
            }
        }
        if(!chatReclst.isEmpty() && Schema.sObjectType.Chat__c.isCreateable()){
            insert chatReclst;
        }
    }catch(Exception e){
        System.debug('Error in sendWhatsAppMessageMap: ' + e.getMessage() + '\n' + e + '\n Exception line no: ' + e.getLineNumber());
    }

    }

}