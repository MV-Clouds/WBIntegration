/**
* Class Name: ObjectConfigController
* Test Class: 
* @description: Used for handling object configuration for webhook class and chat window
* Created Date: 12 Mar, 2025
* Created By: Harsh Gandhi
*--------------------------------------------------------------------------------
* Last Modified By: Harsh Gandhi
* Last Modified Date: 12 Mar, 2025
* Last Modification Description: 
*--------------------------------------------------------------------------------
* Modification History:
* Date Modified - Developer Name - Description
* 18 Mar, 2025  - Harsh Gandhi - Updated method for fetching obects with phone field
**/
public with sharing class ObjectConfigController {
    
    /*
    *********************************************************
    @description     : Method to get objects with phone field.
    @return          : List<Map<String, String>> - return list of objects with phone field.
    ********************************************************
    */
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getObjectsWithPhoneField() {
        List<Map<String, String>> objectList = new List<Map<String, String>>();
        try {
            // Query FieldDefinition to fetch all objects having at least one Phone field
            List<FieldDefinition> phoneFields = [SELECT EntityDefinition.QualifiedApiName, EntityDefinition.Label, QualifiedApiName FROM FieldDefinition WHERE DataType = 'Phone' AND EntityDefinition.IsCustomizable = true AND EntityDefinition.IsApexTriggerable = true AND EntityDefinition.IsQueryable = true WITH SECURITY_ENFORCED];

            Set<String> processedObjects = new Set<String>();

            // Get Object Descriptions
            Map<String, Schema.SObjectType> schemaMap = Schema.getGlobalDescribe();

            for (FieldDefinition field : phoneFields) {
                String objectName = field.EntityDefinition.QualifiedApiName;
                
                // Ensure object exists in schema description
                if (schemaMap.containsKey(objectName)) {
                    Schema.DescribeSObjectResult objDescribe = schemaMap.get(objectName).getDescribe();

                    // Check field-level permissions
                    if (objDescribe.fields.getMap().containsKey(field.QualifiedApiName)) {
                        Schema.DescribeFieldResult fieldDescribe = objDescribe.fields.getMap().get(field.QualifiedApiName).getDescribe();

                        if (fieldDescribe.isAccessible() && fieldDescribe.isCreateable()) {
                            if (!processedObjects.contains(objectName)) {
                                objectList.add(new Map<String, String>{
                                    'label' => field.EntityDefinition.Label,
                                    'value' => objectName
                                });
                                processedObjects.add(objectName);
                            }
                        }
                    }
                }
            }
        } catch (Exception e) {
            ExceptionHandler.logException(new Map<String, Object>{'className' => 'ObjectConfigController','methodName' => 'getObjectsWithPhoneField','exceptionObj' => e,'isApiException' => false,'statusCode' => null,'chatId' => null,'moreDetails' => e.getMessage(),'apiResponse' => null});
        }
        return objectList;
    }

    /*
    *********************************************************
    @description     : Fetch required fields for the selected object
    @return          : List<Map<String, Object>> - return list of required and phone fields for the selected object.
    ********************************************************
    */
    @AuraEnabled
    public static List<Map<String, Object>> getRequiredFields(String objectName) {
        try {
            List<Map<String, Object>> requiredFields = new List<Map<String, Object>>();
            List<Map<String, String>> phoneFields = new List<Map<String, String>>();
            List<Map<String, String>> textFields = new List<Map<String, String>>();
            
            Schema.DescribeSObjectResult objectDescribe = Schema.getGlobalDescribe().get(objectName).getDescribe();
            Map<String, Schema.SObjectField> fieldMap = objectDescribe.fields.getMap();
            
            for (Schema.SObjectField field : fieldMap.values()) {
                Schema.DescribeFieldResult fieldDescribe = field.getDescribe();

                if (fieldDescribe.getType() == Schema.DisplayType.PHONE && fieldDescribe.isAccessible() && fieldDescribe.isCreateable()) {
                    Map<String, String> phoneFieldInfo = new Map<String, String>();
                    phoneFieldInfo.put('label', fieldDescribe.getLabel());
                    phoneFieldInfo.put('value', fieldDescribe.getName());
                    phoneFields.add(phoneFieldInfo);
                }

                // Handle Text fields (only STRING type, excluding TEXTAREA, LONGTEXTAREA, RICHTEXT)
                if (fieldDescribe.getType() == Schema.DisplayType.STRING && fieldDescribe.isAccessible() && fieldDescribe.isCreateable()) {
                    Map<String, String> textFieldInfo = new Map<String, String>();
                    textFieldInfo.put('label', fieldDescribe.getLabel());
                    textFieldInfo.put('value', fieldDescribe.getName());
                    textFields.add(textFieldInfo);
                }
                
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
            responseMap.put('phoneFields', phoneFields);
            responseMap.put('requiredFields', requiredFields);
            responseMap.put('textFields', textFields);
            
            // Wrap the response map in a list to match the desired format
            List<Map<String, Object>> finalResponse = new List<Map<String, Object>>();
            finalResponse.add(responseMap);
            
            return finalResponse;
        } catch (Exception e) {
            ExceptionHandler.logException(new Map<String, Object>{'className' => 'ObjectConfigController', 'methodName' => 'getRequiredFields', 'exceptionObj' => e, 'isApiException' => false, 'statusCode' => null, 'chatId' => null, 'moreDetails' => e.getMessage(), 'apiResponse' => null});
            return null;
        }
    }
    
    /*
    *********************************************************
    @description     : Fetch required fields for the selected object
    @return          : List<Map<String, Object>> - return list of required and phone fields for the selected object.
    ********************************************************
    */
    @AuraEnabled
    public static List<Map<String, Object>> getTextAndPhoneFields(String objectName) {
        try {
            List<Map<String, String>> phoneFields = new List<Map<String, String>>();
            List<Map<String, String>> textFields = new List<Map<String, String>>();
            
            Schema.DescribeSObjectResult objectDescribe = Schema.getGlobalDescribe().get(objectName).getDescribe();
            Map<String, Schema.SObjectField> fieldMap = objectDescribe.fields.getMap();
            
            for (Schema.SObjectField field : fieldMap.values()) {
                Schema.DescribeFieldResult fieldDescribe = field.getDescribe();

                if (fieldDescribe.getType() == Schema.DisplayType.PHONE && fieldDescribe.isAccessible() && fieldDescribe.isCreateable() && !fieldDescribe.isAutoNumber() && !fieldDescribe.isCalculated()) {
                    Map<String, String> phoneFieldInfo = new Map<String, String>();
                    phoneFieldInfo.put('label', fieldDescribe.getLabel());
                    phoneFieldInfo.put('value', fieldDescribe.getName());
                    phoneFields.add(phoneFieldInfo);
                }

                // Handle Text fields (only STRING type, excluding TEXTAREA, LONGTEXTAREA, RICHTEXT)
                if (fieldDescribe.getType() == Schema.DisplayType.STRING && fieldDescribe.isAccessible() && fieldDescribe.isCreateable() && !fieldDescribe.isAutoNumber() && !fieldDescribe.isCalculated()) {
                    Map<String, String> textFieldInfo = new Map<String, String>();
                    textFieldInfo.put('label', fieldDescribe.getLabel());
                    textFieldInfo.put('value', fieldDescribe.getName());
                    textFields.add(textFieldInfo);
                }
            }

            // Create the final response structure
            Map<String, Object> responseMap = new Map<String, Object>();
            responseMap.put('phoneFields', phoneFields);
            responseMap.put('textFields', textFields);
            
            // Wrap the response map in a list to match the desired format
            List<Map<String, Object>> finalResponse = new List<Map<String, Object>>();
            finalResponse.add(responseMap);
            
            return finalResponse;
        } catch (Exception e) {
            ExceptionHandler.logException(new Map<String, Object>{'className' => 'ObjectConfigController', 'methodName' => 'getTextAndPhoneFields', 'exceptionObj' => e, 'isApiException' => false, 'statusCode' => null, 'chatId' => null, 'moreDetails' => e.getMessage(), 'apiResponse' => null});
            return null;
        }
    }

    /*
    *********************************************************
    @description     : Fetch saved configuration from Custom Metadata
    @return          : String - return JSON string of configuration.
    ********************************************************
    */
    @AuraEnabled
    public static Map<String, String> getUserConfig() {
        Map<String, String> configMap = new Map<String, String>();
        try {
            List<MVWB__Object_Config__mdt> config = [SELECT MVWB__ObjectConfigInfo__c, MVWB__ChatWindowConfigInfo__c FROM MVWB__Object_Config__mdt WITH SECURITY_ENFORCED LIMIT 1];
            if(config.size() > 0) {
                configMap.put('ObjectConfigInfo', config[0].MVWB__ObjectConfigInfo__c);
                configMap.put('ChatWindowConfigInfo', config[0].MVWB__ChatWindowConfigInfo__c);
            } else {
                configMap.put('ObjectConfigInfo', '{}');
                configMap.put('ChatWindowConfigInfo', '{}');
            }
            return configMap;
        } catch (Exception e) {
            ExceptionHandler.logException(new Map<String, Object>{'className' => 'ObjectConfigController', 'methodName' => 'getUserConfig', 'exceptionObj' => e, 'isApiException' => false, 'statusCode' => null, 'chatId' => null, 'moreDetails' => e.getMessage(), 'apiResponse' => null});
            configMap.put('ObjectConfigInfo', '{}');
            configMap.put('ChatWindowConfigInfo', '{}');
        }
        return configMap;
    }

    /*
    *********************************************************
    @description     : Save configuration by updating the same Custom Metadata record
    @return          : String - return status of operation.
    ********************************************************
    */
    @AuraEnabled
    public static String saveUserConfig(String jsonData, String jsonDataForChat) {
        try {
            List<MVWB__Object_Config__mdt> config = [SELECT MasterLabel, DeveloperName FROM MVWB__Object_Config__mdt WITH SECURITY_ENFORCED LIMIT 1];
            Metadata.CustomMetadata mdata = new Metadata.CustomMetadata();
            if(config.size() > 0){
                mdata.fullName = 'MVWB__Object_Config__mdt.' + config[0].DeveloperName; 
                mdata.label = config[0].MasterLabel;
            } else {
                mdata.fullName = 'MVWB__Object_Config__mdt.objectConfigInfo'; 
                mdata.label = 'objectConfigInfo';
            }

            if(jsonData != null){
                Metadata.CustomMetadataValue instance1 = new Metadata.CustomMetadataValue();
                instance1.field = 'MVWB__ObjectConfigInfo__c';
                instance1.value = jsonData;
                mdata.values.add(instance1);
            }

            if(jsonDataForChat != null){
                Metadata.CustomMetadataValue instance2 = new Metadata.CustomMetadataValue();
                instance2.field = 'MVWB__ChatWindowConfigInfo__c';
                instance2.value = jsonDataForChat;
                mdata.values.add(instance2);
            }

            Metadata.DeployContainer container = new Metadata.DeployContainer();
            container.addMetadata(mdata);

            Metadata.Operations.enqueueDeployment(container, null);

            return 'sucess';
        } catch (Exception e) {
            ExceptionHandler.logException(new Map<String, Object>{'className' => 'ObjectConfigController', 'methodName' => 'saveUserConfig', 'exceptionObj' => e, 'isApiException' => false, 'statusCode' => null, 'chatId' => null, 'moreDetails' => e.getMessage(), 'apiResponse' => null});
            return 'Error: ' + e.getMessage();
        }
    }
    
    /*
    *********************************************************
    @description     : Get record name from record ID.
    @return          : String - return name of the record.
    ********************************************************
    */
    @AuraEnabled
    public static string getRecordName(String recordId, String objectApiName){
        try {
            if (String.isBlank(recordId) || String.isBlank(objectApiName)) {
                return '';
            }
            List<sObject> records = new List<sObject>();
            String query = 'SELECT Name FROM ' + String.escapeSingleQuotes(objectApiName) + ' WHERE Id = :recordId LIMIT 1';
            records = Database.query(query);
            return records.size() != 0 ? (String)records[0].get('Name') : '';
        } catch (Exception e) {
            ExceptionHandler.logException(new Map<String, Object>{'className' => 'ObjectConfigController', 'methodName' => 'getRecordName', 'exceptionObj' => e, 'isApiException' => false, 'statusCode' => null, 'chatId' => null, 'moreDetails' => e.getMessage(), 'apiResponse' => null});
            return '';
        }
    }

    /*
    *********************************************************
    @description     : Method to insert dummy metadata record when package is installed
    @return          : none
    ********************************************************
    */
    public static void initializeDummyConfig() {
        try {
            // Check if any record already exists
            List<MVWB__Object_Config__mdt> existingConfigs = [SELECT Id FROM MVWB__Object_Config__mdt WITH SECURITY_ENFORCED LIMIT 1];
            if (!existingConfigs.isEmpty() && !Test.isRunningTest()) {
                return;
            }

            // Dynamically build requiredFields based on Contact object schema
            List<Map<String, Object>> requiredFields = new List<Map<String, Object>>();
            Schema.DescribeSObjectResult objectDescribe = Schema.getGlobalDescribe().get('Contact').getDescribe();
            Map<String, Schema.SObjectField> fieldMap = objectDescribe.fields.getMap();

            for (Schema.SObjectField field : fieldMap.values()) {
                Schema.DescribeFieldResult fieldDescribe = field.getDescribe();

                // Skip fields that shouldn't be included
                if (fieldDescribe.isNillable() || fieldDescribe.isAutoNumber() || !fieldDescribe.isAccessible() || 
                    !fieldDescribe.isUpdateable() || fieldDescribe.isCalculated() || fieldDescribe.isExternalId()) {
                    continue;
                }

                Map<String, Object> fieldInfo = new Map<String, Object>();
                fieldInfo.put('name', fieldDescribe.getName());
                fieldInfo.put('type', fieldDescribe.getType().name());

                // Handle picklist fields
                if (fieldDescribe.getType() == Schema.DisplayType.Picklist) {
                    List<Schema.PicklistEntry> picklistEntries = fieldDescribe.getPicklistValues();
                    List<Map<String, String>> picklistValuesSet = new List<Map<String, String>>();
                    for (Schema.PicklistEntry entry : picklistEntries) {
                        Map<String, String> picklistSet = new Map<String, String>();
                        picklistSet.put('label', entry.getLabel());
                        picklistSet.put('value', entry.getValue());
                        picklistValuesSet.add(picklistSet);
                    }

                    String defaultValue = fieldDescribe.getDefaultValue() != null ? 
                        String.valueOf(fieldDescribe.getDefaultValue()) : 
                        (picklistValuesSet.isEmpty() ? '' : picklistValuesSet[0].get('value'));
                    fieldInfo.put('value', defaultValue);
                }
                // Handle text fields (STRING type)
                else if (fieldDescribe.getType() == Schema.DisplayType.STRING) {
                    fieldInfo.put('value', 'Default Value');
                }
                // Handle date fields
                else if (fieldDescribe.getType() == Schema.DisplayType.DATE) {
                    fieldInfo.put('value', Date.today());
                }
                // Handle datetime fields
                else if (fieldDescribe.getType() == Schema.DisplayType.DATETIME) {
                    fieldInfo.put('value', DateTime.now());
                }
                // Handle boolean fields
                else if (fieldDescribe.getType() == Schema.DisplayType.BOOLEAN) {
                    fieldInfo.put('value', false);
                }
                // Handle reference fields
                else if (fieldDescribe.getType() == Schema.DisplayType.REFERENCE) {
                    String relatedObject = fieldDescribe.getReferenceTo()[0].getDescribe().getName();
                    List<SObject> relatedRecords = Database.query('SELECT Id FROM ' + relatedObject + ' LIMIT 1');
                    String defaultValue = !relatedRecords.isEmpty() ? relatedRecords[0].Id : '';
                    fieldInfo.put('value', defaultValue);
                }

                requiredFields.add(fieldInfo);
            }

            // Build the ObjectConfigInfo__c JSON dynamically
            Map<String, Object> objectConfigMap = new Map<String, Object>();
            objectConfigMap.put('objectApiName', 'Contact');
            objectConfigMap.put('phoneField', 'Phone');
            objectConfigMap.put('requiredFieds', requiredFields);

            String dummyObjectConfig = JSON.serialize(objectConfigMap);
    
            // Define dummy data for ChatWindowConfigInfo__c
            String dummyChatConfig = '{"Contact":{"nameField":"LastName","phoneField":"Phone"}}';
    
            // Create new custom metadata record
            Metadata.CustomMetadata mdata = new Metadata.CustomMetadata();
            mdata.fullName = 'MVWB__Object_Config__mdt.objectConfigInfo'; // Default DeveloperName
            mdata.label = 'objectConfigInfo';
    
            // Add ChatWindowConfigInfo__c field with dummy data
            Metadata.CustomMetadataValue instance = new Metadata.CustomMetadataValue();
            instance.field = 'MVWB__ChatWindowConfigInfo__c';
            instance.value = dummyChatConfig;
            mdata.values.add(instance);

            // Add ObjectConfigInfo__c field with dynamic dummy data
            Metadata.CustomMetadataValue instance1 = new Metadata.CustomMetadataValue();
            instance1.field = 'MVWB__ObjectConfigInfo__c';
            instance1.value = dummyObjectConfig;
            mdata.values.add(instance1);
    
            // Deploy the new record
            Metadata.DeployContainer container = new Metadata.DeployContainer();
            container.addMetadata(mdata);
    
            Metadata.Operations.enqueueDeployment(container, null);
        } catch (Exception e) {
            ExceptionHandler.logException(new Map<String, Object>{'className' => 'ObjectConfigController', 'methodName' => 'initializeDummyConfig', 'exceptionObj' => e, 'isApiException' => false, 'statusCode' => null, 'chatId' => null, 'moreDetails' => e.getMessage(), 'apiResponse' => null});
        }
    }
}