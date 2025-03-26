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
    * Method Name : saveAutomation
    * @description : Save Automation record
    * @param name String value
    * @param description String value
    * @param templateId Id value
    * @return Automation__c record
    */
    @AuraEnabled
    public static Automation__c saveAutomation(String name, String description, Id templateId) {
        Automation__c newAutomation = new Automation__c(
            Name = name,
            Description__c = description,
            WB_Template__c = templateId
        );
        if (Schema.sObjectType.Automation__c.fields.Name.IsCreateable() && Schema.sObjectType.Automation__c.fields.Description__c.isCreateable() && Schema.sObjectType.Automation__c.fields.WB_Template__c.isCreateable()){
            insert newAutomation;
        }
        return newAutomation;
    }

    /**
    * Method Name : updateAutomation
    * @description : Update Automation record
    * @param recordId Id value
    * @param name String value
    * @param description String value
    * @param templateId Id value
    * @return Automation__c record
    */
    @AuraEnabled
    public static Automation__c updateAutomation(Id recordId, String name, String description, Id templateId) {
        Automation__c recordToUpdate = [SELECT Id, Name, Description__c, WB_Template__c FROM Automation__c WHERE Id = :recordId WITH SECURITY_ENFORCED LIMIT 1];

        if (Schema.sObjectType.Automation__c.fields.Name.isUpdateable()) {
            recordToUpdate.Name = name;
        }
        if (Schema.sObjectType.Automation__c.fields.Description__c.isUpdateable()) {
            recordToUpdate.Description__c = description;
        }
        if (Schema.sObjectType.Automation__c.fields.WB_Template__c.isUpdateable()) {
            recordToUpdate.WB_Template__c = templateId;
        }

        update recordToUpdate;
        return recordToUpdate;
    }

    /**
    * Method Name : deleteAutomation
    * @description : Delete Automation record
    * @param recordId Id value
    * @return void
    */
    @AuraEnabled
    public static void deleteAutomation(Id recordId) {
        if (!Schema.sObjectType.Automation__c.isDeletable()) {
            throw new SecurityException('You do not have permission to delete this record.');
        }
        
        Automation__c recordToDelete = [SELECT Id FROM Automation__c WHERE Id = :recordId WITH SECURITY_ENFORCED LIMIT 1];        
        delete recordToDelete;
    }
}
