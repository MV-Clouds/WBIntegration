public with sharing class SyncFlowController {
    public static List<MVWB__WBConnect_Configuration__mdt> config = [SELECT Id, MVWB__API_Endpoint__c, MVWB__API_Version__c, MVWB__Access_Token__c, MVWB__Business_Account_Id__c FROM MVWB__WBConnect_Configuration__mdt LIMIT 1];

    @AuraEnabled
    public static SyncFlowDataWrapper syncFlowData() {
        System.debug('syncFlowData called');
        Map<String, Map<String, Object>> allMetaFlowsMap = new Map<String, Map<String, Object>>(); // id → name
        Map<String, String> pendingFlowIdToNameMap = new Map<String, String>();
        SyncFlowDataWrapper syncFlowWrapper = new SyncFlowDataWrapper();
        List<Map<String, Object>> FlowsToAction = new List<Map<String, Object>>();

        try {
            if (config == null || config.isEmpty()) {
                ExceptionHandler.logException(new Map<String, Object>{'className' => 'SyncFlowController', 'methodName' => 'syncFlowData', 'exceptionObj' => null, 'isApiException' => false, 'statusCode' => null, 'chatId' => null, 'moreDetails' => 'No Meta Configuration found for the user account.', 'apiResponse' => null});
                return syncFlowWrapper;
            }

            // Get Meta flows from flow library
            String accessToken = config[0].MVWB__Access_Token__c;
            String flowsEndpoint = config[0].MVWB__API_Endpoint__c + '/' + config[0].MVWB__API_Version__c + '/' + config[0].MVWB__Business_Account_Id__c + '/flows';
            fetchAllMetaFlows(flowsEndpoint, accessToken, allMetaFlowsMap);
            syncFlowWrapper.allMetaFlowsMap = allMetaFlowsMap;

            // Get existing Org flows
            Set<String> allFlowList = fetchAllFlows();
            Map<String, Flow__c> allOrgFlowsMap = fetchAllOrgFlowRecords(allFlowList);

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

            // Add org-only flow names
            Map<Id, String> orgOnlyFlowNamesMap = new Map<Id, String>();
            if (!orgOnlyFlowIds.isEmpty()) {
                for (Flow__c flow : [SELECT Id, Flow_Name__c FROM Flow__c WHERE Flow_Id__c IN :orgOnlyFlowIds]) {
                    orgOnlyFlowNamesMap.put(flow.Id, flow.Flow_Name__c);
                }
            }
            syncFlowWrapper.orgOnlyFlowMap = orgOnlyFlowNamesMap;
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

    // Fetch all Org flow IDs
    private static Set<String> fetchAllFlows() {
        Set<String> savedFlowIds = new Set<String>();
        for (Flow__c  f : [SELECT Flow_Id__c FROM Flow__c WHERE Flow_Id__c != null]) {
            savedFlowIds.add(f.Flow_Id__c);
        }
        return savedFlowIds;
    }

    private static Map<String, Flow__c> fetchAllOrgFlowRecords(Set<String> FlowIds) {
        Map<String, Flow__c> flowMap = new Map<String, Flow__c>();
        for (Flow__c f : [SELECT Flow_Id__c, Status__c, Flow_JSON__c FROM Flow__c WHERE Flow_Id__c IN :FlowIds]) {
            flowMap.put(f.Flow_Id__c, f);
        }
        return flowMap;
    }

    public static SyncFlowDataWrapper buildFlowActionData(SyncFlowDataWrapper wrapper, String selectedOrphanFlowAction) {
        List<Map<String, Object>> FlowsToAction = new List<Map<String, Object>>();

        // Meta flows
        for (String metaFlowId : wrapper.allMetaFlowsMap.keySet()) {
            Map<String, Object> metaFlow = wrapper.allMetaFlowsMap.get(metaFlowId);
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
                'category' => categoriesString,
                'source' => 'meta',
                'action' => 'CreateInOrg'
            };
            FlowsToAction.add(flowEntry);
        }

        // Org-only flows
        if (wrapper.orgOnlyFlowMap != null && !wrapper.orgOnlyFlowMap.isEmpty()) {
            List<Flow__c> orgOnlyFlows = [SELECT Id, Flow_Name__c, Status__c, Flow_JSON__c, Category__c, Template_Type__c FROM Flow__c WHERE Id IN :wrapper.orgOnlyFlowMap.keySet()];
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

        wrapper.FlowsToAction = FlowsToAction;
        return wrapper;
    }

    @AuraEnabled
    public static void confirmFlowSync(String selectedOrphanFlowAction, Boolean isSyncConfirmed, String wrapperFromClientJSON) {
        try {
            if (isSyncConfirmed) {
                System.debug('wrapperFromClientJSON = ' + wrapperFromClientJSON);
                
                Map<String, Object> rawWrapper = (Map<String, Object>) JSON.deserializeUntyped(wrapperFromClientJSON);
                SyncFlowDataWrapper wrapper = new SyncFlowDataWrapper();

                // Safely assign pendingFlowListNames
                List<Object> rawList = (List<Object>) rawWrapper.get('pendingFlowListNames');
                List<String> stringList = new List<String>();
                for (Object o : rawList) {
                    stringList.add((String)o);
                }
                wrapper.pendingFlowListNames = stringList;

                // Safely assign orgOnlyFlowMap - convert String keys to Ids
                Map<String, Object> rawMap = (Map<String, Object>) rawWrapper.get('orgOnlyFlowMap');
                wrapper.orgOnlyFlowMap = new Map<Id, String>();

                if (rawMap != null) {
                    for (String key : rawMap.keySet()) {
                        wrapper.orgOnlyFlowMap.put((Id)key, (String)rawMap.get(key));
                    }
                }

                // Assign allMetaFlowsMap
                Map<String, Object> rawAllMetaFlowsMap = (Map<String, Object>) rawWrapper.get('allMetaFlowsMap');
                wrapper.allMetaFlowsMap = new Map<String, Map<String, Object>>();

                if (rawAllMetaFlowsMap != null) {
                    for (String flowId : rawAllMetaFlowsMap.keySet()) {
                        Object innerObj = rawAllMetaFlowsMap.get(flowId);

                        if (innerObj instanceof Map<String, Object>) {
                            wrapper.allMetaFlowsMap.put(flowId, (Map<String, Object>)innerObj);
                        }
                    }
                }

                // Assign FlowsToAction
                List<Object> rawFlowsToAction = (List<Object>) rawWrapper.get('FlowsToAction');
                wrapper.FlowsToAction = new List<Map<String, Object>>();

                if (rawFlowsToAction != null) {
                    for (Object item : rawFlowsToAction) {
                        if (item instanceof Map<String, Object>) {
                            wrapper.FlowsToAction.add((Map<String, Object>) item);
                        }
                    }
                }

                // Now use buildFlowActionData
                SyncFlowDataWrapper finalWrapper = buildFlowActionData(wrapper, selectedOrphanFlowAction);

                System.debug('Final FlowsToAction size: ' + finalWrapper.FlowsToAction.size());
                for (Map<String, Object> flow : finalWrapper.FlowsToAction) {
                    System.debug('Flow entry: ' + flow);
                }

                SyncFlowBatchClass batch = new SyncFlowBatchClass(finalWrapper.FlowsToAction);
                Database.executeBatch(batch, 1);
            }
        } catch (Exception e) {
            ExceptionHandler.logException(new Map<String, Object>{'className' => 'SyncFlowController', 'methodName' => 'confirmFlowSync', 'exceptionObj' => e, 'isApiException' => false, 'statusCode' => null, 'chatId' => null, 'moreDetails' => e.getMessage(), 'apiResponse' => null});
        }
    }

    public class SyncFlowDataWrapper {
        @AuraEnabled public List<String> pendingFlowListNames;
        @AuraEnabled public Map<Id, String> orgOnlyFlowMap;
        @AuraEnabled public Map<String, Map<String, Object>> allMetaFlowsMap;
        @AuraEnabled public List<Map<String, Object>> FlowsToAction;
    }
}