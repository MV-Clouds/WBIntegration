public with sharing class SyncTemplateController{
    // public SyncTemplateController() {
    // }
    @AuraEnabled
    public static SyncTemplateDataWrapper syncTemplateData(){
        Map<String, Object> allMetaTemplatesMap = new Map<String, Object>();
        List<Template__c> allTemplatesMap = new List<Template__c>();
        List<String> pendingTemplateNameList = new List<String>();
        Set<String> templateNameList = new Set<String>();
        Set<String> flowIdSet = new Set<String>();
        Map<String, String> allMetaFlowsMap = new Map<String, String>(); // id → name
        Map<String, String> pendingFlowIdToNameMap = new Map<String, String>();
        SyncTemplateDataWrapper synTemplateWrapper = new SyncTemplateDataWrapper();

        
        try{
            List<MVWB__WBConnect_Configuration__mdt> config = MVWB__WBConnect_Configuration__mdt.getAll().values();
            if (config == null || config.isEmpty()){
                throw new AuraHandledException('WBConnect metadata configuration missing.');
            }

            // Get first 50 meta templates from template library
            String accessToken = config[0].MVWB__Access_Token__c;
            String endpoint = config[0].MVWB__API_Endpoint__c + '/' + config[0].MVWB__API_Version__c + '/' + config[0].MVWB__Business_Account_Id__c + '/message_templates?limit=50';

            fetchAllMetaTemplates(endpoint, accessToken, allMetaTemplatesMap);
            allTemplatesMap = SyncTemplateController.fetchAllTemplates(config[0].MVWB__Business_Account_Id__c);

            for (Template__c templateList : allTemplatesMap){

                templateNameList.add(templateList.Template_Name__c);
            }

            for(String metaTemplateName : allMetaTemplatesMap.keySet()){
                if (!templateNameList.contains(metaTemplateName)){
                    pendingTemplateNameList.add(metaTemplateName+'');
                }  

                Map<String, Object> templateData = (Map<String, Object>) allMetaTemplatesMap.get(metaTemplateName);
                if (templateData != null && templateData.containsKey('components')) {
                    Object rawComponents = templateData.get('components');
                    if (rawComponents instanceof List<Object>) {
                        List<Object> components = (List<Object>) rawComponents;
                        for (Object comp : components) {
                            if (comp instanceof Map<String, Object>) {
                                Map<String, Object> component = (Map<String, Object>) comp;
                                if (component.containsKey('type') && String.valueOf(component.get('type')) == 'BUTTONS' &&
                                    component.containsKey('buttons')) {

                                    Object rawButtons = component.get('buttons');
                                    if (rawButtons instanceof List<Object>) {
                                        List<Object> buttons = (List<Object>) rawButtons;
                                        for (Object btnObj : buttons) {
                                            if (btnObj instanceof Map<String, Object>) {
                                                Map<String, Object> button = (Map<String, Object>) btnObj;
                                                if (button.containsKey('type') &&
                                                    String.valueOf(button.get('type')) == 'FLOW' &&
                                                    button.containsKey('flow_id')) {

                                                    String flowId = String.valueOf(button.get('flow_id'));
                                                    flowIdSet.add(flowId);
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Set<String> allFlowList = fetchAllFlows();
            flowIdSet.addAll(allFlowList);

            
            // Get first few meta flow from meta flow library
            String flowsEndpoint = config[0].MVWB__API_Endpoint__c + '/' + config[0].MVWB__API_Version__c + '/' + config[0].MVWB__Business_Account_Id__c + '/flows';
            fetchAllMetaFlows(flowsEndpoint, accessToken, allMetaFlowsMap);

            for (String metaFlowId : allMetaFlowsMap.keySet()) {
                if (!flowIdSet.contains(metaFlowId)) {
                    pendingFlowIdToNameMap.put(metaFlowId, allMetaFlowsMap.get(metaFlowId));
                }
            }

            // System.debug('Extracted Flow IDs: ' + flowIdSet);
            // System.debug('Pending Template Names: ' + pendingTemplateNameList);
            // System.debug(pendingTemplateNameList.size());
            // System.debug('Pending Flow IDs (not found in Salesforce): ' + pendingFlowIdToNameMap);

            synTemplateWrapper.pendingTemplateListName = pendingTemplateNameList;
            synTemplateWrapper.pendingFlowListNames = pendingFlowIdToNameMap.values();

        } catch (Exception e){
            throw new AuraHandledException('Error syncing template data: ' + e.getMessage());
        }
        return synTemplateWrapper;
    }

    //Recursively call next templates utill last template is not found
    private static void fetchAllMetaTemplates(String url, String accessToken, Map<String, Object> allMetaTemplatesMap){
        Http http = new Http();
        HttpRequest req = new HttpRequest();
        req.setEndpoint(url);
        req.setMethod('GET');
        req.setHeader('Authorization', 'Bearer ' + accessToken);

        HttpResponse res = http.send(req);
        if (res.getStatusCode() != 200){
            throw new AuraHandledException('Failed to fetch templates. Status Code: ' + res.getStatusCode());
        }

        Map<String, Object> responseMap = (Map<String, Object>)JSON.deserializeUntyped(res.getBody());

        if (responseMap.containsKey('data')){
            List<Object> templates = (List<Object>)responseMap.get('data');
            for (Object templateObj : templates){
                Map<String, Object> template = (Map<String, Object>)templateObj;
                String name = (String) template.get('name');
                allMetaTemplatesMap.put(name, template);
            }
        }

        // Recursively follow the next page if exists
        if (responseMap.containsKey('paging')){
            Map<String, Object> paging = (Map<String, Object>)responseMap.get('paging');
            if (paging != null && paging.containsKey('next')){
                String nextUrl = (String) paging.get('next');
                fetchAllMetaTemplates(nextUrl, accessToken, allMetaTemplatesMap); // 🔁 Recursive call
            }
        }
    }

    
    // Fetch all salesforce template list from template object record
    private static List<Template__c> fetchAllTemplates(String BusinessId){
        return [Select Template_Name__c, Id
                From Template__c
                where WBBussiness_Id__c = :BusinessId];
    }

    
    //Recursively call next templates utill last flow is not found
    private static void fetchAllMetaFlows(String url, String accessToken, Map<String, String> allMetaFlowsMap) {
        Http http = new Http();
        HttpRequest req = new HttpRequest();
        req.setEndpoint(url);
        req.setMethod('GET');
        req.setHeader('Authorization', 'Bearer ' + accessToken);

        HttpResponse res = http.send(req);
        if (res.getStatusCode() != 200){
            throw new AuraHandledException('Failed to fetch flows. Status Code: ' + res.getStatusCode());
        }

        Map<String, Object> responseMap = (Map<String, Object>)JSON.deserializeUntyped(res.getBody());

        if (responseMap.containsKey('data')){
            List<Object> flows = (List<Object>)responseMap.get('data');
            for (Object flowObj : flows){
                Map<String, Object> flow = (Map<String, Object>)flowObj;
                if (flow.containsKey('id') && flow.containsKey('name')) {
                    String id = String.valueOf(flow.get('id'));
                    String name = String.valueOf(flow.get('name'));
                    allMetaFlowsMap.put(id, name);
                }
            }
        }

        if (responseMap.containsKey('paging')){
            Map<String, Object> paging = (Map<String, Object>)responseMap.get('paging');
            if (paging != null && paging.containsKey('next')){
                String nextUrl = (String) paging.get('next');
                fetchAllMetaFlows(nextUrl, accessToken, allMetaFlowsMap); // 🔁 Recursive
            }
        }
    }

    // Fetch all salesforce flow list from Flow object record
    private static Set<String> fetchAllFlows() {
        Set<String> savedFlowIds = new Set<String>();
        for (Flow__c f : [SELECT Flow_Id__c FROM Flow__c WHERE Flow_Id__c != null]) {
            savedFlowIds.add(f.Flow_Id__c);
        }
        return savedFlowIds;
    }

    public class SyncTemplateDataWrapper {
       @AuraEnabled public List<String> pendingTemplateListName;
       @AuraEnabled public List<String> pendingFlowListNames;
   }

}