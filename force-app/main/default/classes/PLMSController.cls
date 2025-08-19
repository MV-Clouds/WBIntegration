global without sharing class PLMSController {
    
    global static void getPLMSValidity(Boolean doSchedule) {}

    global static void getPLMSValidity(){
        getPLMSValidityFutureCall();
    }
    
    @Future(callout=true)
    global static void getPLMSValidityFutureCall() {
        List<MVWB__LicenseConfig__c> configList = [SELECT Id, MVWB__Is_License_Valid__c, MVWB__Expiration_Date__c, MVWB__Next_Callout_Date__c FROM MVWB__LicenseConfig__c LIMIT 1];
        MVWB__LicenseConfig__c config = new MVWB__LicenseConfig__c();
        if(configList != null && configList.size() > 0){
            config = configList[0];
        } else {
            ExceptionHandler.logException(new Map<String, Object>{'className' => 'PLMSController', 'methodName' => 'getPLMSValidityFutureCall', 'exceptionObj' => null, 'isApiException' => true, 'statusCode' => null, 'chatId' => null, 'moreDetails' => 'No License Config Found', 'apiResponse' => null});
            sendEmail(null, true);
            // return;
        }
        try {
            String currentOrgId = UserInfo.getOrganizationId();
            String productName = 'WBConnect';
            String endpoint = 'https://mvcloudsprivatelimited.my.salesforce-sites.com/services/apexrest/product-subscriber?orgId=' + currentOrgId + '&productName=' + productName;
            // Sandbox Endpint - https://mvcloudsprivatelimited--plms.sandbox.my.salesforce-sites.com
            // Production Endpoint - https://mvcloudsprivatelimited.my.salesforce-sites.com

            HttpRequest req = new HttpRequest();
            req.setEndpoint(endpoint);
            req.setMethod('GET');
            req.setHeader('Content-Type', 'application/json');
            
            Http http = new Http();
            HttpResponse res = http.send(req);
            
            Map<String, Object> authResponse = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            System.debug(authResponse);
            
            if (res.getStatusCode() == 200 && authResponse !=  null) {
                String expirationStr = (String) authResponse.get('Expiration_DateTime__c');
                
                if(expirationStr != null && expirationStr != ''){
                    // Remove timezone offset (e.g., +0000)
                    if (expirationStr.contains('+')) {
                        expirationStr = expirationStr.substringBefore('+');
                    }
                    
                    // Remove milliseconds and replace 'T' with space
                    expirationStr = expirationStr.replace('T', ' ');
                    if (expirationStr.contains('.')) {
                        expirationStr = expirationStr.substringBefore('.');
                    }
                    
                    DateTime userExpirationDateTime = DateTime.valueOf(expirationStr);
                    Date expirationDate = userExpirationDateTime.date();
                    config.MVWB__Expiration_Date__c = expirationDate;
                    
                    if(expirationDate < Date.today()){
                        config.MVWB__Is_License_Valid__c = false;
                    } else if(expirationDate == Date.today()){
                        config.MVWB__Is_License_Valid__c = true;
                    } else {
                        config.MVWB__Is_License_Valid__c = true;
                        DateTime userNextCalloutTime = (userExpirationDateTime.date() <= Date.today().addMonths(1)) ? userExpirationDateTime.date() : Date.today().addMonths(1);
                        Date nextCalloutDate = userNextCalloutTime.date();
                        config.MVWB__Next_Callout_Date__c = nextCalloutDate;
                        
                        String cronExpression = '0 ' + userNextCalloutTime.minute() + ' ' + userNextCalloutTime.hour() + ' ' + userNextCalloutTime.day() + ' ' + userNextCalloutTime.month() + ' ? ' + userNextCalloutTime.year();
                        String jobName = 'WBConnect_InnerProcess_' + System.currentTimeMillis();
                        System.schedule(jobName, cronExpression, new PLMSValidityScheduler());
                    }
                    
                    upsert config;
                } else {
                    sendEmail(null, true);
                }
            } else {
                ExceptionHandler.logException(new Map<String, Object>{'className' => 'PLMSController', 'methodName' => 'getPLMSValidityFutureCall', 'exceptionObj' => null, 'isApiException' => true, 'statusCode' => res.getStatusCode(), 'chatId' => null, 'moreDetails' => 'Unable to authorize to Production Org', 'apiResponse' => res.getBody()});
                sendEmail(null, true);
            }
        } catch (Exception e) {
            ExceptionHandler.logException(new Map<String, Object>{'className' => 'PLMSController', 'methodName' => 'getPLMSValidityFutureCall', 'exceptionObj' => e, 'isApiException' => false, 'statusCode' => null, 'chatId' => null, 'moreDetails' => e.getMessage(), 'apiResponse' => null});
            sendEmail(null, true);
        }
    }
    
    @AuraEnabled
    public static Boolean checkLicenseUsablility(){
        try {
            List<MVWB__LicenseConfig__c> config = [SELECT Id, MVWB__Is_License_Valid__c, MVWB__Expiration_Date__c FROM MVWB__LicenseConfig__c LIMIT 1];
            if(config != null && config.size() > 0 && config[0].MVWB__Is_License_Valid__c && config[0].MVWB__Expiration_Date__c != null && config[0].MVWB__Expiration_Date__c > Date.today()){
                return true;
            } else {
                return false;
            }
        } catch (Exception e) {
            ExceptionHandler.logException(new Map<String, Object>{'className' => 'PLMSController', 'methodName' => 'checkLicenseUsablility', 'exceptionObj' => e, 'isApiException' => false, 'statusCode' => null, 'chatId' => null, 'moreDetails' => e.getMessage(), 'apiResponse' => null});
            return false;
        }
    }
    
    public static void sendEmail(DateTime expirationDate, Boolean isException){
        try {
            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
            List<String> emails = new List<String>{'wbconnect-support@mvclouds.com'};
            String[] to = emails;
            String emailBody = isException ? '<div style="font-family:Verdana;">Hello WBConnect Team,<br/><br/>This is the PLMS Validity email, An exception encountered while fetching PLMS validity. Please find the details below:<br/><br/><b>Org Id:</b> ' + UserInfo.getOrganizationId() + '<br/><br/>Please verify the expiration date with records & Kindly follow up with the package installer.</div>' : '<div style="font-family:Verdana;">Hello WBConnect Team,<br/><br/>This is the PLMS Validity email for the package in one of the subscriber orgs has been expired. Please find the details below:<br/><br/><b>Org Id:</b> ' + UserInfo.getOrganizationId() + '<br/><b>Expiration Date:</b> ' + expirationDate + '<br/><br/>Please verify the expiration date with records.</div>';
            email.setToAddresses(to);
            email.setSubject(isException ? 'WBConnect Package PLMS Expiry' : 'WBConnect Package PLMS Validity exception email');
            email.setHtmlBody(emailBody);
            Messaging.sendEmail(new Messaging.SingleEmailMessage[] { email });
        } catch (Exception e) {
            ExceptionHandler.logException(new Map<String, Object>{'className' => 'PLMSController', 'methodName' => 'sendEmail', 'exceptionObj' => e, 'isApiException' => false, 'statusCode' => null, 'chatId' => null, 'moreDetails' => e.getMessage(), 'apiResponse' => null});
        }
    }

    @AuraEnabled
    public static Map<String, Object> getPLMSValidityCustom(){
        List<MVWB__LicenseConfig__c> configList = [SELECT Id, MVWB__Is_License_Valid__c, MVWB__Expiration_Date__c, MVWB__Next_Callout_Date__c FROM MVWB__LicenseConfig__c LIMIT 1];
        MVWB__LicenseConfig__c config = new MVWB__LicenseConfig__c();
        if(configList != null && configList.size() > 0){
            config = configList[0];
        } else {
            ExceptionHandler.logException(new Map<String, Object>{'className' => 'PLMSController', 'methodName' => 'getPLMSValidityCustom', 'exceptionObj' => null, 'isApiException' => true, 'statusCode' => null, 'chatId' => null, 'moreDetails' => 'No License Config Found', 'apiResponse' => null});
            
            return new Map<String, Object>{'expirationDate' => null,'isLicenseValid' => false,'message' => 'Error'};
        }
        try {
            String currentOrgId = UserInfo.getOrganizationId();
            System.debug('Current Org Id: ' + currentOrgId);
            String productName = 'WBConnect';
            String endpoint = 'https://mvcloudsprivatelimited.my.salesforce-sites.com/services/apexrest/product-subscriber?orgId=' + currentOrgId + '&productName=' + productName;

            HttpRequest req = new HttpRequest();
            req.setEndpoint(endpoint);
            req.setMethod('GET');
            req.setHeader('Content-Type', 'application/json');
             
            Http http = new Http();
            HttpResponse res = http.send(req);
            System.debug('Response  ' + res.getBody());

            if (res.getBody() == 'No records found for the given OrgId'){
                ExceptionHandler.logException(new Map<String, Object>{'className' => 'PLMSController', 'methodName' => 'getPLMSValidityCustom', 'exceptionObj' => null, 'isApiException' => true, 'statusCode' => null, 'chatId' => null, 'moreDetails' => 'No License Config Found', 'apiResponse' => null});
            
                return new Map<String, Object>{'expirationDate' => null,'isLicenseValid' => false,'message' => 'Unexpected Error Occurred, Please contact package support.'};
            }
            
            Map<String, Object> authResponse = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            System.debug(authResponse);
            
            if (res.getStatusCode() == 200 && authResponse !=  null) {
                String expirationStr = (String) authResponse.get('Expiration_DateTime__c');
                
                if(expirationStr != null && expirationStr != ''){
                    // Remove timezone offset (e.g., +0000)
                    if (expirationStr.contains('+')) {
                        expirationStr = expirationStr.substringBefore('+');
                    }
                    
                    // Remove milliseconds and replace 'T' with space
                    expirationStr = expirationStr.replace('T', ' ');
                    if (expirationStr.contains('.')) {
                        expirationStr = expirationStr.substringBefore('.');
                    }
                    
                    DateTime userExpirationDateTime = DateTime.valueOf(expirationStr);
                    Date expirationDate = userExpirationDateTime.date();
                    config.MVWB__Expiration_Date__c = expirationDate;
                    
                    if(expirationDate < Date.today()){
                        config.MVWB__Is_License_Valid__c = false;
                    } else if(expirationDate == Date.today()){
                        config.MVWB__Is_License_Valid__c = true;
                    } else {
                        config.MVWB__Is_License_Valid__c = true;
                        DateTime userNextCalloutTime = (userExpirationDateTime.date() <= Date.today().addMonths(1)) ? userExpirationDateTime.date() : Date.today().addMonths(1);
                        Date nextCalloutDate = userNextCalloutTime.date();
                        config.MVWB__Next_Callout_Date__c = nextCalloutDate;
                        String cronExpression = '0 ' + userNextCalloutTime.minute() + ' ' + userNextCalloutTime.hour() + ' ' + userNextCalloutTime.day() + ' ' + userNextCalloutTime.month() + ' ? ' + userNextCalloutTime.year();
                        String jobName = 'WBConnect_InnerProcess_' + System.currentTimeMillis();
                        System.schedule(jobName, cronExpression, new PLMSValidityScheduler());
                    }
                    
                    upsert config;
                } else {
                    sendEmail(null, true);
                }

                return new Map<String, Object>{'expirationDate' => expirationStr,'isLicenseValid' => config.MVWB__Is_License_Valid__c,'message' => 'Success'};
            } else {
                ExceptionHandler.logException(new Map<String, Object>{'className' => 'PLMSController', 'methodName' => 'getPLMSValidityCustom', 'exceptionObj' => null, 'isApiException' => true, 'statusCode' => res.getStatusCode(), 'chatId' => null, 'moreDetails' => 'Unable to authorize to Production Org', 'apiResponse' => res.getBody()});
                sendEmail(null, true);

                return new Map<String, Object>{'expirationDate' => null,'isLicenseValid' => false,'message' => 'Error'};
            }
        } catch (Exception e) {
            ExceptionHandler.logException(new Map<String, Object>{'className' => 'PLMSController', 'methodName' => 'getPLMSValidityCustom', 'exceptionObj' => e, 'isApiException' => false, 'statusCode' => null, 'chatId' => null, 'moreDetails' => e.getMessage(), 'apiResponse' => null});
            sendEmail(null, true);

            return new Map<String, Object>{'expirationDate' => null,'isLicenseValid' => false,'message' => 'Error'};
        }
    }
}