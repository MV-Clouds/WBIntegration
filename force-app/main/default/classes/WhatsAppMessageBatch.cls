/**
* Class Name: WhatsAppMessageBatch
* Test Class: BroadcastMessageControllerTest
* Description: This class is used to send WhatsApp messages in bulk using a batch process.
* Created Date: 03 April 2025
* Created By: Harsh gandhi
*--------------------------------------------------------------------------------
**/

global with sharing class WhatsAppMessageBatch implements Database.Batchable<SObject>, Database.AllowsCallouts, Database.Stateful {
    
    global String templateId;
    global List<Chat__c> chatsToProcess;
    global String broadcastId;
    global String objectApiName;
    global List<Chat__c> chatsToUpdate = new List<Chat__c>();
    global static List<MVWB__WBConnect_Configuration__mdt> wbConfig = MVWB__WBConnect_Configuration__mdt.getAll().values(); 
    global String phoneField;

    // Constructor to pass Chat__c list and template data
    global WhatsAppMessageBatch(String tempId, List<Chat__c> chats, String brId, String objName, String phoneFieldName) {
        this.chatsToProcess = chats;
        this.templateId = tempId;
        this.broadcastId = brId;
        this.objectApiName = objName;
        this.phoneField = phoneFieldName;
    }

    /*
    *********************************************************
    @description     : This method is used to start the batch process and send whatsapp message.
    @param           : bc - Batchable context 
    @return          : Database.QueryLocator - query to fetch all the chat records
    ********************************************************
    */
    global Database.QueryLocator start(Database.BatchableContext bc) {
        try {
            List<Id> chatIds = new List<Id>();
            for (Chat__c chat : this.chatsToProcess) {
                chatIds.add(chat.Id);
            }
    
            return Database.getQueryLocator([SELECT Id, Phone__c, WhatsAppMessageId__c, Message_Status__c FROM Chat__c WHERE Id IN :chatIds]);
        } catch (Exception e) {
            return Database.getQueryLocator([SELECT Id FROM Chat__c WHERE Id = null]);
        }
    }

    /*
    *********************************************************
    @description     : This method is used to execute the batch process.
    @param           : bc - Batchable context
    @param           : scope - Scope of the batch process
    ********************************************************
    */
    global void execute(Database.BatchableContext bc, List<Chat__c> chatList) {
        try {
            Chat__c chat = new Chat__c();
            if(chatList.size() > 0){
                chat = chatList[0];
            }
            String phone = chat.Phone__c;
            
            String query = 'SELECT Id, ' + this.phoneField + ' FROM ' + this.objectApiName + ' WHERE ' + this.phoneField + ' =: phone LIMIT 1';

            List<sObject> records = Database.query(String.escapeSingleQuotes(query));
            if(records.size() > 0){
                Map<String, object> tempData = getTemplateData(this.templateId, records[0].Id, this.objectApiName);
                String jsonData = generatePayloadFromTemplateData(tempData, chat.Phone__c);
                List<Chat__c> cht = sendWhatsAppMessage(chat.Id, jsonData);
                if(cht.size() > 0){
                    this.chatsToUpdate.add(cht[0]);
                }
            }
        } catch (Exception e) {
            ExceptionHandler.logException(new Map<String, Object>{'className' => 'WhatsAppMessageBatch', 'finish' => 'execute', 'exceptionObj' => e, 'isApiException' => false, 'statusCode' => null, 'chatId' => null, 'moreDetails' =>  e.getMessage(), 'apiResponse' => null});
        }
    }

    /*
    *********************************************************
    @description     : This method is used to finish the batch process and update the chat records.
    @param           : bc - Batchable context
    @return          : void
    ********************************************************
    */
    
    global void finish(Database.BatchableContext bc) {
        try {
            if (this.chatsToUpdate.size() > 0) {
                Database.update(this.chatsToUpdate, false, AccessLevel.USER_MODE);
            }
    
            if(broadcastId != null){
                Broadcast__c br = new Broadcast__c(Id = this.broadcastId);
                br.Status__c = 'Completed';
                Database.update(br, false, AccessLevel.USER_MODE);
            }
        } catch (Exception e) {
            ExceptionHandler.logException(new Map<String, Object>{'className' => 'WhatsAppMessageBatch', 'finish' => 'getTemplateData', 'exceptionObj' => e, 'isApiException' => false, 'statusCode' => null, 'chatId' => null, 'moreDetails' =>  e.getMessage(), 'apiResponse' => null});
        }
    }

    /*
    *********************************************************
    @description     : This method is used to get the template data for the given templateId and recordId.
    @param           : templateId - Id of the template
    @param           : recordId - Id of the record
    @param           : objectApiName - API name of the object
    @return          : Map<String, object> - template data
    ********************************************************
    */
    @AuraEnabled
    global static Map<String, object> getTemplateData(String templateId, String recordId, String objectApiName){
        try {
            Map<String, Object> templateData = new Map<String, Object>();
            List<Template__c> templates = new List<Template__c>();

            // Fetch templates with matching child variables
            Set<Id> matchingTemplateIds = new Set<Id>();
            for (Template_Variable__c tv : [SELECT Template__c FROM Template_Variable__c WHERE Object_Name__c = :objectApiName WITH SECURITY_ENFORCED]) {
                matchingTemplateIds.add(tv.Template__c);
            }

            // Fetch template details
            if (!matchingTemplateIds.isEmpty()) {
                templates.addAll([
                    SELECT Id, Template_Name__c, WBButton_Body__c, Button_Label__c, Button_Type__c, WBFooter_Body__c, WBHeader_Body__c, Header_Type__c, Language__c, WBTemplate_Body__c, Template_Category__c, Template_SubCatagory__c, Template_Type__c, Template_Variable__c,
                        (SELECT Id, Name, Field_Name__c, Object_Name__c, Type__c, Alternate_Text__c FROM WB_Template_Variables__r) FROM Template__c WHERE Id = :templateId AND Id IN :matchingTemplateIds WITH SECURITY_ENFORCED
                ]);
            }

            // Fetch templates without child variables
            List<Template__c> templatesWithoutVariables = [
                SELECT Id, Template_Name__c, WBButton_Body__c, Button_Label__c, Button_Type__c, WBFooter_Body__c, WBHeader_Body__c, Header_Type__c, Language__c, WBTemplate_Body__c, Template_Category__c, Template_SubCatagory__c, Template_Type__c, Template_Variable__c,
                    (SELECT Id, Name, Field_Name__c, Object_Name__c, Type__c, Alternate_Text__c FROM WB_Template_Variables__r) FROM Template__c WHERE Id = :templateId WITH SECURITY_ENFORCED
            ];
            templates.addAll(templatesWithoutVariables);

            if(templates.size() > 0 && templates[0].Template_Variable__c>0){
                Template__c template= templates[0];
                Set<String> fieldSelectionCause = new Set<String>();
                for (Template_Variable__c tv : template.WB_Template_Variables__r) {
                    if (tv.Object_Name__c == objectApiName) {
                        // If the object matches the queried object, add only the field name
                        fieldSelectionCause.add(tv.Field_Name__c);
                    } else {
                        fieldSelectionCause.add(tv.Object_Name__c + '.' + tv.Field_Name__c);
                    }
                }
                
                if(fieldSelectionCause.size() < 1){
                    templateData.put('template', templates[0]);
                    return templateData;
                }

                String query = 'SELECT ' + String.join(fieldSelectionCause, ', ') + ' FROM ' + objectApiName + ' WHERE Id =:recordId';
                List<sObject> records = Database.query(String.escapeSingleQuotes(query));
                List<Object> headerVariables = new List<Object>();
                List<Object> bodyVariables = new List<Object>();
                if(records.size() > 0){
                    sObject record = records[0];
                    for (Template_Variable__c tv: template.WB_Template_Variables__r) {
                        Object valueToReplace = '';
                        if (tv.Object_Name__c == objectApiName) {  
                            // If the object matches the queried object (Lead, Contact, etc.), get the field directly  
                            valueToReplace = record.get(tv.Field_Name__c);  
                        } else {  
                            // Check if the object supports relationships before querying related fields  
                            try {  
                                SObject relatedRecord = record.getSObject(tv.Object_Name__c);  
                                valueToReplace = (relatedRecord != null) ? relatedRecord.get(tv.Field_Name__c) : null;  
                            } catch (Exception ex) {  
                                valueToReplace = null;  
                            }  
                        }
                        if (tv.Type__c == 'Header') {
                            headerVariables.add(valueToReplace != null ? valueToReplace.toString() : (tv.Alternate_Text__c!= null ? tv.Alternate_Text__c : ' '));
                            template.WBHeader_Body__c = template.WBHeader_Body__c.replace(tv.Name , valueToReplace != null ? valueToReplace.toString() : (tv.Alternate_Text__c!= null ? tv.Alternate_Text__c : ' ') );
                        }else if(tv.Type__c == 'Body'){
                            bodyVariables.add(valueToReplace != null ? valueToReplace.toString() : (tv.Alternate_Text__c!= null ? tv.Alternate_Text__c : ' '));
                            template.WBTemplate_Body__c = template.WBTemplate_Body__c.replace(tv.Name , valueToReplace != null ? valueToReplace.toString() : (tv.Alternate_Text__c!= null ? tv.Alternate_Text__c : ' ') );
                        }
                    }
                }
                templateData.put('template', template);
                templateData.put('headerParams', headerVariables);
                templateData.put('bodyParams', bodyVariables);
                // templateData.put('template', templates[0]);
                return templateData;
            } else if (templates.size() > 0 && templates[0].Template_Variable__c < 1){
                templateData.put('template', templates[0]);
                return templateData;
            } else {
                return null;
            }
        } catch (Exception e) {
            ExceptionHandler.logException(new Map<String, Object>{'className' => 'WhatsAppMessageBatch', 'methodName' => 'getTemplateData', 'exceptionObj' => e, 'isApiException' => false, 'statusCode' => null, 'chatId' => null, 'moreDetails' =>  e.getMessage(), 'apiResponse' => null});
        }
        return null;
    }

    /*
    *********************************************************
    @description     : This method is used to generate the JSON payload for the WhatsApp message.
    @param           : templateData - Map of template data
    @param           : to - Phone number to send the message
    @return          : String - JSON payload
    ********************************************************
    */
    global static String generatePayloadFromTemplateData(Map<String, Object> templateData, String to) {
        try {
            Template__c template = (Template__c)templateData.get('template'); // Cast to Template__c
            Map<String, Object> data = new Map<String, Object>();

            data.put('templateName', template.Template_Name__c);
            data.put('languageCode', template.Language__c);
            data.put('headerImageURL', template.WBHeader_Body__c);
            data.put('headerType', template.Header_Type__c);
            data.put('headerParameters', (List<Object>)templateData.get('headerParams'));
            data.put('bodyParameters', (List<Object>)templateData.get('bodyParams'));

            if(template.WBButton_Body__c != null){
                Object rawData = JSON.deserializeUntyped(template.WBButton_Body__c);
                List<Object> dataList = (List<Object>) rawData;

                // Convert each entry to a Map<String, Object>
                List<Map<String, Object>> finalList = new List<Map<String, Object>>();
                for (Object item : dataList) {
                    finalList.add((Map<String, Object>) item);
                }

                data.put('buttonValue', finalList);
            } else {
                data.put('buttonValue', null);
            }
            return createJSONBody(to, 'template', data);
        } catch (Exception e) {
            ExceptionHandler.logException(new Map<String, Object>{'className' => 'WhatsAppMessageBatch', 'methodName' => 'generatePayloadFromTemplateData', 'exceptionObj' => e, 'isApiException' => false, 'statusCode' => '', 'chatId' => null, 'moreDetails' => '', 'apiResponse' => '' });
            throw new AuraHandledException('Exception in generatePayloadFromTemplateData - ' + e.getMessage());
        }
    }

    /*
    *********************************************************
    @description     : This method is used to create the JSON body for the WhatsApp message.
    @param           : to - Phone number to send the message
    @param           : type - Type of the message
    @param           : data - Map of data to be included in the message
    @return          : String - JSON body
    ********************************************************
    */
    global static String createJSONBody(String to, String type, Map<String, Object> data) {
        try {
            // Base Payload Structure
            Map<String, Object> payload = new Map<String, Object>();
            payload.put('messaging_product', 'whatsapp');
            payload.put('to', to);
            payload.put('type', type);

            Map<String, Object> template = new Map<String, Object>();
            template.put('name', (String)data.get('templateName'));
            template.put('language', new Map<String, Object>{ 'code' => (String)data.get('languageCode') });

            List<Map<String, Object>> components = new List<Map<String, Object>>();

            // Header Parameters (Text)
            List<Object> headerParameters = (List<Object>)data.get('headerParameters');
            if (headerParameters != null && !headerParameters.isEmpty()) {
                List<Map<String, Object>> headerParams = new List<Map<String, Object>>();
                
                for (Object param : headerParameters) {
                    headerParams.add(new Map<String, Object>{ 'type' => 'text', 'text' => (String)param });
                }
                
                components.add(new Map<String, Object>{ 'type' => 'header', 'parameters' => headerParams });
            }

            // Header Type (Media)
            String headerType = (String)data.get('headerType');
            String headerImageURL = (String)data.get('headerImageURL');
            if (headerType != null && headerImageURL != null && headerType.toLowerCase() != 'text') {
                components.add(new Map<String, Object>{
                    'type' => 'header',
                    'parameters' => new List<Map<String, Object>>{
                        new Map<String, Object>{ 'type' => headerType.toLowerCase(), headerType.toLowerCase() => new Map<String, Object>{ 'link' => headerImageURL } }
                    }
                });
            }

            // Body Parameters
            List<Object> bodyParameters = (List<Object>)data.get('bodyParameters');
            if (bodyParameters != null && !bodyParameters.isEmpty()) {
                List<Map<String, Object>> bodyParams = new List<Map<String, Object>>();
                
                for (Object param : bodyParameters) {
                    bodyParams.add(new Map<String, Object>{ 'type' => 'text', 'text' => (String)param });
                }
                
                components.add(new Map<String, Object>{ 'type' => 'body', 'parameters' => bodyParams });
            }

            // Button Parameters
            List<Map<String, Object>> buttonValue = (List<Map<String, Object>>)data.get('buttonValue');
            if (buttonValue != null && !buttonValue.isEmpty()) {
                Integer index = 0;
                for (Map<String, Object> button : buttonValue) {
                    String buttonType = ((String)button.get('type')).toUpperCase();
                    switch on buttonType {
                        when 'PHONE_NUMBER' {
                            components.add(new Map<String, Object>{
                                'type' => 'button',
                                'sub_type' => 'voice_call',
                                'index' => index,
                                'parameters' => new List<Map<String, Object>>{
                                    new Map<String, Object>{ 'type' => 'text', 'text' => (String)button.get('phone_number') }
                                }
                            });
                        }
                        when 'COPY_CODE', 'COUPON_CODE' {
                            components.add(new Map<String, Object>{
                                'type' => 'button',
                                'sub_type' => 'copy_code',
                                'index' => index,
                                'parameters' => new List<Map<String, Object>>{
                                    new Map<String, Object>{ 'type' => 'coupon_code', 'coupon_code' => (String)data.get('bodyParaCode') }
                                }
                            });
                        }
                        when 'OTP' {
                            if (((String)button.get('otp_type')).toUpperCase() == 'COPY_CODE') {
                                components.add(new Map<String, Object>{
                                    'type' => 'button',
                                    'sub_type' => 'url',
                                    'index' => index,
                                    'parameters' => new List<Map<String, Object>>{
                                        new Map<String, Object>{ 'type' => 'text', 'text' => (String)data.get('bodyParaCode') }
                                    }
                                });
                            }
                        }
                        when 'FLOW' {
                            if (((String)button.get('otp_type')).toUpperCase() == 'FLOW') {
                                components.add(new Map<String, Object>{
                                    'type' => 'button',
                                    'sub_type' => 'flow',
                                    'index' => index,
                                    'parameters' => new List<Map<String, Object>>{
                                        new Map<String, Object>{ 'type' => 'payload', 'text' => 'PAYLOAD' }
                                    }
                                });
                            }
                        }
                    }
                    index++;
                }
            }

            // Add Components to Template
            if (!components.isEmpty()) {
                template.put('components', components);
            }

            payload.put('template', template);
            return JSON.serialize(payload);
        } catch (Exception e) {
            ExceptionHandler.logException(new Map<String, Object>{'className' => 'WhatsAppMessageBatch', 'methodName' => 'createJSONBody', 'exceptionObj' => e, 'isApiException' => false, 'statusCode' => '', 'chatId' => null, 'moreDetails' => '', 'apiResponse' => '' });
            return null;
        }
    }

    /*
    *********************************************************
    @description     : This method is used to send the WhatsApp message using the WhatsApp Business API.
    @param           : chatId - Id of the chat record
    @param           : jsonBody - JSON body to be sent
    @return          : List<Chat__c> - List of chat records
    ********************************************************
    */
    global static List<Chat__c> sendWhatsAppMessage(String chatId, String jsonBody) {
        try {
            List<Chat__c> chat = [SELECT Id, Phone__c, WhatsAppMessageId__c, Message_Status__c FROM Chat__c WHERE Id = :chatId LIMIT 1];
    
            HttpRequest httpReq = new HttpRequest();
            String accessToken = wbConfig[0].MVWB__Access_Token__c;
            String endpoint = 'https://graph.facebook.com/v21.0/' + wbConfig[0].MVWB__Phone_Number_Id__c + '/messages';
            httpReq.setEndpoint(endpoint);
            httpReq.setMethod('POST');
            httpReq.setHeader('Content-Type', 'application/json');
            httpReq.setHeader('Authorization', 'Bearer ' + accessToken);
            httpReq.setBody(jsonBody);
            Http http = new Http();
            HttpResponse response = http.send(httpReq);
            Integer statusCode = response.getStatusCode();
            if(response != null && statusCode == 200){
                String responseBody = response.getBody();
                Map<String, Object> jsonMap = (Map<String, Object>)JSON.deserializeUntyped(responseBody);
                List<Object> messages = (List<Object>)jsonMap.get('messages');
                Map<String, Object> firstMessage = (Map<String, Object>)messages[0];
                String whatsAppMessageID = (String) firstMessage.get('id');
                chat[0].WhatsAppMessageId__c = whatsAppMessageID;
                chat[0].Message_Status__c = 'Sent';
            }else{
                chat[0].Message_Status__c = 'Failed';
                ExceptionHandler.logException(new Map<String, Object>{'className' => 'WhatsAppMessageBatch', 'methodName' => 'sendWhatsAppMessage', 'exceptionObj' => null, 'isApiException' => true, 'statusCode' => statusCode, 'chatId' => chatId, 'moreDetails' => 'API Exception while sending a message', 'apiResponse' => JSON.serialize(response.getBody()) });
            }
            return chat;
        } catch (Exception e) {
            ExceptionHandler.logException(new Map<String, Object>{'className' => 'WhatsAppMessageBatch', 'methodName' => 'sendWhatsAppMessage', 'exceptionObj' => e, 'isApiException' => false, 'statusCode' => '', 'chatId' => chatId, 'moreDetails' => '', 'apiResponse' => '' });
            return null;
        }
    }
}