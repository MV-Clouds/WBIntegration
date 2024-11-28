 /**
 * Class Name: WBTemplateController
 * Test Class: 
 * @description: Used in WbAllTemplatePage LWC components, it used to get the template record, 
                picklist value from static resource and callout for creation of template.
 * Date: 25/11/2024
 * Created By: Kajal Tiwari
 */
 /***********************************************************************
 MODIFICATION LOG*
 * Last Update Date : 27/11/2024
 * Updated By : Kajal Tiwari
 * Name of methods changed (Comma separated if more then one) : deleteTemplete 
 * Change Description : Added method to delete template from meta as well as record page.
 ***********************************************************************/

public with sharing class WBTemplateController {
    
    public static String accessToken = System.Label.WHATSAPP_ACCESS_TOKEN;
    public static String endpoint = System.Label.WHATSAPP_TEMPLATE_ENPOINT;
    public static String uploadEndpoint = System.Label.WB_TEMPLATE_UPLOAD_FILE;

    @AuraEnabled(cacheable=true)
    public static List<Template__c> getWhatsAppTemplates() {
        try {
            List<Template__c> listName = [SELECT Id, Name, Template_Category__c, Language__c, Status__c, LastModifiedById, CreatedDate 
            FROM Template__c WITH SECURITY_ENFORCED ORDER BY LastModifiedDate DESC];

            System.debug('list name==> ' + listName);
            return listName;
        } catch (Exception e) {
            ExceptionLog.exception(e.getMessage(), 'WBTemplateController', 'getWhatsAppTemplates',e.getLineNumber());
            System.debug('Error in getWhatsAppTemplates: ' + e.getMessage() + '\n' + e + '\n Exception line no: ' + e.getLineNumber());
            return null;
        }
       
    }

    @AuraEnabled(cacheable=true)
    public static List<String> getObjectFields() {
        String objectName = 'Contact';
        List<String> fieldNames = new List<String>();
        try {
            Schema.DescribeSObjectResult objDescribe = Schema.getGlobalDescribe().get(objectName).getDescribe();
            Map<String, Schema.SObjectField> fieldsMap = objDescribe.fields.getMap();
            for (String fieldName : fieldsMap.keySet()) {
                fieldNames.add(fieldsMap.get(fieldName).getDescribe().getName()); 
            }
            fieldNames.sort();
        } catch (Exception e) {
            System.debug('Error fetching fields: ' + e.getMessage());
            ExceptionLog.exception(e.getMessage(), 'WBTemplateController', 'getObjectFields',e.getLineNumber());
        }
        return fieldNames;
    }

    @AuraEnabled(cacheable=true)
    public static Boolean doesTemplateExist(String templateName) {
        Integer count = [SELECT COUNT() FROM Template__c WHERE Name = :templateName WITH SECURITY_ENFORCED];
        return count > 0;
    }
    
    @AuraEnabled(cacheable=true)
    public static Map<String, List<String>> getCategoryAndStatusPicklistValues() {
        Map<String, List<String>> picklistValues = new Map<String, List<String>>();

        List<String> categoryValues = new List<String>();
        List<String> statusValues = new List<String>();

        try {
            // Fetch Category__c picklist values
            Schema.DescribeFieldResult categoryFieldResult = Template__c.Template_Category__c.getDescribe();
            for (Schema.PicklistEntry entry : categoryFieldResult.getPicklistValues()) {
                categoryValues.add(entry.getLabel());
            }

            // Fetch Status__c picklist values
            Schema.DescribeFieldResult statusFieldResult = Template__c.Status__c.getDescribe();
            for (Schema.PicklistEntry entry : statusFieldResult.getPicklistValues()) {
                statusValues.add(entry.getLabel());
            }

            picklistValues.put('categories', categoryValues);
            picklistValues.put('statuses', statusValues);

            return picklistValues;
        } catch (Exception e) {
            ExceptionLog.exception(e.getMessage(), 'WBTemplateController', 'getCategoryAndStatusPicklistValues',e.getLineNumber());
            System.debug('Error in getCategoryAndStatusPicklistValues: ' + e.getMessage() + '\n' + e + '\n Exception line no: ' + e.getLineNumber());
            return null;
        }
        
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getCountryCodes() {
        List<Map<String, String>> result = new List<Map<String, String>>();
        try {
            StaticResource sr = [SELECT Body FROM StaticResource WHERE Name = 'CountryJson' WITH SECURITY_ENFORCED LIMIT 1];
            String jsonData = sr.Body.toString();
            
            List<Object> countryList = (List<Object>) JSON.deserializeUntyped(jsonData);
            
            for (Object obj : countryList) {
                Map<String, Object> country = (Map<String, Object>) obj;
                Map<String, String> countryData = new Map<String, String>();
                
                countryData.put('code', (String) country.get('code'));
                countryData.put('callingCode', (String) country.get('callingCode'));
                countryData.put('name', (String) country.get('name'));
                result.add(countryData);
            }
            
            return result;
        } catch (Exception e) {
            ExceptionLog.exception(e.getMessage(), 'WBTemplateController', 'getCountryCodes',e.getLineNumber());
            System.debug('Error in getCountryCodes: ' + e.getMessage() + '\n' + e + '\n Exception line no: ' + e.getLineNumber());
            return null;
        }
       
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getLanguages() {
        List<Map<String, String>> result = new List<Map<String, String>>();
        try {
            StaticResource sr = [SELECT Body FROM StaticResource WHERE Name = 'LanguageJson' WITH SECURITY_ENFORCED LIMIT 1];
            String jsonData = sr.Body.toString();
            
            List<Object> languageList = (List<Object>) JSON.deserializeUntyped(jsonData);
            
            
            for (Object obj : languageList) {
                Map<String, Object> language = (Map<String, Object>) obj;
                Map<String, String> languageData = new Map<String, String>();
                
                languageData.put('language', (String) language.get('language'));
                languageData.put('code', (String) language.get('code'));
                result.add(languageData);
            }
            
            return result;
        } catch (Exception e) {
            ExceptionLog.exception(e.getMessage(), 'WBTemplateController', 'getLanguages',e.getLineNumber());
            System.debug('Error in getLanguages: ' + e.getMessage() + '\n' + e + '\n Exception line no: ' + e.getLineNumber());
            return null;
        }
    }

    @AuraEnabled
    public static Map<String, Object> createWhatsappTemplate(String serializedWrapper) {
        Map<String, Object> response = new Map<String, Object>();

        try {
            CreateTemplateWrapper.TemplateWrapper templateWrapper = (CreateTemplateWrapper.TemplateWrapper) JSON.deserialize(serializedWrapper, CreateTemplateWrapper.TemplateWrapper.class);
            System.debug('Deserialized TemplateWrapper: ' + templateWrapper);

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
            ExceptionLog.exception(e.getMessage(), 'WBTemplateController', 'createWhatsappTemplate',e.getLineNumber());
            System.debug('Error in createWhatsappTemplate: ' + e.getMessage() + '\n' + e + '\n Exception line no: ' + e.getLineNumber());
            response.put('status', 'error');
            response.put('message', e.getMessage());
        }

        return response;
    }

    @AuraEnabled
    public static String startUploadSession(String fileName, Integer fileLength, String fileType) {
        try {
            Map<String, Object> payload = new Map<String, Object>();
            payload.put('file_name', fileName);
            payload.put('file_length', fileLength);
            payload.put('file_type', fileType);
            
            HttpRequest req = new HttpRequest();
            Http http = new Http();
            req.setEndpoint(uploadEndpoint);
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
            ExceptionLog.exception(e.getMessage(), 'WBTemplateController', 'startUploadSession',e.getLineNumber());

        }
        return null;
    }        
    
    @AuraEnabled
    public static String uploadFileChunk(String uploadSessionId, String fileContent, Integer chunkStart, Integer chunkSize) {
        try {
            Blob fileBlob = EncodingUtil.base64Decode(fileContent);

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
            ExceptionLog.exception(e.getMessage(), 'WBTemplateController', 'uploadFileChunk',e.getLineNumber());
        }
        return '';
    }

    private static Blob getBlobChunk(Blob blobdata, Integer start, Integer size) {
        String blobAsString = blobdata.toString();
        String chunkString = blobAsString.substring(start, start + size);
        return Blob.valueOf(chunkString);
    }
   
    @future (callout=true)
    public static void updateWhatsAppTemplateStatus(String templateId, String event) {
        try {
            List<Template__c> templates = [SELECT Id, Status__c FROM Template__c WHERE Template_Id__c = :templateId WITH SECURITY_ENFORCED LIMIT 1];
            
            if (!templates.isEmpty()) {
                Template__c wbTemplate = templates[0];
                
                if (event == 'APPROVED') {
                    wbTemplate.Status__c = 'Active-Quality Pending';
                } else if (event == 'PENDING') {
                    wbTemplate.Status__c = 'In-Review';
                } else if (event == 'REJECTED') {
                    wbTemplate.Status__c = 'Rejected';
                }
                
                update wbTemplate;
            } else {
                System.debug('No WhatsApp Template found for Template Id: ' + templateId);
            }
        } catch (Exception e) {
            System.debug('Exception in updateWhatsAppTemplateStatus: ' + e.getMessage());
            ExceptionLog.exception(e.getMessage(), 'WBTemplateController', 'updateWhatsAppTemplateStatus',e.getLineNumber());
        }
    }

    @AuraEnabled
    public static string deleteTemplete(String templateId){
        try {
            Template__c wbTempRec = [SELECT Id, Name FROM Template__c WHERE Id =: templateId WITH SECURITY_ENFORCED LIMIT 1];
            
            String deleteEndpoint = endpoint + '?name=' + wbTempRec.Name;
            System.debug('endpoint: '+endpoint);

            HttpRequest req = new HttpRequest();         
            req.setEndpoint(deleteEndpoint);
            req.setMethod('DELETE');
            req.setHeader('Content-Type', 'application/json');
            req.setHeader('Authorization', 'Bearer ' + accessToken);
            Http http = new Http();
            HttpResponse res = http.send(req);
            System.debug('Response Body ==>' + res.getBody());

            if (res.getBody() != null && res.getBody() != '') {
                Map<String, Object> jsonResponse = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                Boolean success = (Boolean) jsonResponse.get('success');
                if (success) {
                    if(Template__c.sObjectType.getDescribe().isDeletable()){
                        DELETE wbTempRec;
                    }

                    System.debug('The operation was successful.');
                    return 'Template deleted successfully';
                } else {
                    System.debug('The operation was not successful.');
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
}