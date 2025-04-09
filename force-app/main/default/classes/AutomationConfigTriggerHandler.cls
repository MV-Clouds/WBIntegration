/**
 * @description       : 
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             : 
 * @last modified on  : 04-08-2025
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
**/
public without sharing class AutomationConfigTriggerHandler {
    private List<MVWB__Chat__c> recordNewList = new List<MVWB__Chat__c>();
    private List<MVWB__Chat__c> recordOldList = new List<MVWB__Chat__c>();
    private Map<Id, MVWB__Chat__c> recordNewMap = new Map<Id, MVWB__Chat__c>();
    private Map<Id, MVWB__Chat__c> recordOldMap = new Map<Id, MVWB__Chat__c>();
    private Boolean isInsert;
    private Boolean isUpdate;
    private Boolean isDelete = false;
    private Boolean isUndelete = false;
    private static final String CLASS_NAME = 'AutomationConfigTriggerHandler';

    public AutomationConfigTriggerHandler( List<MVWB__Chat__c> newList,  List<MVWB__Chat__c> oldList, Map<Id, MVWB__Chat__c> newMap, Map<Id, MVWB__Chat__c> oldMap, Boolean isInsert, Boolean isUpdate, Boolean isDelete, Boolean isUndelete) {
        this.recordNewList = newList;
        this.recordOldList = oldList;
        this.recordNewMap = newMap;
        this.recordOldMap = oldMap;
        this.isInsert = isInsert;
        this.isUpdate = isUpdate;
        this.isDelete = isDelete;
        this.isUndelete = isUndelete;
    }

    public void filterAndProcessValidChats() {
        List<MVWB__Chat__c> validChats = new List<MVWB__Chat__c>();
        Set<Id> replyToIds = new Set<Id>();

        for (MVWB__Chat__c newChat : (List<MVWB__Chat__c>)recordNewList) {
            if (newChat.MVWB__Type_of_Message__c == 'Inbound Messages' && newChat.MVWB__Reply_to__c != null) {
                replyToIds.add(newChat.MVWB__Reply_to__c);
            }
        }

        Map<Id, MVWB__Chat__c> parentChatMap = new Map<Id, MVWB__Chat__c>();
        if (!replyToIds.isEmpty()) {
            for (MVWB__Chat__c parent : [
                SELECT Id, MVWB__Whatsapp_Template__r.MVWB__WBButton_Body__c
                FROM MVWB__Chat__c
                WHERE Id IN :replyToIds
            ]) {
                parentChatMap.put(parent.Id, parent);
            }
        }

        for (MVWB__Chat__c newChat : (List<MVWB__Chat__c>)recordNewList) {
            if (isValidAutomationChat(newChat, parentChatMap.get(newChat.MVWB__Reply_to__c))) {
                validChats.add(newChat);
            }
        }

        if (!validChats.isEmpty()) {
            processAutomationConfiguration(validChats);
        } else {
            System.debug('No valid messages found (Button/Interactive & Inbound Message). Exiting trigger.');
        }
    }

    private Boolean isValidAutomationChat(MVWB__Chat__c newChat, MVWB__Chat__c parentChat) {
        if (newChat.MVWB__Type_of_Message__c != 'Inbound Messages') {
            System.debug('Not an Inbound Message. Exiting. ' + newChat.MVWB__Message__c);
            return false;
        }

        String buttonType = null;

        if (newChat.MVWB__Reply_to__c != null && parentChat != null && parentChat.MVWB__Whatsapp_Template__r != null) {
            try {
                String buttonBody = parentChat.MVWB__Whatsapp_Template__r.MVWB__WBButton_Body__c;
                buttonType = getButtonTypeByText(buttonBody, newChat.MVWB__Message__c);
                System.debug('Button Type: ' + buttonType);
            } catch (Exception e) {
                System.debug('Error parsing button JSON: ' + e.getMessage());
            }
        }

        return buttonType == 'QUICK_REPLY' || newChat.MVWB__Message_Type__c == 'interactive';
    }

    public static String getButtonTypeByText(String jsonInput, String buttonText) {
        try {
            // Deserialize JSON into a raw List of Objects
            List<Object> rawButtons = (List<Object>) JSON.deserializeUntyped(jsonInput);
    
            // Iterate and safely cast each item to Map<String, Object>
            for (Object rawBtn : rawButtons) {
                Map<String, Object> btn = (Map<String, Object>) rawBtn;
    
                if (btn.containsKey('text') && btn.get('text') == buttonText) {
                    return (String) btn.get('type'); // Return the button type
                }
            }
        } catch (Exception e) {
            System.debug('Error parsing JSON: ' + e.getMessage());
        }
        return 'Not Found'; // Return "Not Found" if no matching text is found
    }    

    public static void processAutomationConfiguration(List<MVWB__Chat__c> newChats) {
        System.debug('Handler method called');

        // Step 1: Collect context message IDs and filter relevant chats
        Set<String> contextMessageIds = new Set<String>();
        List<MVWB__Chat__c> potentialPathReplies = new List<MVWB__Chat__c>();

        for (MVWB__Chat__c newChat : newChats) {
            if (String.isNotBlank(newChat.MVWB__WhatsAppContextMessageID__c)) {
                contextMessageIds.add(newChat.MVWB__WhatsAppContextMessageID__c);
                if (String.isNotBlank(newChat.MVWB__Message__c)) {
                    potentialPathReplies.add(newChat);
                }
            }
        }

        if (contextMessageIds.isEmpty() || potentialPathReplies.isEmpty()) {
            System.debug('No valid replies found, exiting.');
            return;
        }
        System.debug('ContextMessageIds and PotentialPathReplies found');

        // Step 2: Get original messages and extract template IDs
        Map<String, MVWB__Chat__c> originalChatsMap = fetchOriginalChats(contextMessageIds);
        Set<String> templateIdsToCheck = extractTemplateIds(originalChatsMap);

        if (templateIdsToCheck.isEmpty()) {
            System.debug('No templates found, exiting.');
            return;
        }
        System.debug('Template found on orginal messages.');

        // Step 3: Map Templates to Automation IDs
        Map<String, Id> templateIdToAutomationIdMap = fetchAutomationMappings(templateIdsToCheck);
        if (templateIdToAutomationIdMap.isEmpty()) {
            System.debug('No matching Automations found, exiting.');
            return;
        }
        System.debug('Matching Automation records found.');

        // Step 4: Fetch Automation Paths
        Map<Id, Map<String, Automation_Path__c>> automationPathsMap = fetchAutomationPaths(templateIdToAutomationIdMap);
        if (automationPathsMap.isEmpty()) {
            System.debug('No Automation Paths found.');
        }
        System.debug('Automation Path records found.');

        // Step 5: Process matching chats and send responses
        processMatchingChats(potentialPathReplies, originalChatsMap, templateIdToAutomationIdMap, automationPathsMap);
    }

    private static Map<String, MVWB__Chat__c> fetchOriginalChats(Set<String> contextMessageIds) {
        Map<String, MVWB__Chat__c> originalChatsMap = new Map<String, MVWB__Chat__c>();

        for (MVWB__Chat__c originalChat : [
            SELECT Id, MVWB__Whatsapp_Template__c, MVWB__WhatsAppMessageId__c
            FROM MVWB__Chat__c
            WHERE MVWB__WhatsAppMessageId__c IN :contextMessageIds
        ]) {
            if (originalChat.MVWB__WhatsAppMessageId__c != null) {
                originalChatsMap.put(originalChat.MVWB__WhatsAppMessageId__c, originalChat);
            }
        }
        return originalChatsMap;
    }

    private static Set<String> extractTemplateIds(Map<String, MVWB__Chat__c> originalChatsMap) {
        Set<String> templateIdsToCheck = new Set<String>();

        for (MVWB__Chat__c chat : originalChatsMap.values()) {
            if (String.isNotBlank(chat.MVWB__Whatsapp_Template__c)) {
                templateIdsToCheck.add(chat.MVWB__Whatsapp_Template__c);
            }
        }
        return templateIdsToCheck;
    }

    private static Map<String, Id> fetchAutomationMappings(Set<String> templateIdsToCheck) {
        Map<String, Id> templateIdToAutomationIdMap = new Map<String, Id>();

        for (Automation__c automation : [
            SELECT Id, WB_Template__c
            FROM Automation__c
            WHERE WB_Template__c IN :templateIdsToCheck
        ]) {
            if (automation.WB_Template__c != null) {
                templateIdToAutomationIdMap.put(automation.WB_Template__c, automation.Id);
            }
        }
        return templateIdToAutomationIdMap;
    }

    private static Map<Id, Map<String, Automation_Path__c>> fetchAutomationPaths(Map<String, Id> templateIdToAutomationIdMap) {
        Map<Id, Map<String, Automation_Path__c>> automationPathsMap = new Map<Id, Map<String, Automation_Path__c>>();
        Set<Id> relevantAutomationIds = new Set<Id>(templateIdToAutomationIdMap.values());

        for (Automation_Path__c path : [
            SELECT Id, Automation__c, Button_Value__c, Action_Template__c, Action_Type__c, Action_Email_Template__c, Object_Name__c, Field_Mapping__c
            FROM Automation_Path__c
            WHERE Automation__c IN :relevantAutomationIds
        ]) {
            if (path.Automation__c != null && String.isNotBlank(path.Button_Value__c)) {
                String normalizedButtonValue = path.Button_Value__c.toLowerCase().trim();

                if (!automationPathsMap.containsKey(path.Automation__c)) {
                    automationPathsMap.put(path.Automation__c, new Map<String, Automation_Path__c>());
                }
                automationPathsMap.get(path.Automation__c).put(normalizedButtonValue, path);
            }
        }
        return automationPathsMap;
    }

    private static void processMatchingChats(
        List<MVWB__Chat__c> potentialPathReplies,
        Map<String, MVWB__Chat__c> originalChatsMap,
        Map<String, Id> templateIdToAutomationIdMap,
        Map<Id, Map<String, Automation_Path__c>> automationPathsMap
    ) {
        for (MVWB__Chat__c newChat : potentialPathReplies) {
            
            MVWB__Chat__c originalChat = originalChatsMap.get(newChat.MVWB__WhatsAppContextMessageID__c);

            if (originalChat != null && String.isNotBlank(originalChat.MVWB__Whatsapp_Template__c)) {
                
                Id automationId = templateIdToAutomationIdMap.get(originalChat.MVWB__Whatsapp_Template__c);

                if (automationId != null && automationPathsMap.containsKey(automationId)) {
                    
                    String normalizedMessageBody = newChat.MVWB__Message__c.toLowerCase().trim();
                    Contact contactRecord = [SELECT Id FROM Contact WHERE Phone = :newChat.MVWB__Phone__c LIMIT 1];
                    
                    Id contactId = contactRecord != null ? contactRecord.Id : null;

                    Map<String, Automation_Path__c> pathsForThisAutomation = automationPathsMap.get(automationId);

                    if (pathsForThisAutomation.containsKey(normalizedMessageBody)) {
                        
                        // *** If ALL CONDITIONS MET ***
                        Automation_Path__c matchingPath = pathsForThisAutomation.get(normalizedMessageBody);

                        System.debug('Matched Path: ' + matchingPath.Id);
                        System.debug('Chat ID (inserting) is a reply to Template (' + originalChat.MVWB__Whatsapp_Template__c + ') with Automation (' + automationId + ') and matching Path (' + matchingPath.Id + ') found via Button Value (' + matchingPath.Button_Value__c + ').');

                        if (matchingPath.Action_Type__c == 'Send Message') {

                            Map<String, Object> tempData = getTemplateData(matchingPath.Action_Template__c, contactId, 'Contact'); //Change
                            System.debug('tempData = ' + tempData);
                            String jsonData = generatePayloadFromTemplateData(tempData, newChat.MVWB__Phone__c);
                            System.debug('jsonData = ' + jsonData);
                            // String phone = '' + newChat.MVWB__Phone__c;
                            // String actionTemplate = matchingPath.Action_Template__c;
                            Map<String, String> chatData = new Map<String, String>();
                            chatData.put('message', '');
                            chatData.put('templateId', String.valueOf(matchingPath.Action_Template__c));
                            chatData.put('messageType', 'Template');
                            chatData.put('replyToChatId', '');
                            chatData.put('phoneNumber', String.valueOf(newChat.MVWB__Phone__c));
                            MVWB__Chat__c newChatRecord = createChat(chatData);
                            System.debug('newChatRecord = ' + newChatRecord);
                            sendWhatsAppMessage(jsonData, newChatRecord.Id);
                            MVWB__Chat__c chatToUpdate = new MVWB__Chat__c(
                                Id = newChatRecord.Id,
                                MVWB__Date_of_Message__c = Date.today(),
                                MVWB__Message_Status__c = 'Sent',
                                MVWB__Message_Sent_Time__c = System.now()
                            );
                            update chatToUpdate;

                        } else if (matchingPath.Action_Type__c == 'Send Email') {

                            Contact contactRecord1 = [SELECT Id, Email FROM Contact WHERE Phone = :newChat.MVWB__Phone__c LIMIT 1];
                            
                            if (contactRecord1 != null && String.isNotBlank(contactRecord1.Email) && String.isNotBlank(matchingPath.Action_Email_Template__c)) {

                                Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
                                email.setToAddresses(new String[] { contactRecord1.Email });
                                email.setTemplateId(matchingPath.Action_Email_Template__c);
                                email.setTargetObjectId(contactRecord1.Id);
                                email.setTreatTargetObjectAsRecipient(true);
                                email.setSaveAsActivity(false);

                                try {
                                    Messaging.sendEmail(new Messaging.SingleEmailMessage[] { email });
                                    System.debug('Email sent to: ' + contactRecord1.Email);

                                } catch (Exception e) {
                                    System.debug('Failed to send email: ' + e.getMessage());
                                }
                            } else {
                                System.debug('Email or TemplateId missing. Cannot send email.');
                            }

                        } else if (matchingPath.Action_Type__c == 'Create a Record') {
                            
                            String flowResponseJson = newChat.MVWB__Flow_Response_JSON__c;
                            String fieldMappingJson = matchingPath.Field_Mapping__c;
                            String objectName = matchingPath.Object_Name__c;

                            if (String.isNotBlank(flowResponseJson) &&
                                String.isNotBlank(fieldMappingJson) &&
                                String.isNotBlank(objectName)) {

                                try {
                                    // Parse flow response and field mapping
                                    Map<String, Object> flowResponse = (Map<String, Object>) JSON.deserializeUntyped(flowResponseJson);
                                    Map<String, Object> fieldMapping = (Map<String, Object>) JSON.deserializeUntyped(fieldMappingJson);

                                    // Dynamically create SObject instance
                                    SObject recordToInsert = (SObject) Type.forName('Schema.' + objectName).newInstance();

                                    // Loop through flow fields and set values to corresponding object fields
                                    for (String flowField : fieldMapping.keySet()) {
                                        String objectField = String.valueOf(fieldMapping.get(flowField));

                                        if (flowResponse.containsKey(flowField)) {
                                            Object fieldValue = flowResponse.get(flowField);
                                            recordToInsert.put(objectField, fieldValue);
                                        }
                                    }

                                    insert recordToInsert;
                                    System.debug('Record of type ' + objectName + ' inserted successfully: ' + recordToInsert);

                                } catch (Exception e) {
                                    System.debug('Error processing flow response for record creation: ' + e.getMessage());
                                }
                            } else {
                                System.debug('Missing required data: Flow Response, Field Mapping, or Object Name');
                            }
                        }

                    } else {
                        System.debug('No matching path found for message: "' + newChat.MVWB__Message__c + '"');
                    }
                }
            }
        }
    }

    public static List<MVWB__WBConnect_Configuration__mdt> wbConfig = MVWB__WBConnect_Configuration__mdt.getAll().values(); 

    public static Map<String, object> getTemplateData(String templateId, String recordId, String objectApiName){
        try {
            Map<String, Object> templateData = new Map<String, Object>();
            List<MVWB__Template__c> templates = new List<MVWB__Template__c>();

            // Fetch templates with matching child variables
            Set<Id> matchingTemplateIds = new Set<Id>();
            for (MVWB__Template_Variable__c tv : [SELECT MVWB__Template__c FROM MVWB__Template_Variable__c WHERE MVWB__Object_Name__c = :objectApiName]) {
                matchingTemplateIds.add(tv.MVWB__Template__c);
            }

            // Fetch template details
            if (!matchingTemplateIds.isEmpty()) {
                templates.addAll([
                    SELECT Id, MVWB__Template_Name__c, MVWB__WBButton_Body__c, MVWB__Button_Label__c, MVWB__Button_Type__c, MVWB__WBFooter_Body__c, MVWB__WBHeader_Body__c, MVWB__Header_Type__c, MVWB__Language__c, MVWB__WBTemplate_Body__c, MVWB__Template_Category__c, MVWB__Template_SubCatagory__c, MVWB__Template_Type__c, MVWB__Template_Variable__c,
                        (SELECT Id, Name, MVWB__Field_Name__c, MVWB__Object_Name__c, MVWB__Type__c, MVWB__Alternate_Text__c FROM MVWB__WB_Template_Variables__r) FROM MVWB__Template__c WHERE Id = :templateId AND Id IN :matchingTemplateIds
                ]);
            }

            // Fetch templates without child variables
            List<MVWB__Template__c> templatesWithoutVariables = [
                SELECT Id, MVWB__Template_Name__c, MVWB__WBButton_Body__c, MVWB__Button_Label__c, MVWB__Button_Type__c, MVWB__WBFooter_Body__c, MVWB__WBHeader_Body__c, MVWB__Header_Type__c, MVWB__Language__c, MVWB__WBTemplate_Body__c, MVWB__Template_Category__c, MVWB__Template_SubCatagory__c, MVWB__Template_Type__c, MVWB__Template_Variable__c,
                    (SELECT Id, Name, MVWB__Field_Name__c, MVWB__Object_Name__c, MVWB__Type__c, MVWB__Alternate_Text__c FROM MVWB__WB_Template_Variables__r) FROM MVWB__Template__c WHERE Id = :templateId
            ];
            templates.addAll(templatesWithoutVariables);

            if(templates.size() > 0 && templates[0].MVWB__Template_Variable__c>0){
                MVWB__Template__c template= templates[0];
                Set<String> fieldSelectionCause = new Set<String>();
                for (MVWB__Template_Variable__c tv : template.MVWB__WB_Template_Variables__r) {
                    if (tv.MVWB__Object_Name__c == objectApiName) {
                        // If the object matches the queried object, add only the field name
                        fieldSelectionCause.add(tv.MVWB__Field_Name__c);
                    } else {
                        try {
                            // Check if the object supports relationships before adding related fields
                            fieldSelectionCause.add(tv.MVWB__Object_Name__c + '.' + tv.MVWB__Field_Name__c);
                        } catch (Exception ex) {
                            System.debug('Invalid relationship: ' + tv.MVWB__Object_Name__c + ' for ' + objectApiName);
                        }
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
                    for (MVWB__Template_Variable__c tv: template.MVWB__WB_Template_Variables__r) {
                        Object valueToReplace = '';
                        if (tv.MVWB__Object_Name__c == objectApiName) {  
                            // If the object matches the queried object (Lead, Contact, etc.), get the field directly  
                            valueToReplace = record.get(tv.MVWB__Field_Name__c);  
                        } else {  
                            // Check if the object supports relationships before querying related fields  
                            try {  
                                SObject relatedRecord = record.getSObject(tv.MVWB__Object_Name__c);  
                                valueToReplace = (relatedRecord != null) ? relatedRecord.get(tv.MVWB__Field_Name__c) : null;  
                            } catch (Exception ex) {  
                                System.debug('Invalid relationship: ' + tv.MVWB__Object_Name__c + ' for ' + objectApiName);  
                                valueToReplace = null;  
                            }  
                        }
                        if (tv.MVWB__Type__c == 'Header') {
                            headerVariables.add(valueToReplace != null ? valueToReplace.toString() : (tv.MVWB__Alternate_Text__c!= null ? tv.MVWB__Alternate_Text__c : ' '));
                            template.MVWB__WBHeader_Body__c = template.MVWB__WBHeader_Body__c.replace(tv.Name , valueToReplace != null ? valueToReplace.toString() : (tv.MVWB__Alternate_Text__c!= null ? tv.MVWB__Alternate_Text__c : ' ') );
                        }else if(tv.MVWB__Type__c == 'Body'){
                            bodyVariables.add(valueToReplace != null ? valueToReplace.toString() : (tv.MVWB__Alternate_Text__c!= null ? tv.MVWB__Alternate_Text__c : ' '));
                            template.MVWB__WBTemplate_Body__c = template.MVWB__WBTemplate_Body__c.replace(tv.Name , valueToReplace != null ? valueToReplace.toString() : (tv.MVWB__Alternate_Text__c!= null ? tv.MVWB__Alternate_Text__c : ' ') );
                        }
                    }
                }
                templateData.put('template', template);
                templateData.put('headerParams', headerVariables);
                templateData.put('bodyParams', bodyVariables);
                // templateData.put('template', templates[0]);
                return templateData;
            } else if (templates.size() > 0 && templates[0].MVWB__Template_Variable__c < 1){
                templateData.put('template', templates[0]);
                return templateData;
            } else {
                return null;
            }
        } catch (Exception e) {
            // MVWB__ExceptionHandler.logException(new Map<String, Object>{'className' => 'AutomationConfigTriggerHandler', 'methodName' => 'getTemplateData', 'exceptionObj' => e, 'isApiException' => false, 'statusCode' => null, 'chatId' => null, 'moreDetails' =>  e.getMessage(), 'apiResponse' => null});
        }
        return null;
    }

    // Method to Call createJSONBody Using Template Data
    public static String generatePayloadFromTemplateData(Map<String, Object> templateData, String to) {
        try {
            MVWB__Template__c template = (MVWB__Template__c)templateData.get('template'); // Cast to MVWB__Template__c
            Map<String, Object> data = new Map<String, Object>();

            data.put('templateName', template.MVWB__Template_Name__c);
            data.put('languageCode', template.MVWB__Language__c);
            data.put('headerImageURL', template.MVWB__WBHeader_Body__c);
            data.put('headerType', template.MVWB__Header_Type__c);
            data.put('headerParameters', (List<Object>)templateData.get('headerParams'));
            data.put('bodyParameters', (List<Object>)templateData.get('bodyParams'));
            if(template.MVWB__WBButton_Body__c != null){
                // data.put('buttonValue', (List<Map<String, Object>>)JSON.deserializeUntyped(template.MVWB__WBButton_Body__c));
                Object rawData = JSON.deserializeUntyped(template.MVWB__WBButton_Body__c);
                List<Object> dataList = (List<Object>) rawData;

                // Convert each entry to a Map<String, Object>
                List<Map<String, Object>> finalList = new List<Map<String, Object>>();
                for (Object item : dataList) {
                    finalList.add((Map<String, Object>) item);
                }

                System.debug(finalList);
                data.put('buttonValue', finalList);
            } else {
                data.put('buttonValue', null);
            }
            return createJSONBody(to, 'template', data);
        } catch (Exception e) {
            throw new AuraHandledException('Exception in generatePayloadFromTemplateData - ' + e.getMessage());
        }
    }

    public static String createJSONBody(String to, String type, Map<String, Object> data) {
        try {
            System.debug(data);
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
            System.debug(headerParameters);
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
            if (bodyParameters != null && bodyParameters.size() > 0) {
                List<Map<String, Object>> bodyParams = new List<Map<String, Object>>();
                
                for (Object param : bodyParameters) {
                    bodyParams.add(new Map<String, Object>{ 'type' => 'text', 'text' => (String)param });
                }
                
                components.add(new Map<String, Object>{ 'type' => 'body', 'parameters' => bodyParams });
            }

            // Button Parameters
            List<Map<String, Object>> buttonValue = (List<Map<String, Object>>)data.get('buttonValue');
            if (buttonValue != null && buttonValue.size() > 0) {
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
                        when else {
                            System.debug('Unknown button type: ' + buttonType);
                        }
                    }
                    index++;
                }
            }

            // Add Components to Template
            if (components.size() > 0) {
                template.put('components', components);
            }

            payload.put('template', template);
            return JSON.serialize(payload);
        } catch (Exception e) {
            System.debug('Error in createJSONBody: ' + e.getMessage());
            return null;
        }
    }

    @future(callout=true)
    public static void sendWhatsappMessage(String jsonData, String chatId) {
        Map<String, Object> resultMap = new Map<String, Object>{};
        MVWB__Chat__c chat = new MVWB__Chat__c(Id = chatId);
        try {
            HttpRequest httpReq = new HttpRequest();
            resultMap.put('errorMessage', null);
            // List<WBConnect_Configuration__mdt> wbConfig = WBConnect_Configuration__mdt.getAll().values(); 
            if(wbConfig==null || wbConfig.isEmpty()){
                update chat;
                resultMap.put('errorMessage', 'METADATA_ERROR');
                resultMap.put('chat', chat);
                // return resultMap;
            }
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
                MVWB__Chat__c chatToSend = [SELECT Id, MVWB__Type_of_Message__c, MVWB__WhatsAppMessageId__c, MVWB__Message__c, MVWB__Message_Status__c, MVWB__Message_Type__c, MVWB__Reply_To__c, MVWB__Reaction__c, MVWB__Whatsapp_Template__c, MVWB__Whatsapp_Template__r.Name, CreatedDate, MVWB__Last_Interaction_Date__c, MVWB__Phone__c FROM MVWB__Chat__c WHERE Id =:chatId LIMIT 1];
                chatToSend.MVWB__Message_Status__c = 'Sent';
                chatToSend.MVWB__WhatsAppMessageId__c = whatsAppMessageID;
                update chatToSend;
                MVWB__Chat_Message__e newChatEvent = new MVWB__Chat_Message__e();
                newChatEvent.MVWB__Chat_Data__c = JSON.serialize(chatToSend);
                newChatEvent.MVWB__Type__c = 'new';
                // newChatEvent.ContactId__c = whatsappChat.Contact__c;
                EventBus.publish(newChatEvent);
            }else{
                System.debug('Error sending WhatsApp Message: '+response.getBody());
                // MVWB__ExceptionHandler.logException(new Map<String, Object>{'className' => 'AutomationConfigTriggerHandler', 'methodName' => 'sendWhatsappMessage', 'exceptionObj' => null, 'isApiException' => true, 'statusCode' => statusCode, 'chatId' => chatId, 'moreDetails' => 'API Exception while sending a message', 'apiResponse' => JSON.serialize(response.getBody()) });
            }

            update chat;
            chat = [SELECT Id, MVWB__Type_of_Message__c, MVWB__WhatsAppMessageId__c, MVWB__Message__c, MVWB__Message_Status__c, MVWB__Message_Type__c, MVWB__Reply_To__c, MVWB__Reaction__c, MVWB__Whatsapp_Template__c, MVWB__Whatsapp_Template__r.MVWB__Template_Name__c, CreatedDate, MVWB__Last_Interaction_Date__c FROM MVWB__Chat__c WHERE Id =:chat.Id];
            resultMap.put('chat', chat);
            // return resultMap;

        } catch (Exception e) {
            // MVWB__ExceptionHandler.logException(new Map<String, Object>{'className' => 'AutomationConfigTriggerHandler', 'methodName' => 'sendWhatsappMessage', 'exceptionObj' => e, 'isApiException' => false, 'statusCode' => null, 'chatId' => chatId, 'moreDetails' => e.getMessage(), 'apiResponse' => null });
        }
        resultMap.put('chat', chat);
        // return resultMap;
    }

    public static MVWB__Chat__c createChat(Map<String, String> chatData ){
        try {

            String message = chatData.get('message');
            String templateId = chatData.get('templateId');
            String messageType = chatData.get('messageType');
            String replyToChatId = chatData.get('replyToChatId');
            String phoneNumber = chatData.get('phoneNumber');

            MVWB__Chat__c chat = new MVWB__Chat__c();
            chat.MVWB__Message__c = message;
            chat.MVWB__Whatsapp_Template__c = templateId;
            chat.MVWB__Phone__c = phoneNumber;
            chat.MVWB__Type_of_Message__c	= 'OutBound Messages';
            chat.MVWB__Message_Status__c = 'Sent';
            chat.MVWB__Message_Type__c = messageType;
            // chat.MVWB__Reply_To__c = replyToChatId;

            insert chat;
            System.debug('chat:- '+chat.Id);
            chat = [SELECT Id, MVWB__Type_of_Message__c, MVWB__WhatsAppMessageId__c, MVWB__Message__c, MVWB__Message_Status__c, MVWB__Message_Type__c, MVWB__Reply_To__c, MVWB__Reaction__c, MVWB__Whatsapp_Template__c, MVWB__Whatsapp_Template__r.MVWB__Template_Name__c, CreatedDate, MVWB__Last_Interaction_Date__c FROM MVWB__Chat__c WHERE Id =:chat.Id];
            System.debug('chat:- '+chat);
            return chat;
        } catch (Exception e) {
            if(e.getMessage().contains('STORAGE_LIMIT_EXCEEDED')){
                throw new AuraHandledException('STORAGE_LIMIT_EXCEEDED');
            }
            // MVWB__ExceptionHandler.logException(new Map<String, Object>{'className' => 'ChatWindowController', 'methodName' => 'createChat', 'exceptionObj' => e, 'isApiException' => false, 'statusCode' => null, 'chatId' => null, 'moreDetails' =>  e.getMessage(), 'apiResponse' => null});
            return null;
        }
    }
}