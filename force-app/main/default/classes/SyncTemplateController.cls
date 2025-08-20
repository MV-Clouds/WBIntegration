public with sharing class SyncTemplateController{
    
    // Stores mapping of template names to template metadata fetched from Meta
    public static Map<String, Object> metaToOrg = new Map<String, Object>();

    // Stores template names that exist in the organization but not in Meta
    public static Set<String> orgToMeta = new Set<String>();

    // Stores all template names available in the organization
    public static Map<String,String> organizationTemplatesList = new Map<String,String>();

    // Stores all flow IDs available in the organization
    public static Set<String> organizationFlowsList = new Set<String>();

    // Flag to check if any flow template exists
    public static Boolean isFlowTemplateExist = false;

    // Stores template names from Meta that are identified as flow templates
    public static Set<String> flowTemplatesList = new Set<String>();

    // Stores all template names available in Meta
    public static Set<String> metaTemplatesList = new Set<String>();

    public static List<MVWB__AWS_Config__c> configList = [SELECT Id, MVWB__AWS_Access_Key__c, MVWB__AWS_Secret_Access_Key__c, MVWB__S3_Bucket_Name__c, MVWB__S3_Region_Name__c, CreatedDate, LastModifiedDate FROM MVWB__AWS_Config__c WITH SECURITY_ENFORCED LIMIT 1];
    public static List<MVWB__WBConnect_Configuration__mdt> config = MVWB__WBConnect_Configuration__mdt.getAll().values();

    /**
     * Main entry point to synchronize templates between Organization and Meta.
     * - Fetches templates from Organization and Meta.
     * - Identifies templates missing in Meta (orgToMeta).
     * - Identifies templates missing in Organization (metaToOrg).
     * - Identifies flow templates and excludes them from comparison.
     * @return templateListWrapper - lists of missing templates and flow templates
     */
    @AuraEnabled
    public static templateListWrapper syncTemplate() {
        try {
            if (config == null || config.isEmpty()) {
                throw new AuraHandledException('WBConnect metadata configuration missing.');
            }

            String accessToken = config[0].MVWB__Access_Token__c;
            String endpoint = config[0].MVWB__API_Endpoint__c + '/' + config[0].MVWB__API_Version__c + '/' + config[0].MVWB__Business_Account_Id__c + '/message_templates?limit=500';


            // Fetch templates from organization
            organizationTemplatesList = fetchOrganizationTemplates();

            // Fetch templates from Meta
            fetchAllMetaTemplates(endpoint, accessToken);

            // Remove flow templates from meta-to-org comparison
            metaToOrg.keySet().removeAll(flowTemplatesList);

            System.debug('Organization Templates: ' + organizationTemplatesList);
            System.debug('Meta Templates: ' + metaTemplatesList);

            // Identify templates that exist in Org but not in Meta
            for (String templateName : organizationTemplatesList.keySet()) {
                if (!metaTemplatesList.contains(templateName)) {
                    orgToMeta.add(templateName);
                }
            }

            // Prepare response wrapper
            templateListWrapper wrapper = new templateListWrapper();
            wrapper.orgToMeta = new List<String>(orgToMeta);
            wrapper.metaToOrg = new List<String>(metaToOrg.keySet());
            wrapper.metaToOrgFlowTemplates = new List<String>(flowTemplatesList);
            return wrapper;

        } catch(Exception e) {
            ExceptionHandler.logException(new Map<String, Object>{
                'className' => 'SyncTemplateController',
                'methodName' => 'syncTemplate',
                'exceptionObj' => e,
                'isApiException' => false,
                'statusCode' => null,
                'chatId' => null,
                'moreDetails' => e.getMessage(),
                'apiResponse' => null
            });
            return null;
        }
    }

    /**
     * Fetches all template names available in the Organization for the given AccountId.
     * @param AccountId - ID of the account to fetch templates for
     * @return Set<String> - set of template names
     */
    public static Map<String,String> fetchOrganizationTemplates() {
        List<Template__c> orgTemplates = [
            SELECT Id,Template_Id__c ,Name, Template_Name__c 
            FROM Template__c 
            WITH SECURITY_ENFORCED
        ];
        Map<String,String> orgTemplateIds = new Map<String,String>();
        for (Template__c template : orgTemplates) {
            orgTemplateIds.put(template.Template_Name__c, template.Template_Id__c);
        }
        return orgTemplateIds;
    }

    /**
     * Fetches all flow IDs available in the Organization for the given AccountId.
     * @param AccountId - ID of the account to fetch flows for
     * @return Set<String> - set of flow IDs
     */
    public static Set<String> fetchOrganizationFlows(String AccountId) {
        List<Flow__c> orgFlows = [
            SELECT Id, Flow_Id__c 
            FROM Flow__c 
            WITH SECURITY_ENFORCED
        ];
        Set<String> orgFlowIds = new Set<String>();
        for (Flow__c flow : orgFlows) {
            orgFlowIds.add(flow.Flow_Id__c);
        }
        return orgFlowIds;
    }

    /**
     * Fetches templates from Meta API recursively until all pages are retrieved.
     * Also identifies flow templates by checking for button components of type FLOW.
     * @param url - API endpoint URL for fetching templates
     * @param accessToken - access token for authentication
     */
    private static void fetchAllMetaTemplates(String url, String accessToken) {
        Http http = new Http();
        HttpRequest req = new HttpRequest();
        req.setEndpoint(url);
        req.setMethod('GET');
        req.setHeader('Authorization', 'Bearer ' + accessToken);

        HttpResponse res = http.send(req);
        if (res.getStatusCode() != 200) {
            throw new AuraHandledException('Failed to fetch templates. Status Code: ' + res.getStatusCode());
        }

        Map<String, Object> responseMap = (Map<String, Object>)JSON.deserializeUntyped(res.getBody());

        if (responseMap.containsKey('data')) {
            List<Object> templates = (List<Object>)responseMap.get('data');
            for (Object templateObj : templates) {
                Map<String, Object> template = (Map<String, Object>)templateObj;
                String name = (String) template.get('name');

                if (!organizationTemplatesList.keySet().isEmpty() && !organizationTemplatesList.keySet().contains(name)) {
                    if (template != null && template.containsKey('components')) {
                        Object rawComponents = template.get('components');
                        if (rawComponents instanceof List<Object>) {
                            List<Object> components = (List<Object>)rawComponents;
                            for (Object comp : components) {
                                if (comp instanceof Map<String, Object>) {
                                    Map<String, Object> component = (Map<String, Object>)comp;
                                    if (component.containsKey('type') && String.valueOf(component.get('type')) == 'BUTTONS' && component.containsKey('buttons')) {
                                        Object rawButtons = component.get('buttons');
                                        if (rawButtons instanceof List<Object>) {
                                            List<Object> buttons = (List<Object>)rawButtons;
                                            for (Object btnObj : buttons) {
                                                if (btnObj instanceof Map<String, Object>) {
                                                    Map<String, Object> button = (Map<String, Object>)btnObj;
                                                    if (button.containsKey('type') && String.valueOf(button.get('type')) == 'FLOW' && button.containsKey('flow_id')) {
                                                        String flowId = String.valueOf(button.get('flow_id'));
                                                        if (!isFlowTemplateExist) {
                                                            isFlowTemplateExist = true;
                                                            organizationFlowsList = fetchOrganizationFlows(getUserAccount());
                                                        }
                                                        if (!organizationFlowsList.isEmpty() && !organizationFlowsList.contains(flowId)) {
                                                            flowTemplatesList.add(name);
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
                    metaToOrg.put(name, template);
                }
                metaTemplatesList.add(name);
            }

            // Check if there is a next page and fetch recursively
            if (responseMap.containsKey('paging')) {
                Map<String, Object> paging = (Map<String, Object>)responseMap.get('paging');
                if (paging != null && paging.containsKey('next')) {
                    String nextUrl = (String) paging.get('next');
                    fetchAllMetaTemplates(nextUrl, accessToken);
                }
            }
        }
    }

    public static templateListWrapper buildTemplateActionData(templateListWrapper wrapper, String selectedOrphanTemplateAction) {
        // templateListWrapper wrapper = new templateListWrapper();
        List<String> orgToMetaList = new List<String>(wrapper.orgToMeta);
        List<String> metaToOrgList = new List<String>(wrapper.metaToOrg);
        List<String> metaToOrgFlowTemplates = new List<String>(wrapper.metaToOrgFlowTemplates);
        List<Map<String,String>> templateEntry = new List<Map<String,String>>();
        System.debug('Selected Orphan Template Action: ' + selectedOrphanTemplateAction);

        for (String otm : orgToMetaList) {
            Map<String, String> entry = new Map<String, String>();
            entry.put('templateName', otm);
            entry.put('action', 'orgToMeta');
            entry.put('templateId',organizationTemplatesList.get(otm));
            entry.put('selectedOrphanTemplateAction', selectedOrphanTemplateAction);
            templateEntry.add(entry);
        }

        for (String mto : metaToOrgList) {
            Map<String, String> entry = new Map<String, String>();
            entry.put('templateName', mto);
            entry.put('action', 'metaToOrg');
            entry.put('templateId',null);
            entry.put('selectedOrphanTemplateAction', null);
            templateEntry.add(entry);
        }
        for (String flowTemplate : metaToOrgFlowTemplates) {
            Map<String, String> entry = new Map<String, String>();
            entry.put('templateName', flowTemplate);
            entry.put('action', 'metaToOrgFlowTemplate');
            entry.put('templateId',null);
            entry.put('selectedOrphanTemplateAction', selectedOrphanTemplateAction);
            templateEntry.add(entry);
        }
        wrapper.templateEntry = templateEntry;
        System.debug('wrapper.templateEntry = ' + wrapper.templateEntry);
        System.debug('wrapper.orgToMeta = ' + wrapper.orgToMeta);
        System.debug('wrapper.metaToOrg = ' + wrapper.metaToOrg);
        return wrapper;
    } 
    
    @AuraEnabled
    public static void confirmTemplateSync(String selectedOrphanTemplateAction, Boolean isSyncConfirmed, String wrapperFromClientJSON) {
        try {
            if (isSyncConfirmed) {
                System.debug('wrapperFromClientJSON = ' + wrapperFromClientJSON);
                System.debug('Selected Orphan Flow Action: ' + selectedOrphanTemplateAction);

                Map<String, Object> rawWrapper = (Map<String, Object>) JSON.deserializeUntyped(wrapperFromClientJSON);
                templateListWrapper wrapper = new templateListWrapper();

                // Assign values using helper
                wrapper.metaToOrg = toStringSet(rawWrapper.get('metaToOrg'));
                wrapper.orgToMeta = toStringSet(rawWrapper.get('orgToMeta'));
                wrapper.metaToOrgFlowTemplates = toStringSet(rawWrapper.get('metaToOrgFlowTemplates'));

                System.debug('wrapper.metaToOrg = ' + wrapper.metaToOrg);
                System.debug('wrapper.orgToMeta = ' + wrapper.orgToMeta); 
                System.debug('wrapper.metaToOrgFlowTemplates = ' + wrapper.metaToOrgFlowTemplates);

                templateListWrapper finalWrapper = buildTemplateActionData(wrapper, selectedOrphanTemplateAction);
                System.debug('Final TemplateToAction size = ' + finalWrapper.templateEntry);

                if(!Test.isRunningTest()){
                    SyncTemplateBatchClass batch = new SyncTemplateBatchClass(finalWrapper.templateEntry);
                    Database.executeBatch(batch, 1);
                }

            }

        }
        catch(Exception e){
            ExceptionHandler.logException(new Map<String, Object>{
                'className' => 'SyncTemplateController',
                'methodName' => 'confirmTemplateSync',
                'exceptionObj' => e,
                'isApiException' => false,
                'statusCode' => null,
                'chatId' => null,
                'moreDetails' => e.getMessage(),
                'apiResponse' => null
            });
        }
    }

    // Helper method to safely convert List<Object> to Set<String>
    private static List<String> toStringSet(Object obj) {
        List<String> result = new List<String>();
        if (obj != null) {
            for (Object o : (List<Object>) obj) {
                if (o != null) {
                    result.add((String) o);
                }
            }
        }
        return result;
    }


    /**
     * Gets the AccountId for the current logged-in user.
     * @return String - AccountId if found, otherwise null
     */
    public static String getUserAccount() {
        String userId = UserInfo.getUserId();
        // String userId = '005C4000005IWplIAG'; // Hardcoded for testing
        List<User> userRec = [
            SELECT Id, AccountId 
            FROM User 
            WHERE Id = :userId 
            LIMIT 1
        ];
        if (Test.isRunningTest()) {
            List<Account> accList = [SELECT Id FROM Account LIMIT 1];
            System.debug('Account List: ' + accList);
            return accList.isEmpty() ? null : accList.get(0).Id;
        }
        if (!userRec.isEmpty()) {
            return userRec[0].AccountId;
        } else {
            return null;
        }
    }
    /**
     * Wrapper class for returning lists of template differences between Organization and Meta.
     */
    public class templateListWrapper {
        @AuraEnabled
        public List<String> orgToMeta;               // Templates in Org but not in Meta
        @AuraEnabled
        public List<String> metaToOrg;               // Templates in Meta but not in Org
        @AuraEnabled
        public List<String> metaToOrgFlowTemplates;  // Flow templates from Meta
        @AuraEnabled
        public List<Map<String, String>> templateEntry; // List of template entries with action and selected action
    }
}