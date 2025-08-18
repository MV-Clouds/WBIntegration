public with sharing class SyncFlowController {
    public static List<MVWB__WBConnect_Configuration__mdt> config = [SELECT Id, MVWB__API_Endpoint__c, MVWB__API_Version__c, MVWB__Access_Token__c, MVWB__Business_Account_Id__c FROM MVWB__WBConnect_Configuration__mdt LIMIT 1];

    @AuraEnabled
    public static SyncFlowDataWrapper syncFlowData(String selectedOrphanFlowAction, Boolean isFlowSyncConfirm) {
        System.debug('syncFlowData called');
        Map<String, Map<String, Object>> allMetaFlowsMap = new Map<String, Map<String, Object>>(); // id → name
        Map<String, String> pendingFlowIdToNameMap = new Map<String, String>();
        SyncFlowDataWrapper syncFlowWrapper = new SyncFlowDataWrapper();
        List<Map<String, Object>> FlowsToAction = new List<Map<String, Object>>();

        try {
            if (config == null || config.isEmpty()) {
                throw new AuraHandledException('WBConnect metadata configuration missing.');
            }

            // Get Meta flows from flow library
            String accessToken = config[0].MVWB__Access_Token__c;
            String flowsEndpoint = config[0].MVWB__API_Endpoint__c + '/' + config[0].MVWB__API_Version__c + '/' + config[0].MVWB__Business_Account_Id__c + '/flows';
            fetchAllMetaFlows(flowsEndpoint, accessToken, allMetaFlowsMap);

            // Get existing Salesforce flows
            Set<String> allFlowList = fetchAllFlows();

            // Identify Meta-only and Org-only flows
            Set<String> metaFlowIds = new Set<String>(allMetaFlowsMap.keySet());
            Set<String> orgOnlyFlowIds = new Set<String>(allFlowList);
            orgOnlyFlowIds.removeAll(metaFlowIds); // flows in org but not in meta

            for (String metaFlowId : metaFlowIds) {
                if (!allFlowList.contains(metaFlowId)) {
                    pendingFlowIdToNameMap.put(metaFlowId, String.valueOf(allMetaFlowsMap.get(metaFlowId).get('name')));
                }
            }

            syncFlowWrapper.pendingFlowListNames = pendingFlowIdToNameMap.values();

            // NEW: Add org-only flow names
            Map<Id, String> orgOnlyFlowNamesMap = new Map<Id, String>();
            if (!orgOnlyFlowIds.isEmpty()) {
                for (Flow__c flow : [SELECT Id, Flow_Name__c FROM Flow__c WHERE Flow_Id__c IN :orgOnlyFlowIds]) {
                    orgOnlyFlowNamesMap.put(flow.Id, flow.Flow_Name__c);
                }
            }
            syncFlowWrapper.orgOnlyFlowMap = orgOnlyFlowNamesMap;

            // Only prepare JSON when syncing
            if (isFlowSyncConfirm) {

                // Only sync flows missing from org
                Map<String, Map<String, Object>> missingMetaFlowsMap = new Map<String, Map<String, Object>>();
                for (String flowId : pendingFlowIdToNameMap.keySet()) {
                    missingMetaFlowsMap.put(flowId, allMetaFlowsMap.get(flowId));
                }
                System.debug('missingMetaFlowsMap = ' + missingMetaFlowsMap);
                syncFlowWrapper.allMetaFlowsMap = missingMetaFlowsMap;
                syncFlowWrapper.flowJsonMap = fetchFlowJsonForEachFlow(allMetaFlowsMap.keySet(), accessToken, config[0].MVWB__API_Version__c);

                // Add Meta flows
                System.debug('allmetaflowsmap = ' + allMetaFlowsMap);
                for (String metaFlowId : allMetaFlowsMap.keySet()) {
                    Map<String, Object> metaFlow = allMetaFlowsMap.get(metaFlowId);

                    System.debug('metaFlow = ' + metaFlow);

                    Object categoryObj = metaFlow.get('categories');
                    List<String> categoriesList = new List<String>();

                    if (categoryObj instanceof List<Object>) {
                        for (Object c : (List<Object>) categoryObj) {
                            categoriesList.add((String) c);
                        }
                    } else if (categoryObj instanceof String) {
                        categoriesList.add((String) categoryObj);
                    }
                    String categoriesString = String.join(categoriesList, ';');

                    Map<String, Object> flowEntry = new Map<String, Object>{
                        'metaId' => metaFlowId,
                        'name' => (String) metaFlow.get('name'),
                        'status' => metaFlow.containsKey('status') ? metaFlow.get('status') : null,
                        'flowJson' => syncFlowWrapper.flowJsonMap.get(metaFlowId),
                        'category' => categoriesString,
                        'templateType' => null,
                        'source' => 'meta',
                        'action' => 'CreateInOrg'
                    };
                    FlowsToAction.add(flowEntry);
                }

                // Add Org-only flows
                if (!orgOnlyFlowIds.isEmpty()) {
                    List<Flow__c> orgOnlyFlows = [ SELECT Id, Flow_Name__c, Status__c, Flow_JSON__c, Category__c, Template_Type__c FROM Flow__c WHERE Flow_Id__c IN :orgOnlyFlowIds];

                    for (Flow__c flow : orgOnlyFlows) {
                        Map<String, Object> flowEntry = new Map<String, Object>{
                            'id' => flow.Id,
                            'name' => flow.Flow_Name__c,
                            'status' => flow.Status__c,
                            'flowJson' => flow.Flow_JSON__c,
                            'category' => flow.Category__c,
                            'templateType' => flow.Template_Type__c,
                            'source' => 'org',
                            'action' => selectedOrphanFlowAction
                        };
                        FlowsToAction.add(flowEntry);
                    }
                }
                syncFlowWrapper.FlowsToAction = FlowsToAction;
                System.debug('FlowsToAction = ' + syncFlowWrapper.FlowsToAction);
            }
        } catch (Exception e) {
            System.debug('Full exception: ' + e);
            ExceptionHandler.logException(new Map<String, Object>{'className' => 'SyncFlowController', 'methodName' => 'syncFlowData', 'exceptionObj' => e, 
            'isApiException' => false, 'statusCode' => null, 'chatId' => null, 'moreDetails' => e.getMessage(), 'apiResponse' => null});
        }
        return syncFlowWrapper;
    }

    // Recursively fetch all Meta flows
    private static void fetchAllMetaFlows(String url, String accessToken, Map<String, Map<String, Object>> allMetaFlowsMap) {
        try {
            
            Http http = new Http();
            HttpRequest req = new HttpRequest();
            req.setEndpoint(url);
            req.setMethod('GET');
            req.setHeader('Authorization', 'Bearer ' + accessToken);
    
            HttpResponse res = http.send(req);
            System.debug('Response body: ' + res.getBody());
            if (res.getStatusCode() != 200) {
                ExceptionHandler.logException(new Map<String, Object>{'className' => 'SyncFlowController', 'methodName' => 'fetchAllMetaFlows', 'exceptionObj' => null, 'isApiException' => true, 'statusCode' => res.getStatusCode(), 'chatId' => null, 'moreDetails' => res.getBody(), 'apiResponse' => null});
            }
    
            Map<String, Object> responseMap = (Map<String, Object>)JSON.deserializeUntyped(res.getBody());
    
            if (responseMap.containsKey('data')) {
                List<Object> flows = (List<Object>)responseMap.get('data');
                for (Object flowObj : flows) {
                    Map<String, Object> flow = (Map<String, Object>)flowObj;
                    if (flow.containsKey('id') && flow.containsKey('name')) {
                        String id = String.valueOf(flow.get('id'));
                        Map<String, Object> innerMap = new Map<String, Object>();
                        innerMap.put('name', (String)flow.get('name'));
                        innerMap.put('status', (String)flow.get('status'));
                        List<Object> rawCategories = (List<Object>)flow.get('categories');
                        List<String> categoryList = new List<String>();
                        for (Object o : rawCategories) {
                            categoryList.add(String.valueOf(o));
                        }
                        innerMap.put('categories', categoryList);
                        allMetaFlowsMap.put(id, innerMap);
                    }
                }
            }
    
            if (responseMap.containsKey('paging')) {
                Map<String, Object> paging = (Map<String, Object>)responseMap.get('paging');
                if (paging != null && paging.containsKey('next')) {
                    String nextUrl = (String) paging.get('next');
                    fetchAllMetaFlows(nextUrl, accessToken, allMetaFlowsMap);
                }
            }
        } catch (Exception e) {
            ExceptionHandler.logException(new Map<String, Object>{'className' => 'SyncFlowController', 'methodName' => 'fetchAllMetaFlows', 'exceptionObj' => e, 'isApiException' => false, 'statusCode' => null, 'chatId' => null, 'moreDetails' => e.getMessage(), 'apiResponse' => null});
        }
    }

    // Fetch all Salesforce flow IDs
    private static Set<String> fetchAllFlows() {
        Set<String> savedFlowIds = new Set<String>();
        for (Flow__c  f : [SELECT Flow_Id__c FROM Flow__c WHERE Flow_Id__c != null]) {
            savedFlowIds.add(f.Flow_Id__c);
        }
        return savedFlowIds;
    }

    private static Map<String, String> fetchFlowJsonForEachFlow(Set<String> flowIds, String accessToken, String version) {
        Map<String, String> flowJsonMap = new Map<String, String>();
        
        for (String flowId : flowIds) {
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
                            String flowJson = downloadFlowJson(downloadUrl);
                            flowJsonMap.put(flowId, flowJson);
                            break;
                        }
                    }
                } else {
                    System.debug('Asset fetch failed for flowId ' + flowId + ': ' + assetRes.getBody());
                }
            } catch (Exception e) {
                ExceptionHandler.logException(new Map<String, Object>{'className' => 'SyncFlowController', 'methodName' => 'fetchFlowJsonForEachFlow', 'exceptionObj' => e, 'isApiException' => false, 'statusCode' => null, 'chatId' => null, 'moreDetails' => e.getMessage(), 'apiResponse' => null});
            }
        }
        return flowJsonMap;
    }

    private static String downloadFlowJson(String downloadUrl) {
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

    @AuraEnabled
    public static void confirmFlowSync(String selectedOrphanFlowAction, Boolean isSyncConfirmed) {
        try {
            SyncFlowDataWrapper wrapper = syncFlowData(selectedOrphanFlowAction, isSyncConfirmed);
            SyncFlowBatchClass batch = new SyncFlowBatchClass(wrapper.FlowsToAction);
            Database.executeBatch(batch, 1);
        } catch (Exception e) {
            ExceptionHandler.logException(new Map<String, Object>{'className' => 'SyncFlowController', 'methodName' => 'confirmFlowSync', 'exceptionObj' => e, 'isApiException' => false, 'statusCode' => null, 'chatId' => null, 'moreDetails' => e.getMessage(), 'apiResponse' => null});
        }
    }

    public class SyncFlowDataWrapper {
        @AuraEnabled public List<String> pendingFlowListNames;
        @AuraEnabled public Map<Id, String> orgOnlyFlowMap;
        @AuraEnabled public Map<String, Map<String, Object>> allMetaFlowsMap;
        public Map<String, String> flowJsonMap;
        @AuraEnabled public List<Map<String, Object>> FlowsToAction;
    }
}