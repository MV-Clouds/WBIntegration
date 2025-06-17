public with sharing class SyncTemplateController{
    // public SyncTemplateController() {
    // }
    @AuraEnabled
    public static SyncTemplateDataWrapper syncTemplateData(Boolean isTemplateSyncConfirm){
        Map<String, Object> allMetaTemplatesMap = new Map<String, Object>();
        List<Template__c> allTemplatesMap = new List<Template__c>();
        List<String> pendingTemplateNameList = new List<String>();
        Set<String> templateNameList = new Set<String>();
        Set<String> flowIdSet = new Set<String>();
        Map<String, String> allMetaFlowsMap = new Map<String, String>(); // id → name
        Map<String, String> pendingFlowIdToNameMap = new Map<String, String>();
        SyncTemplateDataWrapper syncTemplateWrapper = new SyncTemplateDataWrapper();

        
        try{
            List<MVWB__WBConnect_Configuration__mdt> config = MVWB__WBConnect_Configuration__mdt.getAll().values();
            if (config == null || config.isEmpty()){
                throw new AuraHandledException('WBConnect metadata configuration missing.');
            }

            // Get first 500 meta templates from template library
            String accessToken = config[0].MVWB__Access_Token__c;
            String endpoint = config[0].MVWB__API_Endpoint__c + '/' + config[0].MVWB__API_Version__c + '/' + config[0].MVWB__Business_Account_Id__c + '/message_templates?limit=500';

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

            syncTemplateWrapper.pendingTemplateListName = pendingTemplateNameList;
            syncTemplateWrapper.pendingFlowListNames = pendingFlowIdToNameMap.values();
            if(isTemplateSyncConfirm){
                syncTemplateWrapper.allMetaTemplatesMap = allMetaTemplatesMap;
            }

        } catch (Exception e){
            throw new AuraHandledException('Error syncing template data: ' + e.getMessage());
        }
        return syncTemplateWrapper;
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
       @AuraEnabled public Map<String, Object> allMetaTemplatesMap;
   }

   
    // @AuraEnabled
    // public static void confirmTemplateSync(){
    //     SyncTemplateDataWrapper syncTemplateWrapper = syncTemplateData(true);
        
    //     for (String templateName : syncTemplateWrapper.allMetaTemplatesMap.keySet()) {
    //         Map<String, Object> templateData = (Map<String, Object>) syncTemplateWrapper.allMetaTemplatesMap.get(templateName);

    //         String metaTempId = (String) templateData.get('id');
    //         String metaTemplateStatus = (String) templateData.get('status');

    //         CreateTemplateWrapper.TemplateWrapper tw = new CreateTemplateWrapper.TemplateWrapper();
    //         tw.templateName = templateName;

    //         // 1. Set templateType from sub_category
    //         tw.templateType = (String) templateData.get('sub_category');

    //         // 2. Initialize
    //         tw.headAlternateTexts = new List<String>();
    //         tw.varAlternateTexts = new List<String>();

    //         List<Object> components = (List<Object>) templateData.get('components');
    //         for (Object compObj : components) {
    //             Map<String, Object> comp = (Map<String, Object>) compObj;
    //             String type = (String) comp.get('type');

    //             if (type == 'HEADER') {
    //                 if (comp.containsKey('example')) {
    //                     Map<String, Object> example = (Map<String, Object>) comp.get('example');
    //                     if (example.containsKey('header_handle')) {
    //                         List<Object> handleList = (List<Object>) example.get('header_handle');
    //                         for (Object h : handleList) {
    //                             tw.headAlternateTexts.add((String) h);
    //                         }
    //                         if (!handleList.isEmpty()) {
    //                             tw.tempImgUrl = (String) handleList[0];
    //                         }
    //                     }
    //                 }
    //             }

    //             if (type == 'BODY') {
    //                 tw.templateBody = (String) comp.get('text');
    //                 if (comp.containsKey('example')) {
    //                     Map<String, Object> example = (Map<String, Object>) comp.get('example');
    //                     if (example.containsKey('body_text')) {
    //                         List<Object> bodyTextList = (List<Object>) example.get('body_text');
    //                         for (Object groupBody : bodyTextList) {
    //                             for (Object val : (List<Object>) groupBody) {
    //                                 tw.varAlternateTexts.add((String) val);
    //                             }
    //                         }
    //                     }
    //                 }
    //             }
                
    //         }
            
    //         System.debug('metaTempId: ' + metaTempId);
    //         System.debug('metaTemplateStatus: ' + metaTemplateStatus);
    //         System.debug('templateData: ' + JSON.serialize(templateData));
    //         System.debug('TemplateWrapper: ' + JSON.serialize(tw));
    //     // Now you can call your method
    // }

    // }

    @AuraEnabled
    public static void confirmTemplateSync() {
        SyncTemplateDataWrapper syncTemplateWrapper = syncTemplateData(true);

        for (String templateName : syncTemplateWrapper.allMetaTemplatesMap.keySet()) {
            Map<String, Object> templateData = (Map<String, Object>) syncTemplateWrapper.allMetaTemplatesMap.get(templateName);

            String metaTempId = (String) templateData.get('id');
            String metaTemplateStatus = (String) templateData.get('status');

            CreateTemplateWrapper.TemplateWrapper tw = new CreateTemplateWrapper.TemplateWrapper();
            tw.templateName = templateName;
            tw.templateType = (String) templateData.get('sub_category');

            tw.headAlternateTexts = new List<String>();
            tw.varAlternateTexts = new List<String>();

            // --- Flags for templateMiscellaneousData ---
            Map<String, Object> miscFlags = new Map<String, Object>();
            Boolean addMedia = false, addHeaderVar = false, isHeaderText = false;
            Boolean isVisitSite = false, isCheckboxChecked = false, isFlowSelected = false;
            Boolean isFeatureEnabled = false, isImageFile = false, isVideoFile = false, isDocFile = false;
            Boolean isImgSelected = false, isVidSelected = false, isDocSelected = false;
            Boolean isImageFileUploader = false, isVideoFileUploader = false, isDocFileUploader = false;
            Boolean isFlowMarketing = false, isFlowUtility = false;

            List<Object> components = (List<Object>) templateData.get('components');
            for (Object compObj : components) {
                Map<String, Object> comp = (Map<String, Object>) compObj;
                String type = (String) comp.get('type');

                if (type == 'HEADER') {
                    String format = (String) comp.get('format');
                    tw.tempHeaderFormat = format;

                    if (format == 'IMAGE') {
                        isImageFile = true; isImgSelected = true; isImageFileUploader = true; addMedia = true;
                    } else if (format == 'VIDEO') {
                        isVideoFile = true; isVidSelected = true; isVideoFileUploader = true; addMedia = true;
                    } else if (format == 'DOCUMENT') {
                        isDocFile = true; isDocSelected = true; isDocFileUploader = true; addMedia = true;
                    } else if (format == 'TEXT') {
                        isHeaderText = true;
                    }

                    if (comp.containsKey('text') && !String.isEmpty((String) comp.get('text'))) {
                        addHeaderVar = true;
                        tw.tempHeaderText = (String) comp.get('text');
                    }

                    if (comp.containsKey('example')) {
                        Map<String, Object> example = (Map<String, Object>) comp.get('example');
                        if (example.containsKey('header_handle')) {
                            List<Object> handleList = (List<Object>) example.get('header_handle');
                            for (Object h : handleList) {
                                tw.headAlternateTexts.add((String) h);
                            }
                            if (!handleList.isEmpty()) {
                                tw.tempImgUrl = (String) handleList[0];
                            }
                        }
                    }
                }

                if (type == 'BODY') {
                    tw.templateBody = (String) comp.get('text');

                    if (comp.containsKey('example')) {
                        Map<String, Object> example = (Map<String, Object>) comp.get('example');
                        if (example.containsKey('body_text')) {
                            List<Object> bodyTextList = (List<Object>) example.get('body_text');
                            for (Object groupBody : bodyTextList) {
                                for (Object val : (List<Object>) groupBody) {
                                    tw.varAlternateTexts.add((String) val);
                                }
                            }
                        }
                    }
                }

                if (type == 'BUTTONS') {
                    List<Object> buttons = (List<Object>) comp.get('buttons');
                    for (Object buttonObj : buttons) {
                        Map<String, Object> button = (Map<String, Object>) buttonObj;
                        String buttonType = (String) button.get('type');
                        String buttonText = (String) button.get('text');

                        if (buttonType == 'URL') {
                            isVisitSite = true;
                            isCheckboxChecked = true;
                        }

                        if (buttonType == 'FLOW') {
                            isFlowSelected = true;

                            String category = (String) templateData.get('category');
                            if (category == 'MARKETING') isFlowMarketing = true;
                            else if (category == 'UTILITY') isFlowUtility = true;

                            List<Map<String, Object>> selectedFlows = new List<Map<String, Object>>();
                            Map<String, Object> flowInfo = new Map<String, Object>{
                                'type' => 'FLOW',
                                'text' => buttonText,
                                'flow_id' => button.get('flow_id')
                            };
                            selectedFlows.add(flowInfo);
                            tw.selectedFlow = JSON.serialize(selectedFlows);
                        }
                    }
                }
            }

            // Additional metadata
            Boolean isSecurityRecommedation = templateData.containsKey('add_security_recommendation') ? (Boolean) templateData.get('add_security_recommendation') : false;
            Boolean isCodeExpiration = templateData.containsKey('code_expiration_minutes');
            Integer expireTime = templateData.containsKey('message_send_ttl_seconds') ? (Integer) templateData.get('message_send_ttl_seconds') : null;

            // Assign to wrapper
            tw.isSecurityRecommedation = isSecurityRecommedation;
            tw.isCodeExpiration = isCodeExpiration;
            tw.expireTime = expireTime;

            // Finalize misc data
            miscFlags.put('isImageFile', isImageFile);
            miscFlags.put('isImgSelected', isImgSelected);
            miscFlags.put('isDocSelected', isDocSelected);
            miscFlags.put('isVidSelected', isVidSelected);
            miscFlags.put('isHeaderText', isHeaderText);
            miscFlags.put('addHeaderVar', addHeaderVar);
            miscFlags.put('addMedia', addMedia);
            miscFlags.put('isImageFileUploader', isImageFileUploader);
            miscFlags.put('isVideoFileUploader', isVideoFileUploader);
            miscFlags.put('isDocFileUploader', isDocFileUploader);
            miscFlags.put('isVideoFile', isVideoFile);
            miscFlags.put('isDocFile', isDocFile);
            miscFlags.put('isSecurityRecommedation', isSecurityRecommedation);
            miscFlags.put('isCodeExpiration', isCodeExpiration);
            miscFlags.put('expireTime', expireTime);
            miscFlags.put('isVisitSite', isVisitSite);
            miscFlags.put('isCheckboxChecked', isCheckboxChecked);
            miscFlags.put('isFlowMarketing', isFlowMarketing);
            miscFlags.put('isFlowUtility', isFlowUtility);
            miscFlags.put('isFlowSelected', isFlowSelected);
            miscFlags.put('isFeatureEnabled', isFeatureEnabled);

            tw.templateMiscellaneousData = JSON.serialize(miscFlags);

            // --- Final debug logs ---
            System.debug('metaTempId: ' + metaTempId);
            System.debug('metaTemplateStatus: ' + metaTemplateStatus);
            System.debug('templateData: ' + JSON.serialize(templateData));
            System.debug('TemplateWrapper: ' + JSON.serialize(tw));

            // If needed:
            processTemplateAfterSync(metaTempId, metaTemplateStatus, templateData, tw);
        }
    }


    public static Id processTemplateAfterSync(String metaTempId, String metaTemplateStatus, Map<String, Object> payload, CreateTemplateWrapper.TemplateWrapper templateWrapper) {
        Id templateId;
        try {
            // Always create a new Template__c record
            Template__c whatsAppTemplate = new Template__c();

            // Step 2: Update or set values from wrapper + payload
            whatsAppTemplate.Template_Id__c = String.isNotBlank(metaTempId) ? metaTempId : null;
            whatsAppTemplate.Template_Name__c = templateWrapper.templateName;
            whatsAppTemplate.Template_Category__c = templateWrapper.templateCategory;
            whatsAppTemplate.Language__c = templateWrapper.tempLanguage;
            whatsAppTemplate.Template_Type__c = templateWrapper.templateType;
            whatsAppTemplate.Template_Miscellaneous_Data__c = templateWrapper.templateMiscellaneousData;
            whatsAppTemplate.Status__c = formatStatus(metaTemplateStatus);

            // Step 3: Populate header
            if (templateWrapper.tempHeaderFormat == 'IMAGE' || templateWrapper.tempHeaderFormat == 'VIDEO' || templateWrapper.tempHeaderFormat == 'DOCUMENT') {
                whatsAppTemplate.Header_Type__c = templateWrapper.tempHeaderFormat;
                whatsAppTemplate.WBImage_Header_Handle__c = templateWrapper.tempHeaderHandle;
                whatsAppTemplate.File_Name__c = templateWrapper.tempImgName;
                whatsAppTemplate.WBHeader_Body__c = templateWrapper.tempImgUrl;
            } else {
                whatsAppTemplate.Header_Type__c = 'TEXT';
                whatsAppTemplate.WBHeader_Body__c = templateWrapper.tempHeaderText;
            }

            // Step 4: Populate footer and body
            whatsAppTemplate.WBFooter_Body__c = templateWrapper.tempFooterText;
            whatsAppTemplate.WBTemplate_Body__c = templateWrapper.templateBody;
            whatsAppTemplate.WBButton_Body__c = templateWrapper.url; // raw button payload JSON

            // Step 5: Insert template
            insert whatsAppTemplate;
            templateId = whatsAppTemplate.Id;

            // Step 6: Create Template_Variable__c records
            List<Template_Variable__c> varsToInsert = new List<Template_Variable__c>();
            String fixedObject = 'Account';
            String fixedField = 'AccountNumber';
            String fixedName = '{{' + fixedObject + '.' + fixedField + '}}';

            for (Integer i = 0; i < templateWrapper.headAlternateTexts.size(); i++) {
                varsToInsert.add(new Template_Variable__c(
                    Name = fixedName,
                    Type__c = 'Header',
                    Object_Name__c = fixedObject,
                    Field_Name__c = fixedField,
                    Alternate_Text__c = templateWrapper.headAlternateTexts[i],
                    Template__c = templateId
                ));
            }

            for (Integer i = 0; i < templateWrapper.varAlternateTexts.size(); i++) {
                varsToInsert.add(new Template_Variable__c(
                    Name = fixedName,
                    Type__c = 'Body',
                    Object_Name__c = fixedObject,
                    Field_Name__c = fixedField,
                    Alternate_Text__c = templateWrapper.varAlternateTexts[i],
                    Template__c = templateId
                ));
            }

            if (!varsToInsert.isEmpty()) {
                insert varsToInsert;
            }

        } catch (Exception e) {
            ExceptionHandler.logException(new Map<String, Object>{
                'className' => 'TemplateProcessor',
                'methodName' => 'processTemplateAfterSync',
                'exceptionObj' => e,
                'isApiException' => false,
                'moreDetails' => e.getMessage()
            });
        }

        return templateId;
    }

    private static String formatStatus(String status) {
        if (String.isBlank(status)) return 'In-Review';
        if (status == 'PENDING') return 'In-Review';
        if (status == 'REJECTED') return 'Rejected';
        if (status == 'APPROVED') return 'Active-Quality Pending';
        return status;
    }


}