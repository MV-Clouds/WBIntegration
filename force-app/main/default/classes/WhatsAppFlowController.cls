public with sharing class WhatsAppFlowController {
    
    @AuraEnabled
    public static List<sObject> getWhatsAppFlows() {
        List<Flow__c> flowRecs = [SELECT Id, Flow_Name__c, Status__c, Flow_Id__c, Category__c, Template_Type__c, LastModifiedDate, CreatedDate FROM Flow__c WITH SECURITY_ENFORCED ORDER BY LastModifiedDate DESC];
        return flowRecs;
    }

    @AuraEnabled
    public static String getJSONData(String type) {
        String jsonString = '';
        try {
            List<MVWB__WBC_Flows_JSON__mdt> FlowJSON = [SELECT Id, MVWB__Default_JSON__c, MVWB__Collect_purchase_interest_JSON__c, MVWB__Customer_support_JSON__c, MVWB__Get_feedback_JSON__c, MVWB__Send_a_survey_JSON__c FROM MVWB__WBC_Flows_JSON__mdt WITH SECURITY_ENFORCED LIMIT 1];
            
            if(type == 'Default') {
                jsonString = FlowJSON[0].MVWB__Default_JSON__c;
            } else if(type == 'Collect purchase interest') {
                jsonString = FlowJSON[0].MVWB__Collect_purchase_interest_JSON__c;
            } else if(type == 'Get feedback') {
                jsonString = FlowJSON[0].MVWB__Get_feedback_JSON__c;
            } else if(type == 'Send a survey') {
                jsonString = FlowJSON[0].MVWB__Send_a_survey_JSON__c;
            } else if(type == 'Customer support') {
                jsonString = FlowJSON[0].MVWB__Customer_support_JSON__c;
            }
        } catch (Exception e) {
            System.debug('Error retrieving or parsing JSON: ' + e.getMessage());
            ExceptionHandler.logException(new Map<String, Object>{'className' => 'WhatsAppFlowController', 'methodName' => 'getJSONData', 'exceptionObj' => e, 'isApiException' => false, 'statusCode' => null, 'chatId' => null, 'moreDetails' => 'Could not save the embedded sign up details in the metadata!', 'apiResponse' => null });
        }
        return jsonString;
    }

    @AuraEnabled
    public static String createWhatsAppFlow(String flowName, List<String> categories, String flowJson, String templateType) {
        try {
            List<MVWB__WBConnect_Configuration__mdt> wbConfig = MVWB__WBConnect_Configuration__mdt.getAll().values(); 

            String accessToken = wbConfig[0].MVWB__Access_Token__c;
            String endpoint = 'https://graph.facebook.com/v21.0/' + wbConfig[0].MVWB__Business_Account_Id__c + '/flows';
            HttpRequest request = new HttpRequest();
            request.setEndpoint(endpoint);
            request.setMethod('POST');
            request.setHeader('Authorization', 'Bearer ' + accessToken);
            request.setHeader('Content-Type', 'application/json');
            
            String payload = JSON.serialize(new Map<String, Object>{
                'categories' => categories,
                'name' => flowName,
                'flow_json' => flowJson
            });
            request.setBody(payload);
            Http http = new Http();
            HttpResponse response = http.send(request);
            
            if (response.getStatusCode() == 200) {
                Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
                String flowId = (String) responseMap.get('id');

                // Create a new Flow record
                Flow__c flow = new Flow__c();
                flow.Flow_Name__c = flowName;
                flow.Status__c = 'Draft';
                flow.Flow_Id__c = flowId;
                flow.Flow_JSON__c = flowJson;
                flow.Category__c = String.join(categories, ';');
                flow.Template_Type__c = templateType;

                insert flow;
                return flowId;
            } else {
                Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
                Map<String, Object> errorMap = (Map<String, Object>) responseMap.get('error');
                String errorMessage = (String) errorMap.get('error_user_msg');
                return 'Failed to create flow : ' + errorMessage;
            }
        } catch (Exception e) {
            ExceptionHandler.logException(new Map<String, Object>{'className' => 'WhatsAppFlowController', 'methodName' => 'createWhatsAppFlow', 'exceptionObj' => e, 'isApiException' => false, 'statusCode' => null, 'chatId' => null, 'moreDetails' => 'Could not save the embedded sign up details in the metadata!', 'apiResponse' => null });
            return 'Failed to create flow : ' + e.getMessage();
        }
    }

    @AuraEnabled
    public static String updateWhatsAppFlow(String flowId, String flowJson) {
        try {
            List<MVWB__WBConnect_Configuration__mdt> wbConfig = MVWB__WBConnect_Configuration__mdt.getAll().values(); 

            String accessToken = wbConfig[0].MVWB__Access_Token__c;
            String endpoint = 'https://graph.facebook.com/v21.0/' + flowId + '/assets';
            HttpRequest request = new HttpRequest();
            request.setEndpoint(endpoint);
            request.setMethod('POST');
            request.setHeader('Authorization', 'Bearer ' + accessToken);
            request.setHeader('Content-Type', 'application/x-www-form-urlencoded');
            
            String payload = JSON.serialize(new Map<String, Object>{
                'file' => flowJson,
                'name' => 'flow.json',
                'asset_type' => 'FLOW_JSON'
            });
            request.setBody(payload);
            Http http = new Http();
            HttpResponse response = http.send(request);
            
            if (response.getStatusCode() == 200) {
                return 'sucess';
            } else {
                return 'failed';
            }
        } catch (Exception e) {
            ExceptionHandler.logException(new Map<String, Object>{'className' => 'WhatsAppFlowController', 'methodName' => 'updateWhatsAppFlow', 'exceptionObj' => e, 'isApiException' => false, 'statusCode' => null, 'chatId' => null, 'moreDetails' => 'Could not save the embedded sign up details in the metadata!', 'apiResponse' => null });
            return 'failed';
        }
    }

    @AuraEnabled
    public static String publishWhatsAppFlow(String flowId) {
        try {
            List<MVWB__WBConnect_Configuration__mdt> wbConfig = MVWB__WBConnect_Configuration__mdt.getAll().values(); 

            String accessToken = wbConfig[0].MVWB__Access_Token__c;
            String endpoint = 'https://graph.facebook.com/v21.0/' + flowId + '/publish';
            HttpRequest request = new HttpRequest();
            request.setEndpoint(endpoint);
            request.setMethod('POST');
            request.setHeader('Authorization', 'Bearer ' + accessToken);
            Http http = new Http();
            HttpResponse response = http.send(request);
            
            if (response.getStatusCode() == 200) {
                Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
                Boolean successVal = (Boolean) responseMap.get('success');
                if(successVal == true) {
                    List<Flow__c> flowRecs = [SELECT Id, Status__c, Flow_Id__c FROM Flow__c WHERE Flow_Id__c = :flowId WITH SECURITY_ENFORCED LIMIT 1];
                    if(flowRecs.size() > 0){
                        flowRecs[0].Status__c = 'Published';
                        update as user flowRecs;
                    }
                    return 'success';
                } else {
                    return 'Failed to publish flow';
                }
            } else {
                return 'Failed to publish flow : ' + response.getBody();
            }
        } catch (Exception e) {
            ExceptionHandler.logException(new Map<String, Object>{'className' => 'WhatsAppFlowController', 'methodName' => 'publishWhatsAppFlow', 'exceptionObj' => e, 'isApiException' => false, 'statusCode' => null, 'chatId' => null, 'moreDetails' => 'Could not save the embedded sign up details in the metadata!', 'apiResponse' => null });
            return 'Failed to publish flow : ' + e.getMessage();
        }
    }

    @AuraEnabled
    public static String deleteWhatsAppFlow(String flowId) {
        try {
            List<MVWB__WBConnect_Configuration__mdt> wbConfig = MVWB__WBConnect_Configuration__mdt.getAll().values(); 

            String accessToken = wbConfig[0].MVWB__Access_Token__c;
            String endpoint = 'https://graph.facebook.com/v21.0/' + flowId;
            HttpRequest request = new HttpRequest();
            request.setEndpoint(endpoint);
            request.setMethod('DELETE');
            request.setHeader('Authorization', 'Bearer ' + accessToken);
            Http http = new Http();
            HttpResponse response = http.send(request);
            
            if (response.getStatusCode() == 200) {
                List<Flow__c> flowRecs = [SELECT Id, Status__c, Flow_Id__c FROM Flow__c WHERE Flow_Id__c = :flowId WITH SECURITY_ENFORCED LIMIT 1];
                if(flowRecs.size() > 0){
                    delete as user flowRecs[0];
                }
                return 'sucess';
            } else {
                return 'failed';
            }
        } catch (Exception e) {
            ExceptionHandler.logException(new Map<String, Object>{'className' => 'WhatsAppFlowController', 'methodName' => 'deleteWhatsAppFlow', 'exceptionObj' => e, 'isApiException' => false, 'statusCode' => null, 'chatId' => null, 'moreDetails' => 'Could not save the embedded sign up details in the metadata!', 'apiResponse' => null });
            return 'failed';
        }
    }

    @AuraEnabled
    public static String deprecateWhatsAppFlow(String flowId) {
        try {
            List<MVWB__WBConnect_Configuration__mdt> wbConfig = MVWB__WBConnect_Configuration__mdt.getAll().values(); 

            String accessToken = wbConfig[0].MVWB__Access_Token__c;
            String endpoint = 'https://graph.facebook.com/v21.0/' + flowId + '/deprecate';
            HttpRequest request = new HttpRequest();
            request.setEndpoint(endpoint);
            request.setMethod('POST');
            request.setHeader('Authorization', 'Bearer ' + accessToken);
            Http http = new Http();
            HttpResponse response = http.send(request);
            
            if (response.getStatusCode() == 200) {
                List<Flow__c> flowRecs = [SELECT Id, Status__c, Flow_Id__c FROM Flow__c WHERE Flow_Id__c = :flowId WITH SECURITY_ENFORCED LIMIT 1];
                if(flowRecs.size() > 0){
                    flowRecs[0].Status__c = 'Deprecated';
                    update as user flowRecs[0];
                }
                return 'sucess';
            } else {
                return 'failed';
            }
        } catch (Exception e) {
            ExceptionHandler.logException(new Map<String, Object>{'className' => 'WhatsAppFlowController', 'methodName' => 'deprecateWhatsAppFlow', 'exceptionObj' => e, 'isApiException' => false, 'statusCode' => null, 'chatId' => null, 'moreDetails' => 'Could not save the embedded sign up details in the metadata!', 'apiResponse' => null });
            return 'failed';
        }
    }

    @AuraEnabled
    public static String getPreviewURLofWhatsAppFlow(String flowId) {
        try {
            List<MVWB__WBConnect_Configuration__mdt> wbConfig = MVWB__WBConnect_Configuration__mdt.getAll().values(); 

            String accessToken = wbConfig[0].MVWB__Access_Token__c;
            String endpoint = 'https://graph.facebook.com/v21.0/' + flowId + '?fields=preview.invalidate(false)';
            HttpRequest request = new HttpRequest();
            request.setEndpoint(endpoint);
            request.setMethod('GET');
            request.setHeader('Authorization', 'Bearer ' + accessToken);
            Http http = new Http();
            HttpResponse response = http.send(request);
            
            if (response.getStatusCode() == 200) {
                Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
                Map<String, Object> previewMap = (Map<String, Object>) responseMap.get('preview');
                String previewUrl = (String) previewMap.get('preview_url');
                return previewUrl;
            } else {
                return 'failed';
            }
        } catch (Exception e) {
            ExceptionHandler.logException(new Map<String, Object>{'className' => 'WhatsAppFlowController', 'methodName' => 'getPreviewURLofWhatsAppFlow', 'exceptionObj' => e, 'isApiException' => false, 'statusCode' => null, 'chatId' => null, 'moreDetails' => 'Could not save the embedded sign up details in the metadata!', 'apiResponse' => null });
            return 'failed';
        }
    }
}