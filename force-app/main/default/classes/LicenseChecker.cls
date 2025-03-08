public with sharing class LicenseChecker {
    private static final String NAMED_CREDENTIAL = 'Production_Org_NC';

    @InvocableMethod
    public static void checkLicense() {
        LicenseMetadata__mdt metadata = [SELECT Client_ID__c, Client_Secret__c FROM LicenseMetadata__mdt LIMIT 1];

        HttpRequest req = new HttpRequest();
        req.setEndpoint(URL.getOrgDomainUrl() + '/services/apexrest/PackageExpiration');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('Authorization', 'Bearer ' + getAccessToken(metadata));
        // req.setBody(JSON.serialize(new RequestBody()));
        req.setBody('');

        Http http = new Http();
        HttpResponse res = http.send(req);

        if (res.getStatusCode() == 200) {
            processResponse(res.getBody());
        }
    }

    private static String getAccessToken(LicenseMetadata__mdt metadata) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(metadata.Auth_Endpoint__c);
        req.setMethod('POST');
        req.setBody('grant_type=client_credentials&client_id=' + metadata.Client_ID__c + '&client_secret=' + metadata.Client_Secret__c);

        Http http = new Http();
        HttpResponse res = http.send(req);

        if (res.getStatusCode() == 200) {
            Map<String, Object> tokenResponse = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            return (String) tokenResponse.get('access_token');
        } else {
            throw new CalloutException('Failed to fetch access token');
        }
    }

    private static void processResponse(String responseBody) {
        Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(responseBody);
        Date expDate = Date.valueOf((String) responseMap.get('expirationDate'));

        LicenseConfig__c config = LicenseConfig__c.getInstance();
        config.Expiration_Date__c = expDate;
        
        if (expDate < Date.today()) {
            config.Is_License_Valid__c = false;
        } else {
            config.Is_License_Valid__c = true;
            config.Next_Callout_Date__c = (expDate <= Date.today().addDays(30)) ? expDate : Date.today().addDays(30);
        }
        upsert config;
    }

    @AuraEnabled
    public static Boolean checkLicenseUsablility(){
        LicenseConfig__c config = LicenseConfig__c.getInstance();
        if(config.Is_License_Valid__c){
            return true;
        }else{
            return false;
        }
    }
}