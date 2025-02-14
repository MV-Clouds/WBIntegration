global class WhatsappConfigController {

    public static String whatsappBusinessAppId {get; set;}

    // Constructor to load the metadata record
    public WhatsappConfigController() {
        // Fetch the metadata record
        List<MVWB__WBConnect_Configuration__mdt  > metaList = [SELECT MasterLabel, MVWB__Business_Account_Id__c FROM MVWB__WBConnect_Configuration__mdt WITH SECURITY_ENFORCED];
        if(metaList.size() > 0){
            whatsappBusinessAppId = metaList[0].MVWB__Business_Account_Id__c;
        }else {
            whatsappBusinessAppId = '';
        }
    }

    @RemoteAction
    global static String saveFBLoginDetails(String sAccessToken, String phoneId, String wabaId, String appId){
        try{
            System.debug('sAccessToken ==> ' + sAccessToken);
            
            String tokenUrl = 'https://graph.facebook.com/v21.0/oauth/access_token?grant_type=fb_exchange_token&client_id=514916280628381&client_secret=6e1719dde4e730a3a55e0eab8899f62b&fb_exchange_token='+sAccessToken;
            HttpRequest req = new HttpRequest();
            req.setEndpoint(tokenUrl);
            req.setMethod('GET');
            req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
            Http http = new Http();
            HttpResponse res = http.send(req);
            System.debug('res:- '+res.getBody());
            
            if (res.getStatusCode() == 200) {
                System.debug('getBody'+res.getBody());
                Map<String, Object> responseBody1 = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                String accessToken = (String) responseBody1.get('access_token');
                System.debug('accessToken==>'+accessToken);
                System.debug('phoneNumberId ==>'+ phoneId);
                System.debug('whatsappBusinessAccountId ==>'+ wabaId);
                System.debug('Application Id ==>'+ appId);
                Boolean isSuccess = saveMetaData(accessToken, phoneId, wabaId, appId);
                if(isSuccess){
                    return wabaId;
                }
            }
        }catch(Exception e){
            System.debug('Error in saveFBLoginDetails : '+ e);
        }
        return null;
        
    }

    @RemoteAction
    global static Boolean unlinkAccount(){
        try{
            Boolean isSuccess = saveMetaData('', '', '', '');
            if(isSuccess){
                return true;
            }
        }catch(Exception e){
            System.debug('Error in unlinkAccount : '+ e);
        }
        return false;
    }
    
    
    public static Boolean saveMetaData(String accessToken, String phoneId, String wabaId, String appId){

        try {
            List<MVWB__WBConnect_Configuration__mdt  > metaList = [SELECT MasterLabel, DeveloperName FROM MVWB__WBConnect_Configuration__mdt WITH SECURITY_ENFORCED];

            Metadata.CustomMetadata mdata = new Metadata.CustomMetadata();
            if(metaList.size() > 0){
                mdata.fullName = 'MVWB__WBConnect_Configuration__mdt.' + metaList[0].DeveloperName; 
                mdata.label = metaList[0].MasterLabel;
            }else{
                mdata.fullName = 'MVWB__WBConnect_Configuration__mdt.WBConnect_Configuration'; 
                mdata.label = 'WB_Connect_Config_Details';
            }

            Metadata.CustomMetadataValue instance1 = new Metadata.CustomMetadataValue();
            instance1.field = 'MVWB__Business_Account_Id__c';
            instance1.value = wabaId;
            mdata.values.add(instance1);

            Metadata.CustomMetadataValue instance2 = new Metadata.CustomMetadataValue();
            instance2.field = 'MVWB__Phone_Number_Id__c';
            instance2.value = phoneId;
            mdata.values.add(instance2);

            Metadata.CustomMetadataValue instance3 = new Metadata.CustomMetadataValue();
            instance3.field = 'MVWB__Access_Token__c';
            instance3.value = accessToken;
            mdata.values.add(instance3);

            Metadata.CustomMetadataValue instance4 = new Metadata.CustomMetadataValue();
            instance4.field = 'MVWB__Application_Id__c';
            instance4.value = appId;
            mdata.values.add(instance4);


            Metadata.DeployContainer container = new Metadata.DeployContainer();
            container.addMetadata(mdata);

            Metadata.Operations.enqueueDeployment(container, null);

            return true;
            
        } catch (Exception e) {
            System.debug('Exception in updateOrCreateCustomMetadata ==> ' + e);
            return null;
        }

    }
    
}