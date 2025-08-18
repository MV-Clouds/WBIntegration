global with sharing class SyncTemplateBatchClass implements Database.Batchable<String>,  Database.Stateful,Database.AllowsCallouts {

    global List<String> templateEntryJSON;
    // global List<Map<String, Object>> allMetaTemplatesMap = new List<Map<String, Object>>();
    global List<Template__c> templatesToInsert = new List<Template__c>();
    global List<Template_Variable__c> allVarsToInsert = new List<Template_Variable__c>();
    global Map<String, List<Template_Variable__c>> templateNameToVars = new Map<String, List<Template_Variable__c>>();

    // public static String userAccountId = WBCP_WhatsAppWebhook.getUserAccount();
    public static List<MVWB__AWS_Config__c> configData = [SELECT Id, MVWB__AWS_Access_Key__c, MVWB__AWS_Secret_Access_Key__c, MVWB__S3_Bucket_Name__c, MVWB__S3_Region_Name__c, CreatedDate, LastModifiedDate FROM MVWB__AWS_Config__c WITH SECURITY_ENFORCED LIMIT 1];
    public static List<MVWB__WBConnect_Configuration__mdt> config = MVWB__WBConnect_Configuration__mdt.getAll().values();


    Set<String> orgDeleteTemplateIds = new Set<String>();

    // Constructor: convert each map to JSON string
    global SyncTemplateBatchClass(List<Map<String, Object>> templateEntry) {
		System.debug('Template Wrapper :: '+templateEntry);
        this.templateEntryJSON = new List<String>();
        for (Map<String, Object> rec : templateEntry) {
            this.templateEntryJSON.add(JSON.serialize(rec));
        }
    }

    // Return JSON strings
    global Iterable<String> start(Database.BatchableContext BC) {
        return templateEntryJSON;
    }

    global void execute(Database.BatchableContext BC, List<String> scope) {
        for (String jsonRec : scope) {
            Map<String, Object> record = (Map<String, Object>) JSON.deserializeUntyped(jsonRec);
            System.debug('Processing record: ' + record);

            // Example: access fields
            String templateName = (String) record.get('templateName');
            String action = (String) record.get('action');
            String selectedOrphanTemplateAction = (String) record.get('selectedOrphanTemplateAction');
            String templateId = (String) record.get('templateId');

            if(action == 'orgToMeta') {
                // Handle org to meta action
                System.debug('Processing org to meta for template: ' + templateName);
                System.debug('Selected Orphan Flow Action: ' + selectedOrphanTemplateAction);
                processOrgToMeta(templateId, templateName, selectedOrphanTemplateAction);
                // Add your logic here, e.g., create or update templates in the org
                
            } else if(action == 'metaToOrg') {
                // Handle meta to org action
                System.debug('Processing meta to org for template: ' + templateName);
                processMetaToOrg(templateName);
                // Add your logic here, e.g., sync templates from meta to org
            }
            // processTemplateBatch(record); // Your processing method
        }
    }


    global void finish(Database.BatchableContext BC) {
        System.debug('Batch Finished');
        // Insert templates and assign variables correctly
        System.debug('Templates to insert: ' + templatesToInsert);
        System.debug('Variables to insert: ' + allVarsToInsert);
        System.debug('Templates to insert size: ' + templatesToInsert.size());
        System.debug('Variables to insert size: ' + allVarsToInsert.size());
        
        if (!templatesToInsert.isEmpty()) {
            insert templatesToInsert;

            for (Template__c insertedTemplate : templatesToInsert) {
                String templateName1 = insertedTemplate.Template_Name__c;
                if (templateNameToVars.containsKey(templateName1)) {
                    List<Template_Variable__c> varsForThisTemplate = templateNameToVars.get(templateName1);
                    for (Template_Variable__c var : varsForThisTemplate) {
                        var.Template__c = insertedTemplate.Id;
                    }
                    this.allVarsToInsert.addAll(varsForThisTemplate);
                }
            }
        }

        if (!allVarsToInsert.isEmpty()) {
            insert allVarsToInsert;
        }
        System.debug('Org Deleted Template Id ::: '+orgDeleteTemplateIds);
        if(!orgDeleteTemplateIds.isEmpty()) {
            // Delete templates in org that are marked for deletion
            // List<Template__c> templatesToDelete = new List<Template__c>();
            List<Template__c> templatesToDelete = [SELECT Id FROM Template__c WHERE Template_Id__c IN :orgDeleteTemplateIds];
            if (!templatesToDelete.isEmpty()) {
                delete templatesToDelete;
            }
        }
    }

    global void processOrgToMeta(String Id, String templateName, String selectedOrphanTemplateAction) {
        // Get the template id
        try {
            System.debug('Processing org to meta for template ID: ' + Id);
            System.debug('Template Name: ' + templateName);
            System.debug('Selected Orphan Flow Action: ' + selectedOrphanTemplateAction);
            String templateId ;
            List<Template__c> template1 = [Select Id,Template_Id__c,Template_Name__c from Template__c];
            for(Template__c x : template1){
                if( x.Template_Name__c == templateName) {
                    Id = x.Id;
                    templateId = x.Template_Id__c;
                    System.debug('Found matching template ID: ' + Id);
                    break;
                }
            }
            if(selectedOrphanTemplateAction == 'DeleteFromOrg') {
                System.debug('If Delete');
                    // If the action is delete, add to orgDeleteTemplateIds
                    this.orgDeleteTemplateIds.add(templateId);
                    return;
            }
            System.debug('Create template with ID: ' + Id);
            Template__c template = [SELECT Id, Template_Id__c,WBButton_Body__c,WBFooter_Body__c,File_Name__c,WBImage_Header_Handle__c,Header_Type__c,WBHeader_Body__c,Language__c,Status__c,WBTemplate_Body__c,Template_Category__c,Template_Name__c,Template_Type__c,Template_Variable__c,Template_Miscellaneous_Data__c FROM Template__c WHERE Id = :Id LIMIT 1];
            System.debug('Template found: ' + template);
            List<Template_Variable__c> templateVar = [Select Id,Name,Alternate_Text__c,Type__c,Field_Name__c,Object_Name__c From Template_Variable__c WHERE Template__c = : template.Id];
            Map<String,List<String>> templateVarMap = new Map<String,List<String>>();

            for (Template_Variable__c variable : templateVar) {
                if (String.isNotBlank(variable.Type__c) && String.isNotBlank(variable.Alternate_Text__c)) {
                    if (!templateVarMap.containsKey(variable.Type__c)) {
                        templateVarMap.put(variable.Type__c, new List<String>());
                    }
                    templateVarMap.get(variable.Type__c).add(variable.Alternate_Text__c);
                }
            }

            System.debug('TEmplate ::: ' + template);
            System.debug('Template Variables Map: ' + templateVarMap);
            if (template == null) {
                System.debug('Template not found for Id: ' + Id);
                return;
            }
    
            Map<String, Object> payload = buildPayload(template,templateVarMap);
            System.debug('Payload built for template: ' + JSON.serialize(payload));
            String endpoint = config[0].MVWB__API_Endpoint__c + '/' + config[0].MVWB__API_Version__c + '/'+config[0].MVWB__Business_Account_Id__c+'/message_templates';
            
            HttpRequest req = new HttpRequest();
            req.setEndpoint(endpoint);
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setHeader('Authorization', 'Bearer ' + config[0].MVWB__Access_Token__c);
            req.setBody(JSON.serialize(payload));
    
            Http http = new Http();
            HttpResponse res = http.send(req);

            if (res.getStatusCode() == 200) {
                System.debug('Success');
            } else {
                System.debug('Http Body ::: '+ res.getBody());
                System.debug('HTTP callout failed with status: ' + res.getStatusCode());
                ExceptionHandler.logException(new Map<String, Object>{'className' => 'SyncTemplateBatchClass','methodName' => 'processOrgToMeta','exceptionObj' => null,'isApiException' => true,'statusCode' => res.getStatusCode(),'chatId' => null,'moreDetails' => 'HTTP callout failed with status: ' + res.getStatusCode(),'apiResponse' => res.getBody()});
            }

        } catch (Exception e) {
            ExceptionHandler.logException(new Map<String, Object>{'className' => 'SyncTemplateBatchClass', 'methodName' => 'processOrgToMeta', 'exceptionObj' => e, 'isApiException' => false, 'statusCode' => null, 'chatId' => null, 'moreDetails' => e.getMessage(), 'apiResponse' => null});
            System.debug('Error building payload for template: ' + e.getMessage());
        }

    }

    public static Map<String, Object> buildPayload(Template__c templateRec, Map<String, List<String>> templateVarMap) {
        try {

            System.debug('Building payload for template: ' + templateRec);
            Map<String, Object> payload = new Map<String, Object>();
            Map<String, Object> metaDataMap = (Map<String, Object>) JSON.deserializeUntyped(templateRec.Template_Miscellaneous_Data__c);

            payload.put('name', templateRec.Template_Name__c);
            payload.put('language', templateRec.Language__c);
            payload.put('category', templateRec.Template_Category__c);

            List<Map<String, Object>> components = buildMarketingOrUtilityComponents(templateRec, metaDataMap, templateVarMap);
            if (!components.isEmpty()) {
                payload.put('components', components);
            }

            if ((templateRec.Template_Category__c == 'Authentication' || templateRec.Template_Category__c == 'Utility')
                && metaDataMap.containsKey('expireTime')) {
                payload.put('message_send_ttl_seconds', (Integer) metaDataMap.get('expireTime'));
            }

            return payload;
        } catch (Exception e) {
            System.debug('buildPayload ::: '+e);
            ExceptionHandler.logException(new Map<String, Object>{
                'className' => 'CreateTemplateWrapper',
                'methodName' => 'buildPayload',
                'exceptionObj' => e,
                'isApiException' => false,
                'moreDetails' => e.getMessage()
            });
        }
        return new Map<String, Object>();
    }

    private static List<Map<String, Object>> buildMarketingOrUtilityComponents(Template__c templateRec, Map<String, Object> metaDataMap, Map<String, List<String>> templateVarMap) {
        List<Map<String, Object>> components = new List<Map<String, Object>>();
        try {
            Map<String, Object> headerComponent = buildHeaderComponent(templateRec, metaDataMap, templateVarMap);
            if (!headerComponent.isEmpty()) {
                components.add(headerComponent);
            }

            if (templateRec.WBTemplate_Body__c != null) {
                components.add(buildBodyComponent(templateRec, metaDataMap, templateVarMap));
            }

            if (templateRec.WBFooter_Body__c != null) {
                components.add(new Map<String, Object>{
                    'type' => 'FOOTER',
                    'text' => templateRec.WBFooter_Body__c
                });
            } else if (templateRec.Template_Category__c == 'Authentication'
                        && (Boolean) metaDataMap.get('isCodeExpiration')) {
                Integer expirationMinutes = (Integer) Math.floor(((Integer) metaDataMap.get('expireTime')) / 60);
                components.add(new Map<String, Object>{
                    'type' => 'FOOTER',
                    'text' => 'Code expires in ' + expirationMinutes + ' minutes'
                });
            }

            List<Map<String, Object>> buttonComponents = buildButtonComponent(templateRec);
            if (!buttonComponents.isEmpty()) {
                components.add(new Map<String, Object>{
                    'type' => 'BUTTONS',
                    'buttons' => buttonComponents
                });
            }

        } catch (Exception e) {
            ExceptionHandler.logException(new Map<String, Object>{
                'className' => 'CreateTemplateWrapper',
                'methodName' => 'buildMarketingOrUtilityComponents',
                'exceptionObj' => e,
                'isApiException' => false,
                'moreDetails' => e.getMessage()
            });
        }

        return components;
    }

    private static Map<String, Object> buildHeaderComponent(Template__c templateRec, Map<String, Object> metaDataMap, Map<String, List<String>> templateVarMap) {
        Map<String, Object> headerComponent = new Map<String, Object>();

        try {
            if (templateRec.Header_Type__c == null || templateRec.Header_Type__c == 'None') {
                return headerComponent;
            }

            headerComponent.put('type', 'HEADER');
            headerComponent.put('format', templateRec.Header_Type__c.toUpperCase());

            if (templateRec.Header_Type__c.equalsIgnoreCase('Text') && String.isNotBlank(templateRec.WBHeader_Body__c)) {
                headerComponent.put('text', templateRec.WBHeader_Body__c);

                if (templateVarMap.containsKey('Header') && !templateVarMap.get('Header').isEmpty()) {
                    headerComponent.put('example', new Map<String, Object>{
                        'header_text' => new List<String>{ templateVarMap.get('Header')[0] }
                    });
                }
            } else if (templateRec.Header_Type__c.equalsIgnoreCase('Image') || 
                    templateRec.Header_Type__c.equalsIgnoreCase('Video') ||
                    templateRec.Header_Type__c.equalsIgnoreCase('Document')) {

                String headerHandle = uploadFileToMetaAndGetHeaderHandle(templateRec.WBHeader_Body__c, templateRec.Template_Miscellaneous_Data__c);
                if (String.isNotBlank(headerHandle)) {
                    headerComponent.put('example', new Map<String, Object>{
                        'header_handle' => headerHandle
                    });
                }
            }
        } catch (Exception e) {
            ExceptionHandler.logException(new Map<String, Object>{
                'className' => 'CreateTemplateWrapper',
                'methodName' => 'buildHeaderComponent',
                'exceptionObj' => e,
                'isApiException' => false,
                'moreDetails' => e.getMessage()
            });
        }

        return headerComponent;
    }

    private static Map<String, Object> buildBodyComponent(Template__c templateRec, Map<String, Object> metaDataMap, Map<String, List<String>> templateVarMap) {
        try {
            Map<String, Object> bodyComponent = new Map<String, Object>{
                'type' => 'BODY',
                'text' => templateRec.WBTemplate_Body__c != null ? templateRec.WBTemplate_Body__c.replace('\\n', '\n') : ''
            };

            if (templateVarMap.containsKey('Body') && !templateVarMap.get('Body').isEmpty()) {
                bodyComponent.put('example', new Map<String, Object>{
                    'body_text' => new List<List<String>>{ templateVarMap.get('Body') }
                });
            }
            return bodyComponent;
        } catch (Exception e) {
            ExceptionHandler.logException(new Map<String, Object>{
                'className' => 'CreateTemplateWrapper',
                'methodName' => 'buildBodyComponent',
                'exceptionObj' => e,
                'isApiException' => false,
                'moreDetails' => e.getMessage()
            });
        }
        return new Map<String, Object>();
    }

    // private static List<Map<String, Object>> buildButtonComponent(Template__c templateRec) {
    //     List<Map<String, Object>> buttonComponents = new List<Map<String, Object>>();
    //     try {
    //         if (String.isBlank(templateRec.WBButton_Body__c)) {
    //             return buttonComponents;
    //         }

    //         // Parse JSON into a generic list
    //         List<Object> rawButtonList = (List<Object>) JSON.deserializeUntyped(templateRec.WBButton_Body__c);

    //         for (Object obj : rawButtonList) {
    //             Map<String, Object> buttonMap = (Map<String, Object>) obj;
    //             Map<String, Object> btn = new Map<String, Object>();

    //             // Maintain order for clarity
    //             if (buttonMap.containsKey('type'))            btn.put('type', buttonMap.get('type'));
    //             if (buttonMap.containsKey('text'))            btn.put('text', buttonMap.get('text'));
    //             if (buttonMap.containsKey('url'))             btn.put('url', buttonMap.get('url'));
    //             if (buttonMap.containsKey('phone_number'))    btn.put('phone_number', buttonMap.get('phone_number'));
    //             if (buttonMap.containsKey('example'))         btn.put('example', buttonMap.get('example'));
    //             if (buttonMap.containsKey('otp_type'))        btn.put('otp_type', buttonMap.get('otp_type'));
    //             if (buttonMap.containsKey('flow_id'))         btn.put('flow_id', buttonMap.get('flow_id'));
    //             if (buttonMap.containsKey('navigate_screen')) btn.put('navigate_screen', buttonMap.get('navigate_screen'));
    //             if (buttonMap.containsKey('flow_action'))     btn.put('flow_action', buttonMap.get('flow_action'));

    //             buttonComponents.add(btn);
    //         }

    //     } catch (Exception e) {
    //         ExceptionHandler.logException(new Map<String, Object>{
    //             'className' => 'CreateTemplateWrapper',
    //             'methodName' => 'buildButtonComponent',
    //             'exceptionObj' => e,
    //             'isApiException' => false,
    //             'moreDetails' => e.getMessage()
    //         });
    //     }
    //     return buttonComponents;
    // }

    
    private static List<Map<String, Object>> buildButtonComponent(Template__c templateRec) {
        List<Map<String, Object>> buttonComponents = new List<Map<String, Object>>();
        try {
        if (String.isBlank(templateRec.WBButton_Body__c)) {
                return buttonComponents;
            }

            // Parse JSON into a generic list
        List<Object> rawButtonList = (List<Object>) JSON.deserializeUntyped(templateRec.WBButton_Body__c);

            // Collect flow_ids up front
            Set<String> flowIds = new Set<String>();
            for (Object obj : rawButtonList) {
                Map<String, Object> buttonMap = (Map<String, Object>) obj;
                if (buttonMap.containsKey('flow_id') && buttonMap.get('flow_id') != null) {
                    flowIds.add(String.valueOf(buttonMap.get('flow_id')));
                }
            }

            // Query all flows at once
            Map<String, Flow__c> flowMap = new Map<String, Flow__c>();
            if (!flowIds.isEmpty()) {
                for (Flow__c flowRec : [
                    SELECT Flow_Id__c, Flow_Json__c 
                    FROM Flow__c 
                    WHERE Flow_Id__c IN :flowIds
                ]) {
                    flowMap.put(flowRec.Flow_Id__c, flowRec);
                }
            }

            // Now build buttons
            for (Object obj : rawButtonList) {
                Map<String, Object> buttonMap = (Map<String, Object>) obj;
                Map<String, Object> btn = new Map<String, Object>();

                // Maintain order for clarity
                if (buttonMap.containsKey('type'))            btn.put('type', buttonMap.get('type'));
                if (buttonMap.containsKey('text'))            btn.put('text', buttonMap.get('text'));
                if (buttonMap.containsKey('url'))             btn.put('url', buttonMap.get('url'));
                if (buttonMap.containsKey('phone_number'))    btn.put('phone_number', buttonMap.get('phone_number'));
                if (buttonMap.containsKey('example'))         btn.put('example', buttonMap.get('example'));
                if (buttonMap.containsKey('otp_type'))        btn.put('otp_type', buttonMap.get('otp_type'));
                if (buttonMap.containsKey('flow_id'))         btn.put('flow_id', buttonMap.get('flow_id'));
                if (buttonMap.containsKey('navigate_screen')) btn.put('navigate_screen', buttonMap.get('navigate_screen'));
                if (buttonMap.containsKey('flow_action'))     btn.put('flow_action', 'navigate');

                // Fill default navigate_screen if missing/blank
                if (
                    (!buttonMap.containsKey('navigate_screen')) || 
                    buttonMap.get('navigate_screen') == null || 
                    String.valueOf(buttonMap.get('navigate_screen')).trim() == ''
                ) {
                    String flowId = (buttonMap.containsKey('flow_id') ? String.valueOf(buttonMap.get('flow_id')) : null);
                    if (flowId != null && flowMap.containsKey(flowId)) {
                        Flow__c flowRec = flowMap.get(flowId);

                        if (String.isNotBlank(flowRec.Flow_Json__c)) {
                            Map<String, Object> flowJson = (Map<String, Object>) JSON.deserializeUntyped(flowRec.Flow_Json__c);

                            if (flowJson.containsKey('screens')) {
                                List<Object> screens = (List<Object>) flowJson.get('screens');
                                if (!screens.isEmpty()) {
                                    Map<String, Object> firstScreen = (Map<String, Object>) screens[0];
                                    if (firstScreen.containsKey('id')) {
                                        btn.put('navigate_screen', (String) firstScreen.get('id'));
                                    }
                                }
                            }
                        }
                    }
                }

                buttonComponents.add(btn);
            }

        } catch (Exception e) {
            ExceptionHandler.logException(new Map<String, Object>{
                'className' => 'CreateTemplateWrapper',
                'methodName' => 'buildButtonComponent',
                'exceptionObj' => e,
                'isApiException' => false,
                'moreDetails' => e.getMessage()
            });
        }
        return buttonComponents;
    }



    public static String uploadFileToMetaAndGetHeaderHandle(String tempImgUrl,String templateMiscellaneousData){
        String headerHandleResult = '';
        String fileUrlOrContentVersionId = '';
        String contentVersionId = '';

        fileUrlOrContentVersionId = tempImgUrl;

        try{
            Blob fileBlob;
            String mimeType;
            String fileName;
            Integer fileLength;

            if (fileUrlOrContentVersionId.contains('amazonaws.com')){
                // ---- S3 FILE ----
                Http http = new Http();
                HttpRequest s3Req = new HttpRequest();
                s3Req.setEndpoint(fileUrlOrContentVersionId);
                s3Req.setMethod('GET');

                HttpResponse s3Res = http.send(s3Req);
                if (s3Res.getStatusCode() != 200){
                    ExceptionHandler.logException(new Map<String, Object>{ 'className' => 'WBTemplateController', 'methodName' => 'uploadFileToMetaAndGetHeaderHandle', 'exceptionObj' => null, 'isApiException' => true, 'statusCode' => s3Res.getStatusCode(), 'chatId' => null, 'moreDetails' => 'HTTP callout failed with status: ' + s3Res.getStatusCode(), 'apiResponse' => s3Res.getBody() });

                    System.debug('❌ Failed to fetch file from S3. Status: ' + s3Res.getStatusCode());
                    return '';
                }

                fileBlob = s3Res.getBodyAsBlob();
                mimeType = s3Res.getHeader('Content-Type');
                fileName = fileUrlOrContentVersionId.substring(fileUrlOrContentVersionId.lastIndexOf('/') + 1);
                fileLength = fileBlob.size();
            } 
            // ---- START META UPLOAD SESSION ----
            String uploadSessionId = WBTemplateController.startUploadSession(fileName, fileLength, mimeType);
            if (String.isBlank(uploadSessionId)){
                System.debug('❌ Failed to start Meta upload session.');
                return '';
            }

            // ---- PREPARE FILE WRAPPER ----
            FileChunkWrapper wrapper = new FileChunkWrapper();
            wrapper.uploadSessionId = uploadSessionId;
            wrapper.fileName = fileName;
            wrapper.fileContent = EncodingUtil.base64Encode(fileBlob);
            wrapper.chunkStart = 0;
            wrapper.chunkSize = fileLength;

            String serializedFileWrapper = JSON.serialize(wrapper);

            // ---- UPLOAD TO META ----
            String resultJson = WBTemplateController.uploadFileChunk(serializedFileWrapper, false);
            Map<String, Object> resultMap = (Map<String, Object>)JSON.deserializeUntyped(resultJson);
            if (resultMap.containsKey('headerHandle')){
                headerHandleResult = (String) resultMap.get('headerHandle');
                System.debug('✅ Upload Successful. Header Handle: ' + headerHandleResult);

                // Update the header_handle using regex
                // payloadWrapper = payloadWrapper.replaceFirst('"header_handle":"[^"]+"', '"header_handle":"' + headerHandleResult + '"');
                // templateWrapper.tempHeaderHandle = headerHandleResult;
                // serializedWrapper = JSON.serialize(templateWrapper);
                // System.debug('Updated serializedWrapper with new header handle: ' + serializedWrapper);
                // editWhatsappTemplate(serializedWrapper, payloadWrapper, tempalteId, templateName);

            } else{
                System.debug('⚠ Upload completed but no headerHandle returned.');
            }
            return headerHandleResult;

        } catch (Exception e){
            ExceptionHandler.logException(new Map<String, Object>{ 'className' => 'WBTemplateController', 'methodName' => 'uploadFileToMetaAndGetHeaderHandle', 'exceptionObj' => e, 'isApiException' => false, 'statusCode' => null, 'chatId' => null, 'moreDetails' => e.getMessage(), 'apiResponse' => null });
            return '';
        }
    }

    private static String getMimeTypeFromExtension(String ext){
        ext = ext != null ? ext.toLowerCase() : '';
        if (ext == 'png')
            return 'image/png';
        if (ext == 'jpg' || ext == 'jpeg')
            return 'image/jpeg';
        if (ext == 'pdf')
            return 'application/pdf';
        if (ext == 'mp4')
            return 'video/mp4';
        if (ext == 'doc')
            return 'application/msword';
        if (ext == 'docx')
            return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
        if (ext == 'xls')
            return 'application/vnd.ms-excel';
        if (ext == 'xlsx')
            return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
        return 'application/octet-stream'; // default fallback
    }

     public class FileChunkWrapper {
        @AuraEnabled public String uploadSessionId;
        @AuraEnabled public String fileContent;
        @AuraEnabled public Integer chunkStart;
        @AuraEnabled public Integer chunkSize;
        @AuraEnabled public String fileName;
    }

    global static Map<String, Object> getMetaToOrgPayload(String templateName){

        Map<String, Object> templateData = new Map<String, Object>();
        String accessToken = config[0].MVWB__Access_Token__c;
        String endpoint = config[0].MVWB__API_Endpoint__c + '/' + config[0].MVWB__API_Version__c + '/' + config[0].MVWB__Business_Account_Id__c + '/message_templates?name='+templateName;
        Http http = new Http();
        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpoint);
        req.setMethod('GET');
        req.setHeader('Authorization', 'Bearer ' + accessToken);

        HttpResponse res = http.send(req);
        if (res.getStatusCode() != 200) {
            throw new AuraHandledException('Failed to fetch templates. Status Code: ' + res.getStatusCode());
        }
        Map<String, Object> responseMap = (Map<String, Object>)JSON.deserializeUntyped(res.getBody());
        if (responseMap.containsKey('data')) {
            List<Object> dataList = (List<Object>)responseMap.get('data');
            templateData = (Map<String, Object>) dataList[0];
        }

        return templateData;
    }

    global void processMetaToOrg(String templateName) {
        // List<Template__c> templatesToInsert = new List<Template__c>();
        // List<Template_Variable__c> allVarsToInsert = new List<Template_Variable__c>();
        // Map<String, List<Template_Variable__c>> templateNameToVars = new Map<String, List<Template_Variable__c>>();

        // for (String templateName : templateNames) {
            
        // }

        Map<String, Object> templateData = (Map<String, Object>) getMetaToOrgPayload(templateName);
        
            String metaTempId = (String) templateData.get('id');
            String metaTemplateStatus = (String) templateData.get('status');
            String buttonDetails;

            CreateTemplateWrapper.TemplateWrapper tw = new CreateTemplateWrapper.TemplateWrapper();
            tw.templateName = templateName;
            tw.templateType = determineTemplateType(templateData);
            String input = (String) templateData.get('category');
            tw.templateCategory = input.substring(0, 1).toUpperCase() + input.substring(1).toLowerCase();
            tw.tempLanguage = (String) templateData.get('language');
            tw.headAlternateTexts = new List<String>();
            tw.varAlternateTexts = new List<String>();

            // Flags for miscellaneous data
            Map<String, Object> miscFlags = new Map<String, Object>();
            Boolean addMedia = false, addHeaderVar = false, isHeaderText = false;
            Boolean isVisitSite = false, isCheckboxChecked = false, isFlowSelected = false;
            Boolean isFeatureEnabled = false, isImageFile = false, isVideoFile = false, isDocFile = false;
            Boolean isImgSelected = false, isVidSelected = false, isDocSelected = false;
            Boolean isImageFileUploader = false, isVideoFileUploader = false, isDocFileUploader = false;
            Boolean isFlowMarketing = false, isFlowUtility = false;
            

            String tempAwsFileName = '';
            String contentVersionId = '';

            List<Object> components = (List<Object>) templateData.get('components');
            for (Object compObj : components) {
                Map<String, Object> comp = (Map<String, Object>) compObj;
                String type = (String) comp.get('type');

                if (type == 'HEADER') {
                    String format = (String) comp.get('format');
                    tw.tempHeaderFormat = format;

                    if (format == 'IMAGE') {
                        isImageFile = false; isImgSelected = true; isImageFileUploader = true; addMedia = true;
                    } else if (format == 'VIDEO') {
                        isVideoFile = false; isVidSelected = true; isVideoFileUploader = true; addMedia = true;
                    } else if (format == 'DOCUMENT') {
                        isDocFile = false; isDocSelected = true; isDocFileUploader = true; addMedia = true;
                    } else if (format == 'TEXT') {
                        isHeaderText = true;
                    }
                    
                    if (comp.containsKey('text') && !String.isEmpty((String) comp.get('text'))) {
                        addHeaderVar = true;
                        tw.tempHeaderText = (String) comp.get('text');
                    }

                    if (comp.containsKey('example')) {
                        Map<String, Object> example = (Map<String, Object>) comp.get('example');

                        List<Object> handleTextList = (example.containsKey('header_text') && example.get('header_text') != null) 
                            ? (List<Object>) example.get('header_text') : new List<Object>();

                        List<Object> handleList = (example.containsKey('header_handle') && example.get('header_handle') != null) 
                            ? (List<Object>) example.get('header_handle') : new List<Object>();

                        for (Object h : handleTextList) {
                            if (h != null) tw.headAlternateTexts.add((String) h);
                        }

                        if (!handleList.isEmpty() && handleList[0] != null) {
                            // tw.tempImgUrl = (String) handleList[0];
                            String metaMediaUrl = (String) handleList[0];
                            if (metaMediaUrl != null) {
                                PublicUrlContentWapper publicUrlContentWrapper = getMediaPublicUrl(metaMediaUrl,tw.templateName);
                                tw.tempImgUrl = publicUrlContentWrapper.publicUrl;
                                tw.tempImgName = publicUrlContentWrapper.fileName;
                                tempAwsFileName = publicUrlContentWrapper.fileName;
                                contentVersionId = publicUrlContentWrapper.contentVersionId;
                            }
                        }
                    }
                }

                if (type == 'BODY') {
                    tw.templateBody = (String) templateData.get('category') == 'Authentication' ? ' is your verification code' : (String) comp.get('text');
                    if (comp.containsKey('example') && templateData.get('category') != 'Authentication') {
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

                // if (type == 'BUTTONS') {
                //     List<Object> buttons = (List<Object>) comp.get('buttons');
                //     for (Object buttonObj : buttons) {
                //         Map<String, Object> button = (Map<String, Object>) buttonObj;
                //         String buttonType = (String) button.get('type');
                //         String buttonText = (String) button.get('text');

                //         if (buttonType == 'URL') {
                //             isVisitSite = true;
                //             isCheckboxChecked = true;
                //         }

                //         if (buttonType == 'FLOW') {
                //             isFlowSelected = true;
                //             String category = (String) templateData.get('category');
                //             if (category == 'MARKETING') isFlowMarketing = true;
                //             else if (category == 'UTILITY') isFlowUtility = true;

                //             List<Map<String, Object>> selectedFlows = new List<Map<String, Object>>();
                //             Map<String, Object> flowInfo = new Map<String, Object>{
                //                 'type' => 'FLOW',
                //                 'text' => buttonText,
                //                 'flow_id' => button.get('flow_id')
                //             };
                //             selectedFlows.add(flowInfo);
                //             tw.selectedFlow = JSON.serialize(selectedFlows);
                //         }
                //     }
                // }

                if (type == 'BUTTONS') {
                    System.debug('divij check buttons ' + comp);
                    System.debug('divij check buttons ' + comp.get('buttons'));
                    List<Object> buttons = (List<Object>) comp.get('buttons');
                    for (Object buttonObj : buttons) {
                        if (buttonObj instanceof Map<String, Object>) {
                            Map<String, Object> button = (Map<String, Object>) buttonObj;
                            String buttonType = (String) button.get('type');
                            String buttonText = (String) button.get('text');

                            // ✅ Check for marketing opt-out
                            if (buttonText == tw.marketingOptText) {
                                button.put('isMarketingOpt', true);
                            }

                            // ✅ Check for URL button
                            if (buttonType == 'URL') {
                                isVisitSite = true;
                                isCheckboxChecked = true;
                            }

                            // ✅ Check for FLOW button
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

                    // ✅ Set WBButton_Body__c from handleButtonComponent()
                    // buttonDetails = handleButtonComponent(comp);
                    if (buttons != null && templateData.get('category') != 'Authentication') {
                        buttonDetails = (String) JSON.serialize(buttons);
                    }
                    else{
                        buttonDetails = '[{"type":"OTP","text":"Verify Code","otp_type":"COPY_CODE"}]';
                    }
                    // whatsAppTemplate.WBButton_Body__c = buttonDetails;
                }                
            }

            Boolean isSecurityRecommedation = templateData.containsKey('add_security_recommendation') ? (Boolean) templateData.get('add_security_recommendation') : true;
            Boolean isCodeExpiration = templateData.containsKey('code_expiration_minutes');
            Integer expireTime = templateData.containsKey('message_send_ttl_seconds') ? (Integer) templateData.get('message_send_ttl_seconds') : null;
            
            tw.isSecurityRecommedation = isSecurityRecommedation;
            tw.isCodeExpiration = isCodeExpiration;
            tw.expireTime = expireTime;

            
            miscFlags.put('contentVersionId', contentVersionId);
            miscFlags.put('awsFileName', tempAwsFileName);
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
            miscFlags.put('expireTime', expireTime == null ? 300 : expireTime);
            miscFlags.put('isVisitSite', isVisitSite);
            miscFlags.put('isCheckboxChecked', isCheckboxChecked);
            miscFlags.put('isFlowMarketing', isFlowMarketing);
            miscFlags.put('isFlowUtility', isFlowUtility);
            miscFlags.put('isFlowSelected', isFlowSelected);
            miscFlags.put('isFeatureEnabled', isFeatureEnabled);
            miscFlags.put('authRadioButton', 'COPY_CODE');
            miscFlags.put('autofillCheck', false);
            miscFlags.put('marketingOptText', tw.marketingOptText);
            
            tw.templateMiscellaneousData = JSON.serialize(miscFlags);
            
            Template__c whatsAppTemplate = new Template__c();
            whatsAppTemplate.Template_Id__c = String.isNotBlank(metaTempId) ? metaTempId : null;
            whatsAppTemplate.Template_Name__c = tw.templateName;
            whatsAppTemplate.Template_Category__c = tw.templateCategory;
            whatsAppTemplate.Language__c = tw.tempLanguage;
            whatsAppTemplate.Template_Type__c = tw.templateType;
            whatsAppTemplate.Template_Miscellaneous_Data__c = tw.templateMiscellaneousData;
            // whatsAppTemplate.Account__c = userAccountId;
            System.debug('Button body ::: '+buttonDetails);
            whatsAppTemplate.WBButton_Body__c = (String) buttonDetails;
            System.debug('Button body ::: '+buttonDetails);
            whatsAppTemplate.Status__c = formatStatus(metaTemplateStatus);
            
            if (tw.tempHeaderFormat == 'IMAGE' || tw.tempHeaderFormat == 'VIDEO' || tw.tempHeaderFormat == 'DOCUMENT') {
                whatsAppTemplate.Header_Type__c = tw.tempHeaderFormat;
                // whatsAppTemplate.WBImage_Header_Handle__c = tw.tempHeaderHandle;
                whatsAppTemplate.File_Name__c = tw.tempImgName;
                whatsAppTemplate.WBHeader_Body__c = tw.tempImgUrl;
            } else {
                whatsAppTemplate.Header_Type__c = 'TEXT';
                whatsAppTemplate.WBHeader_Body__c = tw.tempHeaderText;
            }

            whatsAppTemplate.WBFooter_Body__c = tw.tempFooterText;
            whatsAppTemplate.WBTemplate_Body__c = tw.templateBody;
            // whatsAppTemplate.WBButton_Body__c = tw.url;

            this.templatesToInsert.add(whatsAppTemplate);
            System.debug('WhatsApp Template to insert: ' + whatsAppTemplate);
            System.debug('Template insert ::: '+ templatesToInsert);
            System.debug('Template insert size ::: '+ templatesToInsert.size());
            System.debug('Template variables to insert ::: '+ allVarsToInsert);


            // Collect template variables for this template
            String fixedObject = 'Account';
            String fixedField = 'AccountNumber';
            List<Template_Variable__c> currentTemplateVars = new List<Template_Variable__c>();

            // Regex to match {{ ObjectName . FieldName }} with optional spaces and namespace support
            Pattern altPattern = Pattern.compile('\\{\\{\\s*([a-zA-Z0-9_]+(?:__c|__r)?)\\s*\\.\\s*([a-zA-Z0-9_]+(?:__c|__r)?)\\s*\\}\\}');

            // Headers
            Integer headCount = 1;
            for (String headAlt : tw.headAlternateTexts) {
                String objName = fixedObject;
                String fieldName = fixedField;

                if (String.isNotBlank(headAlt)) {
                    Matcher m = altPattern.matcher(headAlt);
                    if (m.matches()) {
                        objName = m.group(1);   // Object name (with optional __c/__r)
                        fieldName = m.group(2); // Field name (with optional __c/__r)
                    }
                }

                currentTemplateVars.add(new Template_Variable__c(
                    Name = '{{' + headCount + '}}',
                    Type__c = 'Header',
                    Object_Name__c = objName,
                    Field_Name__c = fieldName,
                    Alternate_Text__c = headAlt
                ));
                headCount++;
            }

            // Body variables
            Integer bodyCount = 1;
            for (String bodyAlt : tw.varAlternateTexts) {
                String objName = fixedObject;
                String fieldName = fixedField;

                if (String.isNotBlank(bodyAlt)) {
                    Matcher m = altPattern.matcher(bodyAlt);
                    if (m.matches()) {
                        objName = m.group(1);
                        fieldName = m.group(2);
                    }
                }

                currentTemplateVars.add(new Template_Variable__c(
                    Name = '{{' + bodyCount + '}}',
                    Type__c = 'Body',
                    Object_Name__c = objName,
                    Field_Name__c = fieldName,
                    Alternate_Text__c = bodyAlt
                ));
                bodyCount++;
            }



            this.templateNameToVars.put(templateName, currentTemplateVars);
    }

    global static String formatStatus(String status) {
        if (String.isBlank(status)) return 'In-Review';
        if (status == 'PENDING') return 'In-Review';
        if (status == 'REJECTED') return 'Rejected';
        if (status == 'APPROVED') return 'Active-Quality Pending';
        return status;
    }

    global static String determineTemplateType(Map<String, Object> templateData) {
        String category = ((String) templateData.get('category')).toUpperCase();
        Boolean hasFlowButton = false;

        // Check buttons
        List<Object> components = (List<Object>) templateData.get('components');
        for (Object compObj : components) {
            Map<String, Object> comp = (Map<String, Object>) compObj;
            if (comp.get('type') == 'BUTTONS') {
                List<Object> buttons = (List<Object>) comp.get('buttons');
                for (Object btn : buttons) {
                    Map<String, Object> button = (Map<String, Object>) btn;
                    String buttonType = (String) button.get('type');
                    if (buttonType == 'FLOW') {
                        hasFlowButton = true;
                        break;
                    }
                }
            }
            if (hasFlowButton) break;
        }

        // Apply rules
        if (category == 'MARKETING') {
            return hasFlowButton ? 'Flow' : 'Custom';
        } else if (category == 'UTILITY') {
            return hasFlowButton ? 'flowutility' : 'Custom';
        } else if (category == 'AUTHENTICATION') {
            return 'One-time passcode';
        }  else {
            return 'Custom';
        }
    }

    public static PublicUrlContentWapper getMediaPublicUrl(String mediaUrl,String templateName) {
        // MVWB__WBConnect_Configuration__mdt configData = !config.isEmpty() ? config[0] : null;
        String publicUrl = '';
        DownloadWhatsAppMediaWrapper fileBlob = downloadWhatsAppMedia(mediaUrl);
        PublicUrlContentWapper publicUrlWrapper = new PublicUrlContentWapper();

        if(fileBlob.blobData!=null) {
            String mediaFileName = generateUniqueFilename(templateName, fileBlob.contentType);
            if((configData[0]!=null)&&(configData[0].MVWB__AWS_Secret_Access_Key__c != null)){
                publicUrl = AWSFilesController.uploadFileToS3(mediaFileName,fileBlob.blobData,fileBlob.contentType);
                publicUrlWrapper.contentVersionId = null;
                publicUrlWrapper.publicUrl = publicUrl;
            }
            else{
                String base64String = EncodingUtil.base64Encode(fileBlob.blobData);
                Map<String,String> contentVersionFileContent = FileUploaderController.uploadFile(base64String,mediaFileName);
                publicUrlWrapper.contentVersionId = contentVersionFileContent.get('contentVersionId');
                publicUrlWrapper.publicUrl = contentVersionFileContent.get('publicUrl');
            }
            publicUrlWrapper.fileName =  mediaFileName;
        }
        
        return publicUrlWrapper;
    }

    public static DownloadWhatsAppMediaWrapper downloadWhatsAppMedia(String downloadUrl) {
        String accessToken = config[0].MVWB__Access_Token__c;

        DownloadWhatsAppMediaWrapper downloadMediaWrapper = new DownloadWhatsAppMediaWrapper();

        Http http = new Http();
        HttpRequest req = new HttpRequest();
        req.setEndpoint(downloadUrl);
        req.setMethod('GET');
        req.setHeader('Authorization', 'Bearer ' + accessToken);
        req.setHeader('Accept', '*/*');

        HttpResponse res = http.send(req);
        if (res.getStatusCode() == 200) {
            downloadMediaWrapper.blobData = res.getBodyAsBlob();
            downloadMediaWrapper.contentType = res.getHeader('Content-Type');
            System.debug(res.getBodyAsBlob());

            return downloadMediaWrapper; // ✅ Now this matches the return type
        } else {
            System.debug('❌ WhatsApp media download failed. Code: ' + res.getStatusCode());
            System.debug(res.getBody());
            throw new AuraHandledException('Failed to download media.');
        }
    }

    global static String generateUniqueFilename(String templateName, String contentType) {
        // Step 1: Map content type to file extension
        Map<String, String> extensionMap = new Map<String, String>{
            'image/jpeg' => 'jpg',
            'image/png' => 'png',
            'application/pdf' => 'pdf',
            'video/mp4' => 'mp4',
            'application/json' => 'json'
        };

        String extension = extensionMap.containsKey(contentType) ? extensionMap.get(contentType) : 'bin';

        // Step 2: Format current date and time
        String dateStr = DateTime.now().format('yyyyMMdd_HHmmss');

        // Step 3: Generate a short random string
        String randomStr = EncodingUtil.convertToHex(Crypto.generateDigest('SHA1', Blob.valueOf(String.valueOf(Math.random())))).substring(0, 6).toUpperCase();

        // Step 4: Combine all
        return templateName + '_' + dateStr + '_' + randomStr + '.' + extension;
    }

    // public static String handleButtonComponent(Map<String, Object> component) {
    //     String buttonList = '';
    //     try {
    //         List<Object> buttons = (List<Object>) component.get('buttons');
    
    //         if (buttons != null) {
    //             buttonList = (String) JSON.serialize(buttons);
                
    //         }
    //     } catch (Exception e) {
    //         ExceptionHandler.logException(new Map<String, Object>{'className' => 'CreateTemplateWrapper', 'methodName' => 'handleButtonComponent', 'exceptionObj' => e, 'isApiException' => false, 'statusCode' => null, 'chatId' => null, 'moreDetails' => e.getMessage(), 'apiResponse' => null});
    //     }
    //     return buttonList; 
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