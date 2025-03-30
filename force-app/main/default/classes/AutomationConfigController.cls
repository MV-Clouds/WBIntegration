/** 
* Class Name: AutomationConfigController 
* Test Class:
* @description: Used in automationConfig LWC components 
* Date: 26/03/2025 
* Created By: Kavya Trivedi 
*/

public with sharing class AutomationConfigController {

    /**
    * Method Name : getAllAutomations
    * @description : Get all Automation records
    * @return List of Automation__c records
    */
    @AuraEnabled
    public static List<Automation__c> getAllAutomations() {
        try {
            return [SELECT Id, Name, Description__c, WB_Template__r.MVWB__Template_Name__c FROM Automation__c WITH SECURITY_ENFORCED];
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

            if (Schema.sObjectType.Automation__c.fields.Name.IsCreateable() && Schema.sObjectType.Automation__c.fields.Description__c.isCreateable() && Schema.sObjectType.Automation__c.fields.WB_Template__c.isCreateable()){
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
            return [SELECT Id, Name, Description__c, WB_Template__r.MVWB__Template_Name__c, WB_Template__r.MVWB__Template_Type__c, WB_Template__r.Button_Body__c FROM Automation__c WHERE Id = :recordId WITH SECURITY_ENFORCED LIMIT 1];
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
}
