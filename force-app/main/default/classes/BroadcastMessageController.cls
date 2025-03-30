public with sharing class BroadcastMessageController {

    @AuraEnabled
    public static Map<String, Object> getObjectConfigs() {
        try {
            Map<String, Object> result = new Map<String, Object>();
            List<Object_Config__mdt> objectConfigList = [
                SELECT ChatWindowConfigInfo__c 
                FROM Object_Config__mdt WITH SECURITY_ENFORCED LIMIT 1
            ];
    
            if (objectConfigList.isEmpty()) {
                throw new AuraHandledException('Object Config not found!');
            }
    
            Map<String, Object> chatConfigData = (Map<String, Object>) JSON.deserializeUntyped(objectConfigList[0].ChatWindowConfigInfo__c);
            
            // Prepare return structure: { objectOptions: [...], configMap: {...} }
            List<Map<String, String>> objectOptions = new List<Map<String, String>>();
            Map<String, Map<String, String>> configMap = new Map<String, Map<String, String>>();
    
            for (String objectApiName : chatConfigData.keySet()) {
                objectOptions.add(new Map<String, String> {
                    'label' => objectApiName,
                    'value' => objectApiName
                });
                Map<String, Object> config = (Map<String, Object>) chatConfigData.get(objectApiName);
                configMap.put(objectApiName, new Map<String, String>{
                    'nameField' => (String) config.get('nameField'),
                    'phoneField' => (String) config.get('phoneField')
                });
            }
    
            result.put('objectOptions', objectOptions);
            result.put('configMap', configMap);
    
            return result;
    
        } catch (Exception e) {
            ExceptionHandler.logException(new Map<String, Object>{
                'className' => 'BroadcastMessageController',
                'methodName' => 'getObjectConfigs',
                'exceptionObj' => e,
                'isApiException' => false,
                'statusCode' => null,
                'chatId' => null,
                'moreDetails' => e.getMessage(),
                'apiResponse' => null
            });
            throw new AuraHandledException('Error fetching object configs: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static List<ListView> getListViewsForObject(String objectApiName) {
        try {
            return [SELECT Id, Name FROM ListView WHERE SobjectType = :objectApiName WITH SECURITY_ENFORCED ORDER BY LastViewedDate DESC];
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching list views: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static List<Broadcast_Group__c> getBroadcastGroups(){
        try {
            return [SELECT Id, Name, Count_of_Members__c, Description__c, Object_Name__c FROM Broadcast_Group__c WITH SECURITY_ENFORCED ORDER BY LastModifiedDate DESC];
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static void deleteBroadcastGroup(Id groupId) {
        try {
            // Ensure user has delete permission
            if (!Schema.sObjectType.Broadcast_Group__c.isDeletable()) {
                throw new AuraHandledException('Insufficient permissions to delete this record.');
            }
            
            // Query the record with security enforced
            Broadcast_Group__c groupToDelete = [
                SELECT Id FROM Broadcast_Group__c 
                WHERE Id = :groupId 
                WITH SECURITY_ENFORCED 
                LIMIT 1
            ];
            
            if (groupToDelete == null) {
                throw new AuraHandledException('There was a problem deleting the record. ' + groupId);
            }
            
            delete groupToDelete;
        } catch (Exception e) {
            throw new AuraHandledException('An unexpected error occurred: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static List<Broadcast__c> getBroadcastRecs(){
        try {
            return [SELECT Id, Name, Broadcast_Group__r.Name, Recipient_Count__c, Status__c, Total_Sent__c, Total_Delivered__c, Total_Read__c, Failed__c FROM Broadcast__c WITH SECURITY_ENFORCED];
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static Map<String, List<Template__c>> getTemplatesByObject() {
        Map<String, List<Template__c>> objectTemplateMap = new Map<String, List<Template__c>>();
    
        try {
            // Fetch all templates with their related object names from Template_Variable__c
            List<Template__c> templates = [SELECT Id, Template_Name__c, 
                                                  (SELECT Object_Name__c FROM WB_Template_Variables__r) 
                                           FROM Template__c 
                                           WHERE Status__c = 'Active-Quality Pending'
                                           WITH SECURITY_ENFORCED 
                                           ORDER BY LastModifiedDate DESC];
    
            // Categorize templates by object name
            for (Template__c template : templates) {
                String objectName;
    
                // If the template has associated object names, use the first one; otherwise, categorize it as 'Generic'
                if (!template.WB_Template_Variables__r.isEmpty()) {
                    objectName = template.WB_Template_Variables__r[0].Object_Name__c;
                } else {
                    objectName = 'Generic'; // Templates without variables are categorized as 'Generic'
                }
    
                // Initialize list if objectName is not yet added
                if (!objectTemplateMap.containsKey(objectName)) {
                    objectTemplateMap.put(objectName, new List<Template__c>());
                }
    
                // Add template to the appropriate object name
                objectTemplateMap.get(objectName).add(template);
            }
    
        } catch (Exception e) {
            ExceptionHandler.logException(new Map<String, Object>{
                'className' => 'BroadcastMessageController',
                'methodName' => 'getTemplatesByObject',
                'exceptionObj' => e,
                'isApiException' => false,
                'statusCode' => null,
                'chatId' => null,
                'moreDetails' => e.getMessage(),
                'apiResponse' => null
            });
        }
    
        return objectTemplateMap;
    }    

    @AuraEnabled
    public static void processBroadcastMessageWithObject(BroadcastMessageRequest request) {
        try {
            // Validate the request object
            if (request == null || 
                String.isBlank(request.objectApiName) || 
                request.phoneNumbers == null || request.phoneNumbers.isEmpty() || 
                String.isBlank(request.description) || 
                String.isBlank(request.name)) { // Added validation for name
                throw new AuraHandledException('All fields in the request are required, including the broadcast group name');
            }

            // Create the master Broadcast_Group__c record
            Broadcast_Group__c broadcastGroup = new Broadcast_Group__c();
            broadcastGroup.Name = request.name; 
            broadcastGroup.Description__c = request.description;
            broadcastGroup.Object_Name__c = request.objectApiName;
            broadcastGroup.List_View__c = request.listViewName;

            // Insert the master record with security enforcement
            Database.insert(broadcastGroup, false, AccessLevel.USER_MODE);

            // Prepare child Broadcast_Group_Member__c records
            List<Broadcast_Group_Member__c> groupMembersToInsert = new List<Broadcast_Group_Member__c>();
            
            for (String phoneNumber : request.phoneNumbers) {
                if (String.isNotBlank(phoneNumber)) {
                    Broadcast_Group_Member__c member = new Broadcast_Group_Member__c();
                    member.Broadcast_Group_ID__c = broadcastGroup.Id; // Link to master record
                    member.Phone_Number__c = phoneNumber; 
                    
                    groupMembersToInsert.add(member);
                }
            }

            // Insert child records with security enforcement
            if (!groupMembersToInsert.isEmpty()) {
                Database.insert(groupMembersToInsert, false, AccessLevel.USER_MODE);
            }

        } catch (Exception e) {
            ExceptionHandler.logException(new Map<String, Object>{
                'className' => 'BroadcastMessageController',
                'methodName' => 'processBroadcastMessageWithObject',
                'exceptionObj' => e,
                'isApiException' => false,
                'statusCode' => null,
                'chatId' => null,
                'moreDetails' => e.getMessage(),
                'apiResponse' => null
            });
            throw new AuraHandledException('Error processing broadcast message: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static void sendTemplateMessage(String templateId, List<String> phoneNumbers, String objectApiName) {
        try {
            System.debug('Sending WhatsApp Template Message...');
            
            // Fetch the metadata configuration
            List<WBConnect_Configuration__mdt> wbConfig = WBConnect_Configuration__mdt.getAll().values();
            if (wbConfig == null || wbConfig.isEmpty()) {
                System.debug('Error: METADATA_ERROR - No WhatsApp configuration found.');
                return;
            }
    
            String accessToken = wbConfig[0].Access_Token__c;
            String phoneNumberId = wbConfig[0].Phone_Number_Id__c;
            String endpoint = 'https://graph.facebook.com/v21.0/' + phoneNumberId + '/messages';
    
    
        } catch (Exception e) {
            System.debug('Error in sendTemplateMessage: ' + e.getMessage() + '\n' + e + '\n Exception line no: ' + e.getLineNumber());
        }
    }    

    @AuraEnabled
    public static Map<String, object> getTemplateData(String templateId, String recordId, String objectApiName){
        try {
            Map<String, Object> templateData = new Map<String, Object>();
            List<Template__c> templates = new List<Template__c>();
            //templates = [SELECT Id, Template_Name__c, Button_Body__c, Button_Label__c, Button_Type__c, WBFooter_Body__c, WBHeader_Body__c, Header_Type__c, Language__c, WBTemplate_Body__c, Template_Category__c, Template_SubCatagory__c, Template_Type__c, Template_Variable__c, (SELECT Id, Name, Field_Name__c, Object_Name__c, Type__c, Alternate_Text__c FROM WB_Template_Variables__r ORDER BY Name asc) FROM Template__c WHERE Id =: templateId AND Id IN (SELECT Template__c FROM Template_Variable__c WHERE Object_Name__c = :objectApiName) WITH SECURITY_ENFORCED];
            
            // Fetch templates with matching child variables
            Set<Id> matchingTemplateIds = new Set<Id>();
            for (Template_Variable__c tv : [SELECT Template__c FROM Template_Variable__c WHERE Object_Name__c = :objectApiName WITH SECURITY_ENFORCED]) {
                matchingTemplateIds.add(tv.Template__c);
            }

            // Fetch template details
            if (!matchingTemplateIds.isEmpty()) {
                templates.addAll([
                    SELECT Id, Template_Name__c, Button_Body__c, Button_Label__c, Button_Type__c, WBFooter_Body__c, WBHeader_Body__c, Header_Type__c, Language__c, WBTemplate_Body__c, Template_Category__c, Template_SubCatagory__c, Template_Type__c, Template_Variable__c,
                        (SELECT Id, Name, Field_Name__c, Object_Name__c, Type__c, Alternate_Text__c FROM WB_Template_Variables__r) FROM Template__c WHERE Id = :templateId AND Id IN :matchingTemplateIds WITH SECURITY_ENFORCED
                ]);
            }

            // Fetch templates without child variables
            List<Template__c> templatesWithoutVariables = [
                SELECT Id, Template_Name__c, Button_Body__c, Button_Label__c, Button_Type__c, WBFooter_Body__c, WBHeader_Body__c, Header_Type__c, Language__c, WBTemplate_Body__c, Template_Category__c, Template_SubCatagory__c, Template_Type__c, Template_Variable__c,
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
                        try {
                            // Check if the object supports relationships before adding related fields
                            fieldSelectionCause.add(tv.Object_Name__c + '.' + tv.Field_Name__c);
                        } catch (Exception ex) {
                            System.debug('Invalid relationship: ' + tv.Object_Name__c + ' for ' + objectApiName);
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
                                System.debug('Invalid relationship: ' + tv.Object_Name__c + ' for ' + objectApiName);  
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
                templateData.put('template', templates[0]);
                return templateData;
            } else if (templates.size() > 0 && templates[0].Template_Variable__c < 1){
                templateData.put('template', templates[0]);
                return templateData;
            } else {
                return null;
            }
        } catch (Exception e) {
            ExceptionHandler.logException(new Map<String, Object>{'className' => 'ChatWindowController', 'methodName' => 'getTemplateData', 'exceptionObj' => e, 'isApiException' => false, 'statusCode' => null, 'chatId' => null, 'moreDetails' =>  e.getMessage(), 'apiResponse' => null});
        }
        return null;
    }

    // Wrapper class for the broadcast message data
    public class BroadcastMessageRequest {
        @AuraEnabled public String objectApiName { get; set; }
        @AuraEnabled public String listViewName { get; set; }
        @AuraEnabled public List<String> phoneNumbers { get; set; }
        @AuraEnabled public String description { get; set; }
        @AuraEnabled public String name { get; set; } // Added name field
    }


}