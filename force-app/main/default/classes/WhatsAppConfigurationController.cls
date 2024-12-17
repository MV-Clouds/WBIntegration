/**
 * @description       : 
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             : 

 * @last modified on  : 12-17-2024
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
**/
public without sharing class WhatsAppConfigurationController {
    @AuraEnabled
    public static String saveConfiguration(String WBAccountId, String AccessToken, String PhoneNumberId) {

        try {
            
            List<WhatsAppConfiguration__mdt> config = [SELECT Id, DeveloperName, MasterLabel, Access_token_for_WhatsApp__c, Whatsapp_Account_ID__c, WhatsApp_PhoneNumber_ID__c FROM WhatsAppConfiguration__mdt LIMIT 1];
            if (config.isEmpty()) {
                config = new WhatsAppConfiguration__mdt();
                System.debug('null config');
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