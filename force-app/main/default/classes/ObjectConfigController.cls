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
            List<FieldDefinition> phoneFields = [SELECT EntityDefinition.QualifiedApiName, EntityDefinition.Label FROM FieldDefinition WHERE DataType = 'Phone' AND EntityDefinition.IsCustomizable = true AND EntityDefinition.IsApexTriggerable = true AND EntityDefinition.IsQueryable = true WITH SECURITY_ENFORCED];
            
            Set<String> processedObjects = new Set<String>();
    
            for (FieldDefinition field : phoneFields) {
                String objectName = field.EntityDefinition.QualifiedApiName;
                if (!processedObjects.contains(objectName)) {
                    objectList.add(new Map<String, String>{
                        'label' => field.EntityDefinition.Label,
                        'value' => objectName
                    });
                    processedObjects.add(objectName);
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
    @return          : List<Map<String, Object>> - return list of required and accessible fields for the selected object.
    ********************************************************
    */
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
                    !fieldDescribe.isCreateable() || !fieldDescribe.isUpdateable() || fieldDescribe.isCalculated() || fieldDescribe.isExternalId()) {
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
    
            return requiredFields;
        } catch (Exception e) {
            ExceptionHandler.logException(new Map<String, Object>{'className' => 'ObjectConfigController', 'methodName' => 'getRequiredFields', 'exceptionObj' => e, 'isApiException' => false, 'statusCode' => null, 'chatId' => null, 'moreDetails' => e.getMessage(), 'apiResponse' => null});
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
    public static String getUserConfig() {
        try {
            List<Object_Config__mdt> config = [SELECT ObjectConfigInfo__c FROM Object_Config__mdt WITH SECURITY_ENFORCED LIMIT 1];
            return config.size() != 0 ? config[0].ObjectConfigInfo__c : '{}';
        } catch (Exception e) {
            ExceptionHandler.logException(new Map<String, Object>{'className' => 'ObjectConfigController', 'methodName' => 'getUserConfig', 'exceptionObj' => e, 'isApiException' => false, 'statusCode' => null, 'chatId' => null, 'moreDetails' => e.getMessage(), 'apiResponse' => null});
            return '{}';
        }
    }

    /*
    *********************************************************
    @description     : Save configuration by updating the same Custom Metadata record
    @return          : String - return status of operation.
    ********************************************************
    */
    @AuraEnabled
    public static String saveUserConfig(String jsonData) {
        try {
            List<Object_Config__mdt> config = [SELECT MasterLabel, DeveloperName FROM Object_Config__mdt WITH SECURITY_ENFORCED LIMIT 1];
            Metadata.CustomMetadata mdata = new Metadata.CustomMetadata();
            if(config.size() > 0){
                mdata.fullName = 'Object_Config__mdt.' + config[0].DeveloperName; 
                mdata.label = config[0].MasterLabel;
            } else {
                mdata.fullName = 'Object_Config__mdt.objectConfigInfo'; 
                mdata.label = 'objectConfigInfo';
            }

            Metadata.CustomMetadataValue instance1 = new Metadata.CustomMetadataValue();
            instance1.field = 'ObjectConfigInfo__c';
            instance1.value = jsonData;
            mdata.values.add(instance1);

            Metadata.DeployContainer container = new Metadata.DeployContainer();
            container.addMetadata(mdata);

            Metadata.Operations.enqueueDeployment(container, null);

            return 'sucess';
        } catch (Exception e) {
            ExceptionHandler.logException(new Map<String, Object>{'className' => 'ObjectConfigController', 'methodName' => 'saveUserConfig', 'exceptionObj' => e, 'isApiException' => false, 'statusCode' => null, 'chatId' => null, 'moreDetails' => e.getMessage(), 'apiResponse' => null});
            return 'Error: ' + e.getMessage();
        }
    }
    
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
}