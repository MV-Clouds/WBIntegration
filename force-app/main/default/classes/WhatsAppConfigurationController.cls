/**
 * @description       : 
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             : 
 * @last modified on  : 12-16-2024
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
**/
public without sharing class WhatsAppConfigurationController {
    @AuraEnabled
    public static String saveConfiguration(String WhatsAppAppId, String WhatsAppAppSecret, String AccessToken, String PhoneNumberId) {

        try {
            
            WhatsAppConfiguration__mdt config = [SELECT Id, DeveloperName, MasterLabel, Access_token_for_WhatsApp__c, WhatsApp_App_Id__c, WhatsApp_App_Secret__c, WhatsApp_PhoneNumber_ID__c FROM WhatsAppConfiguration__mdt LIMIT 1];
            if (config == null) {
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
            instance3.field = 'WhatsApp_App_Id__c';
            instance3.value = WhatsAppAppId;
            mdata.values.add(instance3);
            
            Metadata.CustomMetadataValue instance4 = new Metadata.CustomMetadataValue();
            instance3.field = 'WhatsApp_App_Secret__c';
            instance3.value = WhatsAppAppSecret;
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