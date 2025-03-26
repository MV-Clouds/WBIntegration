public without sharing class CreateTemplateController {

    public static String currentTime = System.now().format('yyyy-MM-dd HH:mm:ss');

    @AuraEnabled(cacheable=true)
    public static List<WhatsApp_Template__c> getWhatsAppTemplates() {
        List<WhatsApp_Template__c> listName = [SELECT Id, Name, Category__c, Language__c, Status__c, LastModifiedById, CreatedDate 
                                                 FROM WhatsApp_Template__c WITH SECURITY_ENFORCED ORDER BY LastModifiedDate DESC];
        
        System.debug('list name==> ' + listName);
        
        return listName;
    }
    

    @AuraEnabled(cacheable=true)
    public static Boolean doesTemplateExist(String templateName) {
        Integer count = [SELECT COUNT() FROM WhatsApp_Template__c WHERE Name = :templateName WITH SECURITY_ENFORCED];
        return count > 0;
    }
    
    @AuraEnabled(cacheable=true)
    public static Map<String, List<String>> getCategoryAndStatusPicklistValues() {
        Map<String, List<String>> picklistValues = new Map<String, List<String>>();

        List<String> categoryValues = new List<String>();
        List<String> statusValues = new List<String>();

        // Fetch Category__c picklist values
        Schema.DescribeFieldResult categoryFieldResult = WhatsApp_Template__c.Category__c.getDescribe();
        for (Schema.PicklistEntry entry : categoryFieldResult.getPicklistValues()) {
            categoryValues.add(entry.getLabel());
        }

        // Fetch Status__c picklist values
        Schema.DescribeFieldResult statusFieldResult = WhatsApp_Template__c.Status__c.getDescribe();
        for (Schema.PicklistEntry entry : statusFieldResult.getPicklistValues()) {
            statusValues.add(entry.getLabel());
        }

        picklistValues.put('categories', categoryValues);
        picklistValues.put('statuses', statusValues);

        return picklistValues;
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getCountryCodes() {
        StaticResource sr = [SELECT Body FROM StaticResource WHERE Name = 'CountryJson' WITH SECURITY_ENFORCED LIMIT 1];
        String jsonData = sr.Body.toString();
        
        List<Object> countryList = (List<Object>) JSON.deserializeUntyped(jsonData);
        
        List<Map<String, String>> result = new List<Map<String, String>>();
        
        for (Object obj : countryList) {
            Map<String, Object> country = (Map<String, Object>) obj;
            Map<String, String> countryData = new Map<String, String>();
            
            countryData.put('code', (String) country.get('code'));
            countryData.put('callingCode', (String) country.get('callingCode'));
            countryData.put('name', (String) country.get('name'));
            result.add(countryData);
        }
        
        return result;
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getLanguages() {
        StaticResource sr = [SELECT Body FROM StaticResource WHERE Name = 'LanguageJson' WITH SECURITY_ENFORCED LIMIT 1];
        String jsonData = sr.Body.toString();
        
        List<Object> languageList = (List<Object>) JSON.deserializeUntyped(jsonData);
        
        List<Map<String, String>> result = new List<Map<String, String>>();
        
        for (Object obj : languageList) {
            Map<String, Object> language = (Map<String, Object>) obj;
            Map<String, String> languageData = new Map<String, String>();
            
            languageData.put('language', (String) language.get('language'));
            languageData.put('code', (String) language.get('code'));
            result.add(languageData);
        }
        
        return result;
    }

    @AuraEnabled
    public static Map<String, Object> createWhatsappTemplate(String serializedWrapper) {
        Map<String, Object> response = new Map<String, Object>();

        try {
            CreateTemplateWrapper.TemplateWrapper templateWrapper = (CreateTemplateWrapper.TemplateWrapper) JSON.deserialize(serializedWrapper, CreateTemplateWrapper.TemplateWrapper.class);
            System.debug('Deserialized TemplateWrapper: ' + templateWrapper);

            String accessToken = System.Label.access_token_for_whatsapp;
            String endpoint = System.Label.whatsapp_template_endpoint;

            Map<String, Object> payload = CreateTemplateWrapper.buildPayload(templateWrapper);
            
            HttpRequest req = new HttpRequest();
            req.setEndpoint(endpoint);
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setHeader('Authorization', 'Bearer ' + accessToken);
            req.setBody(JSON.serialize(payload));
    
            Http http = new Http();
            HttpResponse res = http.send(req);
            System.debug('Response Body ==>' + res.getBody());

            if (res.getStatusCode() == 200) {
                CreateTemplateWrapper.handleSuccessResponse(res, payload, response,templateWrapper);
            } else {
                response.put('success', false);
                response.put('errorMessage', res.getBody());
            }
        } catch (Exception e) {
            System.debug('Error: ' + e.getMessage());
            response.put('status', 'error');
            response.put('message', e.getMessage());
        }

        return response;
    }

    @AuraEnabled
    public static string deleteTemplete(String templateId){
        try {
            WhatsApp_Template__c waTempRec = [SELECT Id, Name FROM WhatsApp_Template__c WHERE Id =: templateId WITH SECURITY_ENFORCED LIMIT 1];
            
            String accessToken = System.Label.access_token_for_whatsapp;
            String endpoint = System.Label.whatsapp_template_endpoint + '?name=' + waTempRec.Name;
            System.debug('endpoint: '+endpoint);

            HttpRequest req = new HttpRequest();         
            req.setEndpoint(endpoint);
            req.setMethod('DELETE');
            req.setHeader('Content-Type', 'application/json');
            req.setHeader('Authorization', 'Bearer ' + accessToken);
            Http http = new Http();
            HttpResponse res = http.send(req);
            System.debug('Response Body ==>' + res.getBody());

            if (res.getBody() != null && res.getBody() != '') {
                Map<String, Object> jsonResponse = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                
                if (jsonResponse.containsKey('success')) {
                    Boolean success = (Boolean) jsonResponse.get('success');
                    if (success) {
                        if(WhatsApp_Template__c.sObjectType.getDescribe().isDeletable()){
                            DELETE waTempRec;
                        }

                        System.debug('The operation was successful.');
                        return 'Template deleted successfully';
                    } else {
                        System.debug('The operation was not successful.');
                        return 'Template is not deleted';
                    }
                } else {
                    System.debug('The response does not contain a success key.');
                    return 'Template is not deleted';
                }
            } else {
                System.debug('Response body is empty or null.');
                return 'Template is not deleted';
            }
        } catch (Exception e) {
            return e.getMessage();
        }
    }

    @AuraEnabled
    public static String startUploadSession(String fileName, Integer fileLength, String fileType) {
        try {
            String accessToken = System.Label.access_token_for_whatsapp;
            String endpoint = 'https://graph.facebook.com/v21.0/514916280628381/uploads';
    
            Map<String, Object> payload = new Map<String, Object>();
            payload.put('file_name', fileName);
            payload.put('file_length', fileLength);
            payload.put('file_type', fileType);
            
            HttpRequest req = new HttpRequest();
            Http http = new Http();
            req.setEndpoint(endpoint);
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setHeader('Authorization', 'OAuth ' + accessToken);
            req.setBody(JSON.serialize(payload));

            HttpResponse res = http.send(req);
            System.debug('Upload session response: ' + res.getBody());
            if (res.getStatusCode() == 200) {
                Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                String sessionId = (String) responseMap.get('id');
                if (sessionId != null && sessionId.startsWith('upload:')) {
                    sessionId = sessionId.replace('upload:', ''); 
                }

                return sessionId; 
            } else {
                System.debug('Error starting upload session: ' + res.getBody());
            }
        } catch (Exception e) {
            System.debug('Error in startUploadSession: ' + e.getMessage());
        }
        return null;
    }        
    
    @AuraEnabled
    public static String uploadFileChunk(String uploadSessionId, String fileContent, Integer chunkStart, Integer chunkSize) {
        try {
            Blob fileBlob = EncodingUtil.base64Decode(fileContent);

            String accessToken = System.Label.access_token_for_whatsapp;
            HttpRequest req = new HttpRequest();
            Http http = new Http();

            String endpoint = 'https://graph.facebook.com/v21.0/upload:' + uploadSessionId;
            req.setEndpoint(endpoint);
            req.setMethod('POST');            
            req.setHeader('Authorization', 'OAuth ' + accessToken);
            req.setHeader('file_offset' ,'0');            
            req.setHeader('Content-Range', 'bytes ' + chunkStart + '-' + (chunkStart + chunkSize - 1) + '/' + fileBlob.size());            
            
            // Set the body as Blob
            req.setBodyAsBlob(fileBlob);

            HttpResponse res = http.send(req);
            System.debug('File chunk upload response: ' + res.getBody());

            if (res.getStatusCode() == 200) {
                Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                String headerHandle = (String) responseMap.get('h');
                // if (headerHandle != null && headerHandle.startsWith('upload:')) {
                //     headerHandle = headerHandle.replace('upload:', ''); 
                // }

                return headerHandle; 
            } else {
                System.debug('Error uploading file chunk: ' + res.getBody());
            }
        } catch (Exception e) {
            System.debug('Error in uploadFileChunk: ' + e.getMessage());
        }
        return '';
    }

    private static Blob getBlobChunk(Blob blobdata, Integer start, Integer size) {
        String blobAsString = blobdata.toString();
        String chunkString = blobAsString.substring(start, start + size);
        return Blob.valueOf(chunkString);
    }

}