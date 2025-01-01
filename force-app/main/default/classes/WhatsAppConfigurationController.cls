/**
 * @description       : 
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             : 

 * @last modified on  : 12-23-2024
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
**/
public without sharing class WhatsAppConfigurationController {

    @AuraEnabled
    public static WBConnect_Configuration__mdt getConfiguration(){

        WBConnect_Configuration__mdt config = new WBConnect_Configuration__mdt();
        try {
            List<WBConnect_Configuration__mdt> Configlist = [SELECT Id, DeveloperName, MasterLabel, Access_Token__c, Application_Id__c, Business_Account_Id__c, Phone_Number_Id__c FROM WBConnect_Configuration__mdt LIMIT 1];
            if(!Configlist.isEmpty()){
                config = Configlist[0];
            } else{
                config.Access_Token__c = '';
                config.Phone_Number_Id__c = '';
                config.Application_Id__c = '';
                config.Business_Account_Id__c = '';
            }
        } catch (Exception e) {
            ExceptionHandler.logException(new Map<String, Object>{ 'className' => 'WhatsAppConfigurationController', 'methodName' => 'getConfiguration', 'exceptionObj' => e, 'isApiException' => false, 'statusCode' => null, 'chatId' => null, 'moreDetails' => e.getMessage(), 'apiResponse' => null });
        }
        return config;
    }

    @AuraEnabled
    public static String saveConfiguration(String WBAccountId, String AppId ,String AccessToken, String PhoneNumberId) {

        try {
            
            String devName = 'WBConnect_Configuration';
            String masterLabel = 'WBConnect_Configuration';
            List<WBConnect_Configuration__mdt> configList = [SELECT Id, DeveloperName, MasterLabel, Access_Token__c, Application_Id__c, Business_Account_Id__c, Phone_Number_Id__c FROM WBConnect_Configuration__mdt LIMIT 1];
            WBConnect_Configuration__mdt config = new WBConnect_Configuration__mdt();
            if (!configList.isEmpty()) {
                config = configList[0];
                devName = config.DeveloperName;
                masterLabel = config.MasterLabel;
            }
            Metadata.CustomMetadata mdata = new Metadata.CustomMetadata();
            mdata.fullName = 'WBConnect_Configuration__mdt.' + devName; 
            mdata.label = masterLabel;
            
            Metadata.CustomMetadataValue instance1 = new Metadata.CustomMetadataValue();
            instance1.field = 'Access_Token__c';
            instance1.value = AccessToken;
            mdata.values.add(instance1);
            
            Metadata.CustomMetadataValue instance2 = new Metadata.CustomMetadataValue();
            instance2.field = 'Phone_Number_Id__c';
            instance2.value = PhoneNumberId;
            mdata.values.add(instance2);
            
            Metadata.CustomMetadataValue instance3 = new Metadata.CustomMetadataValue();
            instance3.field = 'Business_Account_Id__c';
            instance3.value = WBAccountId;
            mdata.values.add(instance3);
            
            Metadata.CustomMetadataValue instance4 = new Metadata.CustomMetadataValue();
            instance4.field = 'Application_Id__c';
            instance4.value = AppId;
            mdata.values.add(instance4);

            Metadata.DeployContainer container = new Metadata.DeployContainer();
            container.addMetadata(mdata);
            
            Metadata.Operations.enqueueDeployment(container, null);

            return 'Success';
        }
        catch (Exception e) {
            ExceptionHandler.logException(new Map<String, Object>{ 'className' => 'WhatsAppConfigurationController', 'methodName' => 'saveConfiguration', 'exceptionObj' => e, 'isApiException' => false, 'statusCode' => null, 'chatId' => null, 'moreDetails' => e.getMessage(), 'apiResponse' => null });
            return 'Error';
        }
    }
}