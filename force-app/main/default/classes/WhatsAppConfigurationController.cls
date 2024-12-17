/**
 * @description       : 
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             : 

 * @last modified on  : 12-17-2024
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
**/
public without sharing class WhatsAppConfigurationController {
    @AuraEnabled
    public static String saveConfiguration(String WBAccountId, String AppId ,String AccessToken, String PhoneNumberId) {

        try {
            
            List<WhatsAppConfiguration__mdt> configList = [SELECT Id, DeveloperName, MasterLabel, Access_token_for_WhatsApp__c, WhatsApp_App_Id__c, Whatsapp_Account_ID__c, WhatsApp_PhoneNumber_ID__c FROM WhatsAppConfiguration__mdt LIMIT 1];
            WhatsAppConfiguration__mdt config = new WhatsAppConfiguration__mdt();
            if (!configList.isEmpty()) {
                config = configList[0];
            }
            Metadata.CustomMetadata mdata = new Metadata.CustomMetadata();
            mdata.fullName = 'WhatsAppConfiguration__mdt.' + config.DeveloperName; 
            mdata.label = config.MasterLabel;
            
            Metadata.CustomMetadataValue instance1 = new Metadata.CustomMetadataValue();
            instance1.field = 'Access_token_for_WhatsApp__c';
            instance1.value = AccessToken;
            mdata.values.add(instance1);
            
            Metadata.CustomMetadataValue instance2 = new Metadata.CustomMetadataValue();
            instance2.field = 'WhatsApp_PhoneNumber_ID__c';
            instance2.value = PhoneNumberId;
            mdata.values.add(instance2);
            
            Metadata.CustomMetadataValue instance3 = new Metadata.CustomMetadataValue();
            instance3.field = 'Whatsapp_Account_ID__c';
            instance3.value = WBAccountId;
            mdata.values.add(instance3);
            
            Metadata.CustomMetadataValue instance4 = new Metadata.CustomMetadataValue();
            instance4.field = 'WhatsApp_App_Id__c';
            instance4.value = AppId;
            mdata.values.add(instance4);

            Metadata.DeployContainer container = new Metadata.DeployContainer();
            container.addMetadata(mdata);
            
            Metadata.Operations.enqueueDeployment(container, null);

            return 'Success';
        }
        catch (Exception ex) {
            return 'Error';
        }
    }
}