global with sharing class SyncFlowBatchClass implements Database.Batchable<Map<String, Object>>, Database.Stateful, Database.AllowsCallouts {

    public static List<MVWB__WBConnect_Configuration__mdt> config = [SELECT Id, MVWB__API_Endpoint__c, MVWB__API_Version__c, MVWB__Access_Token__c, MVWB__Business_Account_Id__c FROM MVWB__WBConnect_Configuration__mdt LIMIT 1];
    public static List<CustomNotificationType> cnType = [SELECT Id FROM CustomNotificationType WHERE DeveloperName = 'WBConnectNotification' LIMIT 1];
    
    global List<Flow__c> flowsToInsert = new List<Flow__c>();
    global List<Flow__c> flowsToUpdate = new List<Flow__c>();
    global List<Flow__c> flowsToDelete = new List<Flow__c>();
    global Map<String, Flow__c> existingFlows = new Map<String, Flow__c>();
    global List<Map<String, Object>> flowsToProcess;

    global SyncFlowBatchClass(List<Map<String, Object>> flowsToProcess) {
        this.flowsToProcess = flowsToProcess;
    }

    global Iterable<Map<String, Object>> start(Database.BatchableContext bc) {
        for (Flow__c f : [SELECT Id, Flow_Id__c, Status__c, Flow_JSON__c FROM Flow__c]) {
            if (f.Flow_Id__c != null) {
                this.existingFlows.put(f.Flow_Id__c, f);
            }
        }
        System.debug('Flows to process = ' + flowsToProcess);
        return flowsToProcess;
    }

    global void execute(Database.BatchableContext bc, List<Map<String, Object>> scope) {
        try {
            if (config == null || config.isEmpty()) {
                ExceptionHandler.logException(new Map<String, Object>{'className' => 'SyncFlowBatchClass', 'methodName' => 'execute', 'exceptionObj' => null, 'isApiException' => false, 'statusCode' => null, 'chatId' => null, 'moreDetails' => 'No Meta Configuration found for the user account.', 'apiResponse' => null});
                return;
            }

            Map<String, Object> flow = scope[0];
            String action = (String) flow.get('action');
            String metaId = (String) flow.get('metaId');
            String orgFlowId = (String) flow.get('id');

            if (action == 'CreateInOrg') {
                String flowJson = fetchFlowJsonForFlow(metaId, config[0].MVWB__API_Version__c, config[0].MVWB__Access_Token__c);
                Flow__c f = new Flow__c(
                    Flow_Id__c = metaId,
                    Flow_Name__c = (String) flow.get('name'),
                    Status__c = (String) flow.get('status'),
                    Category__c = (String) flow.get('category'),
                    Flow_JSON__c = flowJson
                );

                if (existingFlows.containsKey(metaId)) {
                    Flow__c orgFlow = existingFlows.get(metaId);
                    
                    System.debug('orgFlow = ' + orgFlow);
                    System.debug('flowJson = ' + flowJson);
                    // Update only if there's change
                    if (orgFlow.Status__c != (String) flow.get('status') || orgFlow.Flow_JSON__c != flowJson) {
                        f.Id = existingFlows.get(metaId).Id;
                        this.flowsToUpdate.add(f);
                    }
                } else {
                    this.flowsToInsert.add(f);
                }

            } else if (action == 'DeleteFromOrg') {
                if (orgFlowId != null) {
                    this.flowsToDelete.add(new Flow__c(Id = orgFlowId));
                }

            } else if (action == 'CreateInMeta') {
                String categoryStr = (String) flow.get('category');
                List<String> categories = categoryStr != null ? categoryStr.split(';') : new List<String>();
                if (categories.isEmpty()) categories.add('OTHER');
                String name = (String) flow.get('name');
                String templateType = (String) flow.get('templateType');
                String json = (String) flow.get('flowJson');

                String returnedFlowId = WhatsAppFlowController.createWhatsAppFlow(name, categories, json, templateType, false);
                this.flowsToUpdate.add(new Flow__c(Id = orgFlowId, Flow_Id__c = returnedFlowId, Status__c = 'Draft'));
            }
        } catch (Exception e) {
            ExceptionHandler.logException(new Map<String, Object>{'className' => 'SyncFlowBatchClass', 'methodName' => 'execute', 'exceptionObj' => e, 'isApiException' => false, 'statusCode' => null, 'chatId' => null, 'moreDetails' => e.getMessage(), 'apiResponse' => null});
        }
    }

    public static String fetchFlowJsonForFlow(String flowId, String version, String accessToken) {        
        try {
            String assetUrl = 'https://graph.facebook.com/' + version + '/' + flowId + '/assets';
            HttpRequest assetReq = new HttpRequest();
            assetReq.setEndpoint(assetUrl);
            assetReq.setMethod('GET');
            assetReq.setHeader('Authorization', 'Bearer ' + accessToken);
            
            Http assetHttp = new Http();
            HttpResponse assetRes = assetHttp.send(assetReq);
            
            System.debug('Response body for assets: ' + assetRes.getBody());
            if (assetRes.getStatusCode() == 200) {
                Map<String, Object> assetMap = (Map<String, Object>) JSON.deserializeUntyped(assetRes.getBody());
                List<Object> assets = (List<Object>) assetMap.get('data');
                
                for (Object obj : assets) {
                    Map<String, Object> asset = (Map<String, Object>) obj;
                    if (String.valueOf(asset.get('asset_type')) == 'FLOW_JSON') {
                        String downloadUrl = String.valueOf(asset.get('download_url'));
                        return downloadFlowJson(downloadUrl);
                    }
                }
            } else {
                System.debug('Asset fetch failed for flowId ' + flowId + ': ' + assetRes.getBody());
            }
        } catch (Exception e) {
            ExceptionHandler.logException(new Map<String, Object>{'className' => 'SyncFlowController', 'methodName' => 'fetchFlowJsonForFlow', 'exceptionObj' => e, 'isApiException' => false, 'statusCode' => null, 'chatId' => null, 'moreDetails' => e.getMessage(), 'apiResponse' => null});
        }
        return null;
    }

    public static String downloadFlowJson(String downloadUrl) {
        try {
            HttpRequest req = new HttpRequest();
            req.setEndpoint(downloadUrl);
            req.setMethod('GET');
            
            Http http = new Http();
            HttpResponse res = http.send(req);
            
            System.debug('Response body for downloadUrl: ' + res.getBody());
            if (res.getStatusCode() == 200) {
                return res.getBody();
            } else {
                ExceptionHandler.logException(new Map<String, Object>{'className' => 'SyncFlowController', 'methodName' => 'downloadFlowJson', 'exceptionObj' => null, 'isApiException' => true, 'statusCode' => res.getStatusCode(), 'chatId' => null, 'moreDetails' => null, 'apiResponse' => res.getBody()});
                System.debug('Failed to download flow JSON from: ' + downloadUrl);
                return null;
            }
        } catch (Exception e) {
            ExceptionHandler.logException(new Map<String, Object>{'className' => 'SyncFlowController', 'methodName' => 'downloadFlowJson', 'exceptionObj' => e, 'isApiException' => false, 'statusCode' => null, 'chatId' => null, 'moreDetails' => e.getMessage(), 'apiResponse' => null});
            return null;
        }
    }

    public void finish(Database.BatchableContext bc) {
        try {
            if (!flowsToInsert.isEmpty()) insert flowsToInsert;
            System.debug('flowsToUpdate = ' + flowsToUpdate);
            if (!flowsToUpdate.isEmpty()) update flowsToUpdate;
            if (!flowsToDelete.isEmpty()) delete flowsToDelete;

            if (cnType.isEmpty()) {
                System.debug('No WBConnectNotification Custom Notification Type found');
                return;
            }

            // Build valid PageReference JSON for the custom tab
            Map<String, Object> pageRef = new Map<String, Object>{
                'type' => 'standard__navItemPage',
                'attributes' => new Map<String, Object>{
                    'apiName' => 'Manage_WhatsApp_Flows' // Tab API Name
                }
            };

            // Prepare notification
            Messaging.CustomNotification customNotificationObj = new Messaging.CustomNotification();
            customNotificationObj.setTitle('WBConnect Flows Synced');
            customNotificationObj.setBody('Your WhatsApp flows have been successfully synced. Tap to view.');
            customNotificationObj.setNotificationTypeId(cnType[0].Id);
            customNotificationObj.setTargetPageRef(JSON.serialize(pageRef));

            // Send to batch initiator
            Set<String> addressees = new Set<String>{ UserInfo.getUserId() };
            customNotificationObj.send(addressees);

        } catch (Exception e) {
            ExceptionHandler.logException(new Map<String, Object>{'className' => 'SyncFlowBatchClass', 'methodName' => 'finish', 'exceptionObj' => e, 'isApiException' => false, 'statusCode' => null, 'chatId' => null, 'moreDetails' => e.getMessage(), 'apiResponse' => null});
        }
    }
}