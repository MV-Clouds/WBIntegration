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
    * @return Automation__c record
    */
    @AuraEnabled(cacheable=true)
    public static List<Automation__c> getAllAutomations() {
        return [SELECT Id, Name, Description__c, WB_Template__r.MVWB__Template_Name__c FROM Automation__c WITH SECURITY_ENFORCED];
    }

    /**
    * Method Name : getTemplates
    * @description : Get all Template records
    * @return MVWB__Template__c record
    */
    @AuraEnabled(cacheable=true)
    public static List<MVWB__Template__c> getTemplates() {
        return [SELECT Id, MVWB__Template_Name__c FROM MVWB__Template__c WITH USER_MODE];
    }

    /**
    * Method Name : saveAutomations
    * @description : Save Automation records
    * @param automations List of Automation__c records
    * @return List of Automation__c records
    */
    @AuraEnabled
    public static List<Automation__c> saveAutomations(List<Automation__c> automations) {
        if (automations == null || automations.isEmpty()) {
            return new List<Automation__c>();
        }

        if (Schema.sObjectType.Automation__c.fields.Name.IsCreateable() && Schema.sObjectType.Automation__c.fields.Description__c.isCreateable() && Schema.sObjectType.Automation__c.fields.WB_Template__c.isCreateable()){
            insert automations;
        }
        return automations;
    }

    /**
    * Method Name : updateAutomations
    * @description : Update Automation records
    * @param automationsToUpdate List of Automation__c records
    * @return List of Automation__c records
    */
    @AuraEnabled
    public static List<Automation__c> updateAutomations(List<Automation__c> automationsToUpdate) {
        if (automationsToUpdate == null || automationsToUpdate.isEmpty()) {
            return new List<Automation__c>();
        }

        Map<Id, Automation__c> existingRecords = new Map<Id, Automation__c>(
            [SELECT Id, Name, Description__c, WB_Template__c 
            FROM Automation__c 
            WHERE Id IN :automationsToUpdate 
            WITH SECURITY_ENFORCED]
        );

        List<Automation__c> recordsToUpdate = new List<Automation__c>();

        for (Automation__c newRecord : automationsToUpdate) {
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
    }

    /**
    * Method Name : deleteAutomations
    * @description : Delete Automation records
    * @param recordIds List of Ids
    * @return void
    */
    @AuraEnabled
    public static void deleteAutomations(List<Id> recordIds) {
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
    }
}
