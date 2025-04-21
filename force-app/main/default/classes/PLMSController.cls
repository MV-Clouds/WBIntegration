public with sharing class PLMSController {
    
    @AuraEnabled
    public static void getPLMSValidity() {
        try {
            LicenseConfig__c config = LicenseConfig__c.getInstance();
            // Define your Salesforce OAuth credentials
            String clientId = config.Client_Id__c;  // Consumer Key from Connected App
            String clientSecret = config.Client_Secret__c;  // Consumer Secret from Connected App
            String username = config.Username__c;
            String password = config.Password__c;
            String authEndpoint = 'https://login.salesforce.com/services/oauth2/token';
    
            // Step 1: Get Access Token
            HttpRequest req = new HttpRequest();
            req.setEndpoint(authEndpoint);
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
            req.setBody(
                'grant_type=password' +
                '&client_id=' + EncodingUtil.urlEncode(clientId, 'UTF-8') +
                '&client_secret=' + EncodingUtil.urlEncode(clientSecret, 'UTF-8') +
                '&username=' + EncodingUtil.urlEncode(username, 'UTF-8') +
                '&password=' + EncodingUtil.urlEncode(password, 'UTF-8')
            );
    
            Http http = new Http();
            HttpResponse res = http.send(req);
    
            if (res.getStatusCode() == 200) {
                Map<String, Object> authResponse = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                String accessToken = (String) authResponse.get('access_token');
    
                String currentOrgId = UserInfo.getOrganizationId();
                System.debug(currentOrgId);
                String soql = 'SELECT Id, Org_Id__c, Expiration_DateTime__c ' +
                            'FROM Product_Subscriber__c ' +
                            'WHERE Product__r.Name = \'WBConnect\' ' +
                            'AND Org_Id__c = \'' + currentOrgId + '\'' +
                            'ORDER BY CreatedDate DESC ' +
                            ' LIMIT 1';
    
                HttpRequest productReq = new HttpRequest();
                productReq.setEndpoint('https://mvcloudsprivatelimited.my.salesforce.com/services/data/v60.0/query?q=' + EncodingUtil.urlEncode(soql, 'UTF-8'));
                productReq.setMethod('GET');
                productReq.setHeader('Authorization', 'Bearer ' + accessToken);
    
                HttpResponse productRes = http.send(productReq);
    
                if (productRes.getStatusCode() == 200) {
                    // Parse the response JSON
                    Map<String, Object> jsonBody = (Map<String, Object>) JSON.deserializeUntyped(productRes.getBody());
                    List<Object> records = (List<Object>) jsonBody.get('records');
    
                    if (records!= null &&!records.isEmpty()) {
                        Map<String, Object> firstRecord = (Map<String, Object>) records[0];
                        String expirationStr = (String) firstRecord.get('Expiration_DateTime__c');
    
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
                            config.Expiration_Date__c = userExpirationDateTime;

                            if(userExpirationDateTime < Date.today()){
                                config.Is_License_Valid__c = false;
                            } else {
                                config.Is_License_Valid__c = true;
                                DateTime userNextCalloutTime = (userExpirationDateTime.date() <= Date.today().addMonths(1)) ? userExpirationDateTime : Date.today().addMonths(1);
                                config.Next_Callout_Date__c = userNextCalloutTime;

                                String cronExpression = '0 ' + userNextCalloutTime.minute() + ' ' + userNextCalloutTime.hour() + ' ' + userNextCalloutTime.day() + ' ' + userNextCalloutTime.month() + ' ? ' + userNextCalloutTime.year();
                                String jobName = 'PLMS_Validity_Check_' + System.currentTimeMillis();
                                System.schedule(jobName, cronExpression, new PLMSValidityScheduler());
                            }

                            upsert config;
                        }
                    } else {
                        ExceptionHandler.logException(new Map<String, Object>{'className' => 'PLMSController', 'methodName' => 'getPLMSValidity', 'exceptionObj' => null, 'isApiException' => true, 'statusCode' => productRes.getStatusCode(), 'chatId' => null, 'moreDetails' => 'Failed to fetch Expiration Date for Org Id ' + UserInfo.getOrganizationId(), 'apiResponse' => productRes.getBody()});
                    }
                } else {
                    ExceptionHandler.logException(new Map<String, Object>{'className' => 'PLMSController', 'methodName' => 'getPLMSValidity', 'exceptionObj' => null, 'isApiException' => true, 'statusCode' => productRes.getStatusCode(), 'chatId' => null, 'moreDetails' => 'Failed to fetch Product_Subscriber__c record for Org Id ' + UserInfo.getOrganizationId(), 'apiResponse' => productRes.getBody()});
                }
            } else {
                ExceptionHandler.logException(new Map<String, Object>{'className' => 'PLMSController', 'methodName' => 'getPLMSValidity', 'exceptionObj' => null, 'isApiException' => true, 'statusCode' => res.getStatusCode(), 'chatId' => null, 'moreDetails' => 'Unable to authorize to Production Org', 'apiResponse' => res.getBody()});
            }
        } catch (Exception e) {
            ExceptionHandler.logException(new Map<String, Object>{'className' => 'PLMSController', 'methodName' => 'getPLMSValidity', 'exceptionObj' => e, 'isApiException' => false, 'statusCode' => null, 'chatId' => null, 'moreDetails' => e.getMessage(), 'apiResponse' => null});
        }
    }

    @AuraEnabled
    public static Boolean checkLicenseUsablility(){
        try {
            LicenseConfig__c config = LicenseConfig__c.getInstance();
            if(config != null && config.Is_License_Valid__c && config.Expiration_Date__c != null && config.Expiration_Date__c > Date.today()){
                return true;
            } else {
                return false;
            }
        } catch (Exception e) {
            ExceptionHandler.logException(new Map<String, Object>{'className' => 'PLMSController', 'methodName' => 'checkLicenseUsablility', 'exceptionObj' => e, 'isApiException' => false, 'statusCode' => null, 'chatId' => null, 'moreDetails' => e.getMessage(), 'apiResponse' => null});
            return false;
        }
    }
}