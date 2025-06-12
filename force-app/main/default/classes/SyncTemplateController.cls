public with sharing class SyncTemplateController{
    // public SyncTemplateController() {
    // }
    @AuraEnabled
    public static Map<String, Object> syncTemplateData(){
        Map<String, Object> allMetaTemplatesMap = new Map<String, Object>();
        List<Template__c> allTemplatesMap = new List<Template__c>();
        Set<String> pendingTemplateNameList = new Set<String>();
        Set<String> templateNameList = new Set<String>();
        
        try{
            List<MVWB__WBConnect_Configuration__mdt> config = MVWB__WBConnect_Configuration__mdt.getAll().values();
            if (config == null || config.isEmpty()){
                throw new AuraHandledException('WBConnect metadata configuration missing.');
            }

            String accessToken = config[0].MVWB__Access_Token__c;
            String endpoint = config[0].MVWB__API_Endpoint__c + '/' + config[0].MVWB__API_Version__c + '/' + config[0].MVWB__Business_Account_Id__c + '/message_templates?limit=50';

            fetchAllMetaTemplates(endpoint, accessToken, allMetaTemplatesMap);
            allTemplatesMap = SyncTemplateController.fetchAllTemplates(config[0].MVWB__Business_Account_Id__c);
            // System.debug(allMetaTemplatesMap.size());
            // System.debug(allMetaTemplatesMap.keySet());
            // System.debug(allTemplatesMap.size());
            // System.debug(allTemplatesMap);
            for (Template__c templateList : allTemplatesMap){

                templateNameList.add(templateList.Template_Name__c);
            }

            for(String metaTemplateName : allMetaTemplatesMap.keySet()){
                if (!templateNameList.contains(metaTemplateName)){
                    pendingTemplateNameList.add(metaTemplateName);
                }  
            }
            System.debug('Pending Template Names: ' + pendingTemplateNameList);
            System.debug(pendingTemplateNameList.size());

        } catch (Exception e){
            throw new AuraHandledException('Error syncing template data: ' + e.getMessage());
        }
        return allMetaTemplatesMap;
    }

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

    private static List<Template__c> fetchAllTemplates(String BusinessId){
        return [Select Template_Name__c, Id
                From Template__c
                where WBBussiness_Id__c = :BusinessId];
    }

}