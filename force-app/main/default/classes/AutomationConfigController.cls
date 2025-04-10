/** 
* Class Name: AutomationConfigController 
* Test Class:
* @description: Used in automationConfig LWC components 
* Date: 26/03/2025 
* Created By: Kavya Trivedi 
*/

public without sharing class AutomationConfigController {

    /**
    * Method Name : getAllAutomations
    * @description : Get all Automation records
    * @return List of Automation__c records
    */
    @AuraEnabled
    public static List<Automation__c> getAllAutomations() {
        try {
            return [SELECT Id, Name, Description__c, WB_Template__r.MVWB__Template_Name__c, WB_Template__r.MVWB__Template_Type__c FROM Automation__c];
        } catch (Exception e) {
            ExceptionHandler.logException(new Map<String, Object>{
                'className' => 'AutomationConfigController',
                'methodName' => 'getAllAutomations',
                'exceptionObj' => e,
                'isApiException' => false,
                'statusCode' => null,
                'chatId' => null,
                'moreDetails' => e.getMessage(),
                'apiResponse' => null
            });
            System.debug('Error in getAllAutomations: ' + e.getMessage());
            return null;
        }
    }

    /**
    * Method Name : getTemplates
    * @description : Get all Template records
    * @return MVWB__Template__c records
    */
    @AuraEnabled
    public static List<MVWB__Template__c> getTemplates() {
        try {
            return [SELECT Id, MVWB__Template_Name__c, MVWB__Template_Type__c FROM MVWB__Template__c WITH USER_MODE];
        } catch (Exception e) {
            ExceptionHandler.logException(new Map<String, Object>{
                'className' => 'AutomationConfigController',
                'methodName' => 'getTemplates',
                'exceptionObj' => e,
                'isApiException' => false,
                'statusCode' => null,
                'chatId' => null,
                'moreDetails' => e.getMessage(),
                'apiResponse' => null
            });
            return null;
        }
    }

    /**
    * Method Name : saveAutomations
    * @description : Save Automation records
    * @param automations List of Automation__c records
    * @return List of Automation__c records
    */
    @AuraEnabled
    public static List<Automation__c> saveAutomations(List<Automation__c> automations) {
        try {
            if (automations == null || automations.isEmpty()) {
                return new List<Automation__c>();
            }

            System.debug(Schema.sObjectType.Automation__c.fields.Name.isCreateable() + ', ' + Schema.sObjectType.Automation__c.fields.Description__c.isCreateable() + ', ' + Schema.sObjectType.Automation__c.fields.WB_Template__c.isCreateable());
            if (Schema.sObjectType.Automation__c.fields.Name.isCreateable() && Schema.sObjectType.Automation__c.fields.Description__c.isCreateable() && Schema.sObjectType.Automation__c.fields.WB_Template__c.isCreateable()){
                insert automations;
            }
            return automations;
        } catch (Exception e) {
            ExceptionHandler.logException(new Map<String, Object>{
                'className' => 'AutomationConfigController',
                'methodName' => 'saveAutomations',
                'exceptionObj' => e,
                'isApiException' => false,
                'statusCode' => null,
                'chatId' => null,
                'moreDetails' => e.getMessage(),
                'apiResponse' => null
            });
            System.debug('Error in saveAutomations: ' + e.getMessage());
            return null;
        }
    }

    /**
    * Method Name : updateAutomations
    * @description : Update Automation records
    * @param automations List of Automation__c records
    * @return List of Automation__c records
    */
    @AuraEnabled
    public static List<Automation__c> updateAutomations(List<Automation__c> automations) {
        try {
            if (automations == null || automations.isEmpty()) {
                return new List<Automation__c>();
            }

            Map<Id, Automation__c> existingRecords = new Map<Id, Automation__c>(
                [SELECT Id, Name, Description__c, WB_Template__c 
                FROM Automation__c 
                WHERE Id IN :automations 
                WITH SECURITY_ENFORCED]
            );

            List<Automation__c> recordsToUpdate = new List<Automation__c>();

            for (Automation__c newRecord : automations) {
                if (existingRecords.containsKey(newRecord.Id)) {
                    Automation__c existingRecord = existingRecords.get(newRecord.Id);

                    existingRecord.Name = newRecord.Name;
                    existingRecord.Description__c = newRecord.Description__c;
                    existingRecord.WB_Template__c = newRecord.WB_Template__c;

                    recordsToUpdate.add(existingRecord);
                }
            }

            if (!recordsToUpdate.isEmpty() && Schema.sObjectType.Automation__c.fields.Name.isUpdateable() && Schema.sObjectType.Automation__c.fields.Description__c.isUpdateable() && Schema.sObjectType.Automation__c.fields.WB_Template__c.isUpdateable()) {
                update recordsToUpdate;
            }

            return recordsToUpdate;

        } catch (Exception e) {
            ExceptionHandler.logException(new Map<String, Object>{
                'className' => 'AutomationConfigController',
                'methodName' => 'updateAutomations',
                'exceptionObj' => e,
                'isApiException' => false,
                'statusCode' => null,
                'chatId' => null,
                'moreDetails' => e.getMessage(),
                'apiResponse' => null
            });
            return null;
        }
    }

    /**
    * Method Name : deleteAutomations
    * @description : Delete Automation records
    * @param recordIds List of Ids
    * @return void
    */
    @AuraEnabled
    public static void deleteAutomations(List<Id> recordIds) {
        try {
            if (recordIds == null || recordIds.isEmpty()) {
                return;
            }

            if (!Schema.sObjectType.Automation__c.isDeletable()) {
                throw new SecurityException('You do not have permission to delete Automation records.');
            }

            List<Automation__c> recordsToDelete = [
                SELECT Id FROM Automation__c 
                WHERE Id IN :recordIds 
                WITH SECURITY_ENFORCED
            ];

            if (!recordsToDelete.isEmpty()) {
                delete recordsToDelete;
            }

        } catch (Exception e) {
            ExceptionHandler.logException(new Map<String, Object>{
                'className' => 'AutomationConfigController',
                'methodName' => 'deleteAutomations',
                'exceptionObj' => e,
                'isApiException' => false,
                'statusCode' => null,
                'chatId' => null,
                'moreDetails' => e.getMessage(),
                'apiResponse' => null
            });
        }
    }

    /**
    * Method Name : getAutomationsById
    * @description : Get Automation records by Id
    * @return Automation__c record
    */
    @AuraEnabled
    public static Automation__c getAutomationById(Id recordId) {
        try {
            return [SELECT Id, Name, Description__c, WB_Template__r.MVWB__Template_Name__c, WB_Template__r.MVWB__Template_Type__c, WB_Template__r.MVWB__WBButton_Body__c FROM Automation__c WHERE Id = :recordId WITH SECURITY_ENFORCED LIMIT 1];
        } catch (Exception e) {
            ExceptionHandler.logException(new Map<String, Object>{
                'className' => 'AutomationConfigController',
                'methodName' => 'getAutomationById',
                'exceptionObj' => e,
                'isApiException' => false,
                'statusCode' => null,
                'chatId' => null,
                'moreDetails' => e.getMessage(),
                'apiResponse' => null
            });
            return null;
        }
    }

    /**
    * Method Name : getEmailTemplates
    * @description : Get all Email Template records
    * @return List of EmailTemplate records
    */
    @AuraEnabled
    public static List<EmailTemplate> getEmailTemplates() {
        try {
            return [SELECT Id, Name FROM EmailTemplate WITH SECURITY_ENFORCED];
        } catch (Exception e) {
            ExceptionHandler.logException(new Map<String, Object>{
                'className' => 'AutomationConfigController',
                'methodName' => 'getTemplates',
                'exceptionObj' => e,
                'isApiException' => false,
                'statusCode' => null,
                'chatId' => null,
                'moreDetails' => e.getMessage(),
                'apiResponse' => null
            });
            return null;
        }
    }

    /**
    * Method Name : saveAutomationPaths
    * @description : Save Automation Path records
    * @param automationPaths List of Automation_Path__c records
    * @return List of Automation_Path__c records
    */
    @AuraEnabled
    public static List<Automation_Path__c> saveAutomationPaths(List<Automation_Path__c> automationPaths) {
        try {
            if (automationPaths == null || automationPaths.isEmpty()) {
                return new List<Automation_Path__c>();
            }
            
            if (Schema.sObjectType.Automation_Path__c.fields.Automation__c.IsCreateable() && Schema.sObjectType.Automation_Path__c.fields.Button_Value__c.isCreateable() && Schema.sObjectType.Automation_Path__c.fields.Action_Type__c.isCreateable() && Schema.sObjectType.Automation_Path__c.fields.Action_Template__c.isCreateable() && Schema.sObjectType.Automation_Path__c.fields.Action_Email_Template__c.isCreateable() && Schema.sObjectType.Automation_Path__c.fields.Object_Name__c.isCreateable() && Schema.sObjectType.Automation_Path__c.fields.Field_Mapping__c.isCreateable() && Schema.sObjectType.Automation_Path__c.fields.WB_Flow__c.isCreateable() && Schema.sObjectType.Automation_Path__c.fields.Automation__c.isUpdateable() && Schema.sObjectType.Automation_Path__c.fields.Button_Value__c.isUpdateable() && Schema.sObjectType.Automation_Path__c.fields.Action_Type__c.isUpdateable() && Schema.sObjectType.Automation_Path__c.fields.Action_Template__c.isUpdateable() && Schema.sObjectType.Automation_Path__c.fields.Action_Email_Template__c.isUpdateable() && Schema.sObjectType.Automation_Path__c.fields.Object_Name__c.isUpdateable() && Schema.sObjectType.Automation_Path__c.fields.Field_Mapping__c.isUpdateable() && Schema.sObjectType.Automation_Path__c.fields.WB_Flow__c.isUpdateable()) {
                Set<Id> automationIds = new Set<Id>();
                Set<String> buttonValues = new Set<String>();

                for (Automation_Path__c path : automationPaths) {
                    automationIds.add(path.Automation__c);
                    buttonValues.add(path.Button_Value__c);
                }

                List<Automation_Path__c> existingRecords = [
                    SELECT Id, Automation__c, Button_Value__c, Action_Type__c, Action_Template__c, 
                        Action_Email_Template__c, Object_Name__c, Field_Mapping__c, WB_Flow__c
                    FROM Automation_Path__c
                    WHERE Automation__c IN :automationIds AND Button_Value__c IN :buttonValues
                ];

                Map<String, Automation_Path__c> existingRecordsMap = new Map<String, Automation_Path__c>();

                for (Automation_Path__c record : existingRecords) {
                    String key = record.Automation__c + '-' + record.Button_Value__c;
                    existingRecordsMap.put(key, record);
                }

                List<Automation_Path__c> recordsToUpsert = new List<Automation_Path__c>();

                for (Automation_Path__c path : automationPaths) {
                    String key = path.Automation__c + '-' + path.Button_Value__c;

                    if (existingRecordsMap.containsKey(key)) {
                        Automation_Path__c existingRecord = existingRecordsMap.get(key);
                        existingRecord.Action_Type__c = path.Action_Type__c;
                        existingRecord.Action_Template__c = path.Action_Template__c;
                        existingRecord.Action_Email_Template__c = path.Action_Email_Template__c;
                        existingRecord.Object_Name__c = path.Object_Name__c;
                        existingRecord.Field_Mapping__c = path.Field_Mapping__c;
                        existingRecord.WB_Flow__c = path.WB_Flow__c;

                        recordsToUpsert.add(existingRecord);
                    } else {
                        recordsToUpsert.add(path);
                    }
                }

                upsert recordsToUpsert;
            }
            return automationPaths;
        } catch (Exception e) {
            ExceptionHandler.logException(new Map<String, Object>{
                'className' => 'AutomationConfigController',
                'methodName' => 'saveAutomationPaths',
                'exceptionObj' => e,
                'isApiException' => false,
                'statusCode' => null,
                'chatId' => null,
                'moreDetails' => e.getMessage(),
                'apiResponse' => null
            });
            return null;
        }
    }

    @AuraEnabled
    public static List<Automation_Path__c> getAutomationPathsByAutomationId(Id automationId) {
        if (String.isEmpty(automationId)) {
            return new List<Automation_Path__c>();
        }
        
        List<Automation_Path__c> automationPaths = [
            SELECT Id, Automation__c, Button_Value__c, Action_Type__c, Action_Template__c, 
                Action_Email_Template__c, Object_Name__c, Field_Mapping__c, WB_Flow__c
            FROM Automation_Path__c
            WHERE Automation__c = :automationId
        ];
        
        // Return an empty list if no records are found
        return automationPaths != null ? automationPaths : new List<Automation_Path__c>();
    }

    @AuraEnabled
    public static List<Map<String, String>> getAllObjects() {
        List<Map<String, String>> objectList = new List<Map<String, String>>();
        
        try {
            // Get all objects from Schema
            Map<String, Schema.SObjectType> schemaMap = Schema.getGlobalDescribe();
            
            for (String objectName : schemaMap.keySet()) {
                Schema.DescribeSObjectResult objDescribe = schemaMap.get(objectName).getDescribe();
                
                // Ensure the object is accessible, customizable, and queryable
                if (objDescribe.isAccessible() && objDescribe.isQueryable() && objDescribe.isCreateable()) {
                    objectList.add(new Map<String, String>{
                        'label' => objDescribe.getLabel(),
                        'value' => objectName
                    });
                }
            }
        } catch (Exception e) {
            System.debug('Error fetching objects: ' + e.getMessage());
        }
        
        return objectList;
    }

    @AuraEnabled
    public static List<Map<String, Object>> getRequiredFields(String objectName) {
        try {
            List<Map<String, Object>> requiredFields = new List<Map<String, Object>>();
            
            Schema.DescribeSObjectResult objectDescribe = Schema.getGlobalDescribe().get(objectName).getDescribe();
            Map<String, Schema.SObjectField> fieldMap = objectDescribe.fields.getMap();
            
            for (Schema.SObjectField field : fieldMap.values()) {
                Schema.DescribeFieldResult fieldDescribe = field.getDescribe();
                
                // Skip fields that shouldn't be included
                if (fieldDescribe.isNillable() || fieldDescribe.isAutoNumber() || !fieldDescribe.isAccessible() || 
                    !fieldDescribe.isCreateable() || fieldDescribe.isCalculated() || fieldDescribe.isExternalId()) {
                    continue;
                }
    
                Map<String, Object> fieldInfo = new Map<String, Object>();
                fieldInfo.put('name', fieldDescribe.getName());
                fieldInfo.put('label', fieldDescribe.getLabel());
                fieldInfo.put('type', fieldDescribe.getType().name());
    
                // Handle picklist values
                if (fieldDescribe.getType() == Schema.DisplayType.Picklist) {
                    List<Schema.PicklistEntry> picklistEntries = fieldDescribe.getPicklistValues();
                    List<String> picklistValues = new List<String>();
                    List<Map<String, String>> picklistValuesSet = new List<Map<String, String>>();
    
                    for (Schema.PicklistEntry entry : picklistEntries) {
                        picklistValues.add(entry.getValue());
                        Map<String, String> picklistSet = new Map<String, String>();
                        picklistSet.put('label', entry.getLabel());
                        picklistSet.put('value', entry.getValue());
                        picklistValuesSet.add(picklistSet);
                    }
    
                    fieldInfo.put('picklistValues', picklistValuesSet);
    
                    // Set default picklist value (either default set value or first value)
                    String defaultValue = fieldDescribe.getDefaultValue() != null ? 
                        String.valueOf(fieldDescribe.getDefaultValue()) : 
                        (picklistValues.isEmpty() ? '' : picklistValues[0]);
    
                    fieldInfo.put('value', defaultValue);
                } 
                
                // Handle lookup fields (assign first record ID)
                else if (fieldDescribe.getType() == Schema.DisplayType.Reference) {
                    String relatedObject = fieldDescribe.getReferenceTo()[0].getDescribe().getName();
                    fieldInfo.put('value', '');
                    fieldInfo.put('relatedObject', relatedObject);
                    fieldInfo.put('relatedRecordName', '');
                }
    
                requiredFields.add(fieldInfo);
            }

            // Create the final response structure
            Map<String, Object> responseMap = new Map<String, Object>();
            responseMap.put('requiredFields', requiredFields);
            
            // Wrap the response map in a list to match the desired format
            List<Map<String, Object>> finalResponse = new List<Map<String, Object>>();
            finalResponse.add(responseMap);
            
            return finalResponse;
        } catch (Exception e) {
            ExceptionHandler.logException(new Map<String, Object>{'className' => 'AutomationConfigController', 'methodName' => 'getRequiredFields', 'exceptionObj' => e, 'isApiException' => false, 'statusCode' => null, 'chatId' => null, 'moreDetails' => e.getMessage(), 'apiResponse' => null});
            return null;
        }
    }

    @AuraEnabled
    public static List<Map<String, String>> getObjectFields(String objectName) {
        try {

            List<Map<String, String>> objectFields = new List<Map<String, String>>();
            
            Schema.DescribeSObjectResult objectDescribe = Schema.getGlobalDescribe().get(objectName).getDescribe();
            Map<String, Schema.SObjectField> fieldMap = objectDescribe.fields.getMap();
            
            for (Schema.SObjectField field : fieldMap.values()) {
                Schema.DescribeFieldResult fieldDescribe = field.getDescribe();

                if (fieldDescribe.isAccessible() && fieldDescribe.isCreateable() && !fieldDescribe.isAutoNumber() && !fieldDescribe.isCalculated()) {
                    Map<String, String> objectFieldInfo = new Map<String, String>();
                    objectFieldInfo.put('label', fieldDescribe.getLabel());
                    objectFieldInfo.put('value', fieldDescribe.getName());
                    objectFieldInfo.put('type', String.valueOf(fieldDescribe.getType()));
                    objectFields.add(objectFieldInfo);
                }
            }
            
            return objectFields;
        } catch (Exception e) {
            ExceptionHandler.logException(new Map<String, Object>{'className' => 'AutomationConfigController', 'methodName' => 'getTextAndPhoneFields', 'exceptionObj' => e, 'isApiException' => false, 'statusCode' => null, 'chatId' => null, 'moreDetails' => e.getMessage(), 'apiResponse' => null});
            return null;
        }
    }

    @AuraEnabled
    public static String getFlowIdFromAutomation(Id automationId) {
        // Step 1: Query the template related to the automation
        Automation__c automation = [
            SELECT WB_Template__r.MVWB__WBButton_Body__c 
            FROM Automation__c 
            WHERE Id = :automationId 
            LIMIT 1
        ];
    
        String buttonBodyJson = automation.WB_Template__r.MVWB__WBButton_Body__c;
        if (String.isBlank(buttonBodyJson)) { return null; }
    
        try {
            // Step 2: Parse the JSON string into a list of objects
            List<Object> buttonList = (List<Object>) JSON.deserializeUntyped(buttonBodyJson);
    
            // Step 3: Loop through and find the flow_id
            for (Object itemObj : buttonList) {
                Map<String, Object> item = (Map<String, Object>) itemObj;
                if ((String)item.get('type') == 'FLOW' && item.containsKey('flow_id')) {
                    return (String)item.get('flow_id');
                }
            }
        } catch (Exception ex) {
            System.debug('Error parsing button body JSON: ' + ex.getMessage());
        }
    
        return null; // if no FLOW type or error
    }

    @AuraEnabled
    public static String getFlowFields(String flowId) {
        MVWB__Flow__c flow =  [SELECT Id, MVWB__Flow_JSON__c FROM MVWB__Flow__c WHERE MVWB__Flow_Id__c = :flowId WITH SECURITY_ENFORCED];

        if (flow == null || String.isBlank(flow.MVWB__Flow_JSON__c)) {
            return null; // or handle the error as needed
        }
        return flow.MVWB__Flow_JSON__c;
    }
}