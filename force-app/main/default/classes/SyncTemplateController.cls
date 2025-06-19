public with sharing class SyncTemplateController{
    // public SyncTemplateController() {
    // }

    public static List<MVWB__AWS_Config__c> configList = [SELECT Id, MVWB__AWS_Access_Key__c, MVWB__AWS_Secret_Access_Key__c, MVWB__S3_Bucket_Name__c, MVWB__S3_Region_Name__c, CreatedDate, LastModifiedDate FROM MVWB__AWS_Config__c WITH SECURITY_ENFORCED LIMIT 1];


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

   @AuraEnabled
    public static void confirmTemplateSync() {
        SyncTemplateDataWrapper wrapper = syncTemplateData(true);
        SyncTemplateBatchClass batch = new SyncTemplateBatchClass(wrapper.allMetaTemplatesMap);
        Database.executeBatch(batch, 1);
    }

    // @AuraEnabled
    // public static void confirmTemplateSync() {
    //     System.debug('Hello there line 267');
    //     SyncTemplateDataWrapper syncTemplateWrapper = syncTemplateData(true);

    //     List<String> allTemplateNames = new List<String>(syncTemplateWrapper.allMetaTemplatesMap.keySet());
    //     Integer batchSize = 5;

    //     for (Integer i = 0; i < allTemplateNames.size(); i += batchSize) {
    //         Integer endIndex = Math.min(i + batchSize, allTemplateNames.size());
    //         List<String> batchTemplateNames = new List<String>();

    //         for (Integer j = i; j < endIndex; j++) {
    //             batchTemplateNames.add(allTemplateNames[j]);
    //         }

    //         processTemplateBatch(batchTemplateNames, syncTemplateWrapper.allMetaTemplatesMap);
    //     }
    // }


    // private static void processTemplateBatch(List<String> templateNames, Map<String, Object> allMetaTemplatesMap) {
    //     List<Template__c> templatesToInsert = new List<Template__c>();
    //     List<Template_Variable__c> allVarsToInsert = new List<Template_Variable__c>();
    //     Map<String, List<Template_Variable__c>> templateNameToVars = new Map<String, List<Template_Variable__c>>();

    //     for (String templateName : templateNames) {
    //         Map<String, Object> templateData = (Map<String, Object>) allMetaTemplatesMap.get(templateName);

    //         String metaTempId = (String) templateData.get('id');
    //         String metaTemplateStatus = (String) templateData.get('status');

    //         CreateTemplateWrapper.TemplateWrapper tw = new CreateTemplateWrapper.TemplateWrapper();
    //         tw.templateName = templateName;
    //         tw.templateType = determineTemplateType(templateData);
    //         String input = (String) templateData.get('category');
    //         tw.templateCategory = input.substring(0, 1).toUpperCase() + input.substring(1).toLowerCase();
    //         tw.tempLanguage = (String) templateData.get('language');
    //         tw.headAlternateTexts = new List<String>();
    //         tw.varAlternateTexts = new List<String>();

    //         // Flags for miscellaneous data
    //         Map<String, Object> miscFlags = new Map<String, Object>();
    //         Boolean addMedia = false, addHeaderVar = false, isHeaderText = false;
    //         Boolean isVisitSite = false, isCheckboxChecked = false, isFlowSelected = false;
    //         Boolean isFeatureEnabled = false, isImageFile = false, isVideoFile = false, isDocFile = false;
    //         Boolean isImgSelected = false, isVidSelected = false, isDocSelected = false;
    //         Boolean isImageFileUploader = false, isVideoFileUploader = false, isDocFileUploader = false;
    //         Boolean isFlowMarketing = false, isFlowUtility = false;
            

    //         String tempAwsFileName = '';
    //         String contentVersionId = '';

    //         List<Object> components = (List<Object>) templateData.get('components');
    //         for (Object compObj : components) {
    //             Map<String, Object> comp = (Map<String, Object>) compObj;
    //             String type = (String) comp.get('type');

    //             if (type == 'HEADER') {
    //                 String format = (String) comp.get('format');
    //                 tw.tempHeaderFormat = format;

    //                 if (format == 'IMAGE') {
    //                     isImageFile = false; isImgSelected = true; isImageFileUploader = true; addMedia = true;
    //                 } else if (format == 'VIDEO') {
    //                     isVideoFile = false; isVidSelected = true; isVideoFileUploader = true; addMedia = true;
    //                 } else if (format == 'DOCUMENT') {
    //                     isDocFile = false; isDocSelected = true; isDocFileUploader = true; addMedia = true;
    //                 } else if (format == 'TEXT') {
    //                     isHeaderText = true;
    //                 }
                    
    //                 if (comp.containsKey('text') && !String.isEmpty((String) comp.get('text'))) {
    //                     addHeaderVar = true;
    //                     tw.tempHeaderText = (String) comp.get('text');
    //                 }

    //                 if (comp.containsKey('example')) {
    //                     Map<String, Object> example = (Map<String, Object>) comp.get('example');

    //                     List<Object> handleTextList = (example.containsKey('header_text') && example.get('header_text') != null) 
    //                         ? (List<Object>) example.get('header_text') : new List<Object>();

    //                     List<Object> handleList = (example.containsKey('header_handle') && example.get('header_handle') != null) 
    //                         ? (List<Object>) example.get('header_handle') : new List<Object>();

    //                     for (Object h : handleTextList) {
    //                         if (h != null) tw.headAlternateTexts.add((String) h);
    //                     }

    //                     if (!handleList.isEmpty() && handleList[0] != null) {
    //                         // tw.tempImgUrl = (String) handleList[0];
    //                         String metaMediaUrl = (String) handleList[0];
    //                         if (metaMediaUrl != null) {
    //                             PublicUrlContentWapper publicUrlContentWrapper = getMediaPublicUrl(metaMediaUrl,tw.templateName);
    //                             tw.tempImgUrl = publicUrlContentWrapper.publicUrl;
    //                             tw.tempImgName = publicUrlContentWrapper.fileName;
    //                             tempAwsFileName = publicUrlContentWrapper.fileName;
    //                             contentVersionId = publicUrlContentWrapper.contentVersionId;
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

    //             if (type == 'BUTTONS') {
    //                 List<Object> buttons = (List<Object>) comp.get('buttons');
    //                 for (Object buttonObj : buttons) {
    //                     Map<String, Object> button = (Map<String, Object>) buttonObj;
    //                     String buttonType = (String) button.get('type');
    //                     String buttonText = (String) button.get('text');

    //                     if (buttonType == 'URL') {
    //                         isVisitSite = true;
    //                         isCheckboxChecked = true;
    //                     }

    //                     if (buttonType == 'FLOW') {
    //                         isFlowSelected = true;
    //                         String category = (String) templateData.get('category');
    //                         if (category == 'MARKETING') isFlowMarketing = true;
    //                         else if (category == 'UTILITY') isFlowUtility = true;

    //                         List<Map<String, Object>> selectedFlows = new List<Map<String, Object>>();
    //                         Map<String, Object> flowInfo = new Map<String, Object>{
    //                             'type' => 'FLOW',
    //                             'text' => buttonText,
    //                             'flow_id' => button.get('flow_id')
    //                         };
    //                         selectedFlows.add(flowInfo);
    //                         tw.selectedFlow = JSON.serialize(selectedFlows);
    //                     }
    //                 }
    //             }
    //         }

    //         Boolean isSecurityRecommedation = templateData.containsKey('add_security_recommendation') ? (Boolean) templateData.get('add_security_recommendation') : false;
    //         Boolean isCodeExpiration = templateData.containsKey('code_expiration_minutes');
    //         Integer expireTime = templateData.containsKey('message_send_ttl_seconds') ? (Integer) templateData.get('message_send_ttl_seconds') : null;

    //         tw.isSecurityRecommedation = isSecurityRecommedation;
    //         tw.isCodeExpiration = isCodeExpiration;
    //         tw.expireTime = expireTime;


    //         miscFlags.put('contentVersionId', contentVersionId);
    //         miscFlags.put('awsFileName', tempAwsFileName);
    //         miscFlags.put('isImageFile', isImageFile);
    //         miscFlags.put('isImgSelected', isImgSelected);
    //         miscFlags.put('isDocSelected', isDocSelected);
    //         miscFlags.put('isVidSelected', isVidSelected);
    //         miscFlags.put('isHeaderText', isHeaderText);
    //         miscFlags.put('addHeaderVar', addHeaderVar);
    //         miscFlags.put('addMedia', addMedia);
    //         miscFlags.put('isImageFileUploader', isImageFileUploader);
    //         miscFlags.put('isVideoFileUploader', isVideoFileUploader);
    //         miscFlags.put('isDocFileUploader', isDocFileUploader);
    //         miscFlags.put('isVideoFile', isVideoFile);
    //         miscFlags.put('isDocFile', isDocFile);
    //         miscFlags.put('isSecurityRecommedation', isSecurityRecommedation);
    //         miscFlags.put('isCodeExpiration', isCodeExpiration);
    //         miscFlags.put('expireTime', expireTime == null ? 300 : expireTime);
    //         miscFlags.put('isVisitSite', isVisitSite);
    //         miscFlags.put('isCheckboxChecked', isCheckboxChecked);
    //         miscFlags.put('isFlowMarketing', isFlowMarketing);
    //         miscFlags.put('isFlowUtility', isFlowUtility);
    //         miscFlags.put('isFlowSelected', isFlowSelected);
    //         miscFlags.put('isFeatureEnabled', isFeatureEnabled);

    //         tw.templateMiscellaneousData = JSON.serialize(miscFlags);

    //         Template__c whatsAppTemplate = new Template__c();
    //         whatsAppTemplate.Template_Id__c = String.isNotBlank(metaTempId) ? metaTempId : null;
    //         whatsAppTemplate.Template_Name__c = tw.templateName;
    //         whatsAppTemplate.Template_Category__c = tw.templateCategory;
    //         whatsAppTemplate.Language__c = tw.tempLanguage;
    //         whatsAppTemplate.Template_Type__c = tw.templateType;
    //         whatsAppTemplate.Template_Miscellaneous_Data__c = tw.templateMiscellaneousData;
    //         whatsAppTemplate.Status__c = formatStatus(metaTemplateStatus);

    //         if (tw.tempHeaderFormat == 'IMAGE' || tw.tempHeaderFormat == 'VIDEO' || tw.tempHeaderFormat == 'DOCUMENT') {
    //             whatsAppTemplate.Header_Type__c = tw.tempHeaderFormat;
    //             whatsAppTemplate.WBImage_Header_Handle__c = tw.tempHeaderHandle;
    //             whatsAppTemplate.File_Name__c = tw.tempImgName;
    //             whatsAppTemplate.WBHeader_Body__c = tw.tempImgUrl;
    //         } else {
    //             whatsAppTemplate.Header_Type__c = 'TEXT';
    //             whatsAppTemplate.WBHeader_Body__c = tw.tempHeaderText;
    //         }

    //         whatsAppTemplate.WBFooter_Body__c = tw.tempFooterText;
    //         whatsAppTemplate.WBTemplate_Body__c = tw.templateBody;
    //         whatsAppTemplate.WBButton_Body__c = tw.url;

    //         templatesToInsert.add(whatsAppTemplate);

    //         // Collect template variables for this template
    //         String fixedObject = 'Account';
    //         String fixedField = 'AccountNumber';
    //         List<Template_Variable__c> currentTemplateVars = new List<Template_Variable__c>();

    //         Integer headCount = 1;
    //         for (String headAlt : tw.headAlternateTexts) {
    //             currentTemplateVars.add(new Template_Variable__c(
    //                 Name = '{{'+headCount+'}}',
    //                 Type__c = 'Header',
    //                 Object_Name__c = fixedObject,
    //                 Field_Name__c = fixedField,
    //                 Alternate_Text__c = headAlt
    //             ));
    //             headCount++;
    //         }

    //         Integer bodyCount = 1;
    //         for (String bodyAlt : tw.varAlternateTexts) {
    //             currentTemplateVars.add(new Template_Variable__c(
    //                 Name = '{{'+bodyCount+'}}',
    //                 Type__c = 'Body',
    //                 Object_Name__c = fixedObject,
    //                 Field_Name__c = fixedField,
    //                 Alternate_Text__c = bodyAlt
    //             ));
    //             bodyCount++;
    //         }

    //         templateNameToVars.put(templateName, currentTemplateVars);
    //     }

    //     // Insert templates and assign variables correctly
    //     if (!templatesToInsert.isEmpty()) {
    //         insert templatesToInsert;

    //         for (Template__c insertedTemplate : templatesToInsert) {
    //             String templateName = insertedTemplate.Template_Name__c;
    //             if (templateNameToVars.containsKey(templateName)) {
    //                 List<Template_Variable__c> varsForThisTemplate = templateNameToVars.get(templateName);
    //                 for (Template_Variable__c var : varsForThisTemplate) {
    //                     var.Template__c = insertedTemplate.Id;
    //                 }
    //                 allVarsToInsert.addAll(varsForThisTemplate);
    //             }
    //         }
    //     }

    //     if (!allVarsToInsert.isEmpty()) {
    //         insert allVarsToInsert;
    //     }
    // }



    // private static String formatStatus(String status) {
    //     if (String.isBlank(status)) return 'In-Review';
    //     if (status == 'PENDING') return 'In-Review';
    //     if (status == 'REJECTED') return 'Rejected';
    //     if (status == 'APPROVED') return 'Active-Quality Pending';
    //     return status;
    // }

    // private static String determineTemplateType(Map<String, Object> templateData) {
    //     String category = ((String) templateData.get('category')).toUpperCase();
    //     Boolean hasFlowButton = false;

    //     // Check buttons
    //     List<Object> components = (List<Object>) templateData.get('components');
    //     for (Object compObj : components) {
    //         Map<String, Object> comp = (Map<String, Object>) compObj;
    //         if (comp.get('type') == 'BUTTONS') {
    //             List<Object> buttons = (List<Object>) comp.get('buttons');
    //             for (Object btn : buttons) {
    //                 Map<String, Object> button = (Map<String, Object>) btn;
    //                 String buttonType = (String) button.get('type');
    //                 if (buttonType == 'FLOW') {
    //                     hasFlowButton = true;
    //                     break;
    //                 }
    //             }
    //         }
    //         if (hasFlowButton) break;
    //     }

    //     // Apply rules
    //     if (category == 'MARKETING') {
    //         return hasFlowButton ? 'Flow' : 'CustomMarketing';
    //     } else if (category == 'UTILITY') {
    //         return hasFlowButton ? 'flowutility' : 'Custom';
    //     } else if (category == 'AUTHENTICATION') {
    //         return 'One-time passcode';
    //     }  else {
    //         return 'Custom';
    //     }
    // }

    // private static PublicUrlContentWapper getMediaPublicUrl(String mediaUrl,String templateName) {
    //     MVWB__AWS_Config__c configData = !configList.isEmpty() ? configList[0] : null;
    //     String publicUrl = '';
    //     DownloadWhatsAppMediaWrapper fileBlob = downloadWhatsAppMedia(mediaUrl);
    //     PublicUrlContentWapper publicUrlWrapper = new PublicUrlContentWapper();

    //     if(fileBlob.blobData!=null) {
    //         String mediaFileName = generateUniqueFilename(templateName, fileBlob.contentType);
    //         if((configData!=null)&&(configData.MVWB__AWS_Secret_Access_Key__c != null)){
    //             publicUrl = AWSFilesController.uploadFileToS3(mediaFileName,fileBlob.blobData,fileBlob.contentType);
    //             publicUrlWrapper.contentVersionId = null;
    //             publicUrlWrapper.publicUrl = publicUrl;
    //         }
    //         else{
    //             String base64String = EncodingUtil.base64Encode(fileBlob.blobData);
    //             Map<String,String> contentVersionFileContent = FileUploaderController.uploadFile(base64String,mediaFileName);
    //             publicUrlWrapper.contentVersionId = contentVersionFileContent.get('contentVersionId');
    //             publicUrlWrapper.publicUrl = contentVersionFileContent.get('publicUrl');
    //         }
    //         publicUrlWrapper.fileName =  mediaFileName;
    //     }
        
    //     return publicUrlWrapper;
    // }

    // private static DownloadWhatsAppMediaWrapper downloadWhatsAppMedia(String downloadUrl) {
    //     List<MVWB__WBConnect_Configuration__mdt> config = MVWB__WBConnect_Configuration__mdt.getAll().values();
    //     String accessToken = config[0].MVWB__Access_Token__c;

    //     DownloadWhatsAppMediaWrapper downloadMediaWrapper = new DownloadWhatsAppMediaWrapper();

    //     Http http = new Http();
    //     HttpRequest req = new HttpRequest();
    //     req.setEndpoint(downloadUrl);
    //     req.setMethod('GET');
    //     req.setHeader('Authorization', 'Bearer ' + accessToken);
    //     req.setHeader('Accept', '*/*');

    //     HttpResponse res = http.send(req);
    //     if (res.getStatusCode() == 200) {
    //         downloadMediaWrapper.blobData = res.getBodyAsBlob();
    //         downloadMediaWrapper.contentType = res.getHeader('Content-Type');
    //         System.debug(res.getBodyAsBlob());

    //         return downloadMediaWrapper; // ✅ Now this matches the return type
    //     } else {
    //         System.debug('❌ WhatsApp media download failed. Code: ' + res.getStatusCode());
    //         System.debug(res.getBody());
    //         throw new AuraHandledException('Failed to download media.');
    //     }
    // }

    // public static String generateUniqueFilename(String templateName, String contentType) {
    //     // Step 1: Map content type to file extension
    //     Map<String, String> extensionMap = new Map<String, String>{
    //         'image/jpeg' => 'jpg',
    //         'image/png' => 'png',
    //         'application/pdf' => 'pdf',
    //         'video/mp4' => 'mp4',
    //         'application/json' => 'json'
    //     };

    //     String extension = extensionMap.containsKey(contentType) ? extensionMap.get(contentType) : 'bin';

    //     // Step 2: Format current date and time
    //     String dateStr = DateTime.now().format('yyyyMMdd_HHmmss');

    //     // Step 3: Generate a short random string
    //     String randomStr = EncodingUtil.convertToHex(Crypto.generateDigest('SHA1', Blob.valueOf(String.valueOf(Math.random())))).substring(0, 6).toUpperCase();

    //     // Step 4: Combine all
    //     return templateName + '_' + dateStr + '_' + randomStr + '.' + extension;
    // }


    public class DownloadWhatsAppMediaWrapper{
        @AuraEnabled public Blob blobData;
        @AuraEnabled public String contentType;
    }

    public class PublicUrlContentWapper{
        @AuraEnabled public String publicUrl;
        @AuraEnabled public String contentVersionId;
        @AuraEnabled public String fileName;

    }



}