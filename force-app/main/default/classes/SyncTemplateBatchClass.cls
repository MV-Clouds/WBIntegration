public with sharing class SyncTemplateBatchClass implements Database.Batchable<String>, Database.AllowsCallouts {
    Map<String, Object> allMetaTemplatesMap;
    public static List<MVWB__AWS_Config__c> configList = [SELECT Id, MVWB__AWS_Access_Key__c, MVWB__AWS_Secret_Access_Key__c, MVWB__S3_Bucket_Name__c, MVWB__S3_Region_Name__c, CreatedDate, LastModifiedDate FROM MVWB__AWS_Config__c WITH SECURITY_ENFORCED LIMIT 1];

    public SyncTemplateBatchClass(Map<String, Object> allMetaTemplatesMap) {
        this.allMetaTemplatesMap = allMetaTemplatesMap;
    }

    public Iterable<String> start(Database.BatchableContext BC) {
        return allMetaTemplatesMap.keySet();
    }

      public void execute(Database.BatchableContext BC, List<String> scope) {
        processTemplateBatch(scope);
    }


    public void finish(Database.BatchableContext BC) {
        // Optional: send email or log
        System.debug('Batch Finished');
    }

    private void processTemplateBatch(List<String> templateNames) {
        List<Template__c> templatesToInsert = new List<Template__c>();
        List<Template_Variable__c> allVarsToInsert = new List<Template_Variable__c>();
        Map<String, List<Template_Variable__c>> templateNameToVars = new Map<String, List<Template_Variable__c>>();

        for (String templateName : templateNames) {
            Map<String, Object> templateData = (Map<String, Object>) allMetaTemplatesMap.get(templateName);

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
                    if (buttons != null) {
                        buttonDetails = (String) JSON.serialize(buttons);
                        
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
            miscFlags.put('authRadioButton', 'zero_tap');
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
            System.debug('Button body ::: '+buttonDetails);
            whatsAppTemplate.WBButton_Body__c = (String) buttonDetails;
            System.debug('Button body ::: '+buttonDetails);
            whatsAppTemplate.Status__c = formatStatus(metaTemplateStatus);
            
            if (tw.tempHeaderFormat == 'IMAGE' || tw.tempHeaderFormat == 'VIDEO' || tw.tempHeaderFormat == 'DOCUMENT') {
                whatsAppTemplate.Header_Type__c = tw.tempHeaderFormat;
                whatsAppTemplate.WBImage_Header_Handle__c = tw.tempHeaderHandle;
                whatsAppTemplate.File_Name__c = tw.tempImgName;
                whatsAppTemplate.WBHeader_Body__c = tw.tempImgUrl;
            } else {
                whatsAppTemplate.Header_Type__c = 'TEXT';
                whatsAppTemplate.WBHeader_Body__c = tw.tempHeaderText;
            }

            whatsAppTemplate.WBFooter_Body__c = tw.tempFooterText;
            whatsAppTemplate.WBTemplate_Body__c = tw.templateBody;
            // whatsAppTemplate.WBButton_Body__c = tw.url;

            templatesToInsert.add(whatsAppTemplate);

            // Collect template variables for this template
            String fixedObject = 'Account';
            String fixedField = 'AccountNumber';
            List<Template_Variable__c> currentTemplateVars = new List<Template_Variable__c>();

            Integer headCount = 1;
            for (String headAlt : tw.headAlternateTexts) {
                currentTemplateVars.add(new Template_Variable__c(
                    Name = '{{'+headCount+'}}',
                    Type__c = 'Header',
                    Object_Name__c = fixedObject,
                    Field_Name__c = fixedField,
                    Alternate_Text__c = headAlt
                ));
                headCount++;
            }

            Integer bodyCount = 1;
            for (String bodyAlt : tw.varAlternateTexts) {
                currentTemplateVars.add(new Template_Variable__c(
                    Name = '{{'+bodyCount+'}}',
                    Type__c = 'Body',
                    Object_Name__c = fixedObject,
                    Field_Name__c = fixedField,
                    Alternate_Text__c = bodyAlt
                ));
                bodyCount++;
            }

            templateNameToVars.put(templateName, currentTemplateVars);
        }

        // Insert templates and assign variables correctly
        if (!templatesToInsert.isEmpty()) {
            insert templatesToInsert;

            for (Template__c insertedTemplate : templatesToInsert) {
                String templateName = insertedTemplate.Template_Name__c;
                if (templateNameToVars.containsKey(templateName)) {
                    List<Template_Variable__c> varsForThisTemplate = templateNameToVars.get(templateName);
                    for (Template_Variable__c var : varsForThisTemplate) {
                        var.Template__c = insertedTemplate.Id;
                    }
                    allVarsToInsert.addAll(varsForThisTemplate);
                }
            }
        }

        if (!allVarsToInsert.isEmpty()) {
            insert allVarsToInsert;
        }
    }

    private static String formatStatus(String status) {
        if (String.isBlank(status)) return 'In-Review';
        if (status == 'PENDING') return 'In-Review';
        if (status == 'REJECTED') return 'Rejected';
        if (status == 'APPROVED') return 'Active-Quality Pending';
        return status;
    }

    private static String determineTemplateType(Map<String, Object> templateData) {
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

    private static PublicUrlContentWapper getMediaPublicUrl(String mediaUrl,String templateName) {
        MVWB__AWS_Config__c configData = !configList.isEmpty() ? configList[0] : null;
        String publicUrl = '';
        DownloadWhatsAppMediaWrapper fileBlob = downloadWhatsAppMedia(mediaUrl);
        PublicUrlContentWapper publicUrlWrapper = new PublicUrlContentWapper();

        if(fileBlob.blobData!=null) {
            String mediaFileName = generateUniqueFilename(templateName, fileBlob.contentType);
            if((configData!=null)&&(configData.MVWB__AWS_Secret_Access_Key__c != null)){
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

    private static DownloadWhatsAppMediaWrapper downloadWhatsAppMedia(String downloadUrl) {
        List<MVWB__WBConnect_Configuration__mdt> config = MVWB__WBConnect_Configuration__mdt.getAll().values();
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

    public static String generateUniqueFilename(String templateName, String contentType) {
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