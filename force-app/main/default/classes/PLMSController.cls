global without sharing class PLMSController {
    
    global static void getPLMSValidity(){}

    @AuraEnabled
    global static void getPLMSValidity(Boolean doSchedule) {
        List<MVWB__LicenseConfig__c> configList = [SELECT Id, MVWB__Is_License_Valid__c, MVWB__Expiration_Date__c, MVWB__Next_Callout_Date__c FROM MVWB__LicenseConfig__c LIMIT 1];
        MVWB__LicenseConfig__c config = new MVWB__LicenseConfig__c();
        if(configList != null && configList.size() > 0){
            config = configList[0];
        } else {
            ExceptionHandler.logException(new Map<String, Object>{'className' => 'PLMSController', 'methodName' => 'getPLMSValidity', 'exceptionObj' => null, 'isApiException' => true, 'statusCode' => null, 'chatId' => null, 'moreDetails' => 'No License Config Found', 'apiResponse' => null});
            return;
        }
        try {
            String currentOrgId = UserInfo.getOrganizationId();
            String productName = 'WBConnect';
            String endpoint = 'https://mvcloudsprivatelimited.my.salesforce-sites.com/services/apexrest/product-subscriber?orgId=' + currentOrgId + '&productName=' + productName;

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
                        
                        if(doSchedule) {
                            String cronExpression = '0 ' + userNextCalloutTime.minute() + ' ' + userNextCalloutTime.hour() + ' ' + userNextCalloutTime.day() + ' ' + userNextCalloutTime.month() + ' ? ' + userNextCalloutTime.year();
                            String jobName = 'PLMS_Validity_Check_' + System.currentTimeMillis();
                            System.schedule(jobName, cronExpression, new PLMSValidityScheduler());
                        }
                    }
                    
                    upsert config;
                } else {
                    setNextSchedule();
                }
            } else {
                ExceptionHandler.logException(new Map<String, Object>{'className' => 'PLMSController', 'methodName' => 'getPLMSValidity', 'exceptionObj' => null, 'isApiException' => true, 'statusCode' => res.getStatusCode(), 'chatId' => null, 'moreDetails' => 'Unable to authorize to Production Org', 'apiResponse' => res.getBody()});
                setNextSchedule();
            }
        } catch (Exception e) {
            ExceptionHandler.logException(new Map<String, Object>{'className' => 'PLMSController', 'methodName' => 'getPLMSValidity', 'exceptionObj' => e, 'isApiException' => false, 'statusCode' => null, 'chatId' => null, 'moreDetails' => e.getMessage(), 'apiResponse' => null});
            setNextSchedule();
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

    @AuraEnabled
    public static string getExpirationDate(){
        try {
            List<MVWB__LicenseConfig__c> configList = [SELECT Id, MVWB__Expiration_Date__c FROM MVWB__LicenseConfig__c LIMIT 1];
            if(configList != null && configList.size() > 0 && configList[0].MVWB__Expiration_Date__c != null){
                return String.valueOf(configList[0].MVWB__Expiration_Date__c);
            } else {
                return 'No Expiration Date Found';
            }
        } catch (Exception e) {
            ExceptionHandler.logException(new Map<String, Object>{'className' => 'PLMSController', 'methodName' => 'getExpirationDate', 'exceptionObj' => e, 'isApiException' => false, 'statusCode' => null, 'chatId' => null, 'moreDetails' => e.getMessage(), 'apiResponse' => null});
            throw new AuraHandledException(e.getMessage());
        }
    }

    
    public static void setNextSchedule(){
        try {
            List<MVWB__LicenseConfig__c> configList = [SELECT Id, MVWB__Is_License_Valid__c, MVWB__Expiration_Date__c, MVWB__Next_Callout_Date__c FROM MVWB__LicenseConfig__c LIMIT 1];
            MVWB__LicenseConfig__c config = new MVWB__LicenseConfig__c();
            if(configList != null && configList.size() > 0){
                config = configList[0];
                config.MVWB__Is_License_Valid__c = true;
                config.MVWB__Expiration_Date__c = Date.today().addDays(1);
                config.MVWB__Next_Callout_Date__c = Date.today().addDays(1);
                upsert config;
                
                DateTime userNextCalloutTime = Date.today().addDays(1);
                String cronExpression = '0 ' + userNextCalloutTime.minute() + ' ' + userNextCalloutTime.hour() + ' ' + userNextCalloutTime.day() + ' ' + userNextCalloutTime.month() + ' ? ' + userNextCalloutTime.year();
                String jobName = 'PLMS_Validity_Check_' + System.currentTimeMillis();
                System.schedule(jobName, cronExpression, new PLMSValidityScheduler());
                
                sendEmail(null, true);
            }
        } catch (Exception e) {
            ExceptionHandler.logException(new Map<String, Object>{'className' => 'PLMSController', 'methodName' => 'setNextSchedule', 'exceptionObj' => e, 'isApiException' => false, 'statusCode' => null, 'chatId' => null, 'moreDetails' => e.getMessage(), 'apiResponse' => null});
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
}