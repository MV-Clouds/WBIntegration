/**
 * Class Name: WBTemplateController
 * Test Class: 
 * @description: Used in LWC components, it used to get the template record, 
                picklist value from static resource and callout for creation of template.
 * Date: 25/11/2024
 * Created By: Kajal Tiwari
 */
 /***********************************************************************
 MODIFICATION LOG*
 * Last Update Date : 3/11/2024
 * Updated By : Kajal Tiwari
 * Name of methods changed (Comma separated if more then one) : getDynamicObjectData
 * Change Description : Get dynamic template and contact data.
 ***********************************************************************/

public with sharing class WBTemplateController {
    
    public static String accessToken = System.Label.WHATSAPP_ACCESS_TOKEN;
    public static String endpoint = System.Label.WHATSAPP_TEMPLATE_ENPOINT;
    public static String uploadEndpoint = System.Label.WB_TEMPLATE_UPLOAD_FILE;

    // Used in WbAllTemplatePage to get all template record.
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

    // Used to fetch all the field related to object name
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

     // Fetch records based on the object name
     @AuraEnabled(cacheable=true)
     public static List<sObject> getRecordsBySObject() {
         String sObjectName='Contact';
         List<sObject> records = new List<sObject>();
         
         try {
             String query = 'SELECT Id, Name FROM ' + sObjectName + ' LIMIT 100';             
             records = Database.query(query);
             System.debug('records '+records);
         } catch (Exception e) {
             System.debug('Error fetching records: ' + e.getMessage());
             ExceptionLog.exception(e.getMessage(), 'WBTemplateController', 'getObjectFields',e.getLineNumber());
         }
         return records;
     }

    @AuraEnabled(cacheable=true)
    public static TemplateDataWrapper getDynamicObjectData() {
        TemplateDataWrapper wrapper = new TemplateDataWrapper();
        Set<String> objectNames = new Set<String>();
        Set<String> fieldNames = new Set<String>();

        try {
            // Fetch the specific template
            Template__c template = [
                SELECT Id, Name, Header_Body__c, Template_Body__c, Footer_Body__c, Button_Label__c
                FROM Template__c WITH SECURITY_ENFORCED
                ORDER BY CreatedDate DESC 
                LIMIT 1 
            ];
    
            if (template == null) {
                System.debug('No template found.');
            }
            wrapper.template = template;
    
            // Fetch related template variable data
            List<Template_Variable__c> templateVariables = [
                SELECT Object_Name__c, Field_Name__c 
                FROM Template_Variable__c 
                WHERE Template__c = :template.Id WITH SECURITY_ENFORCED
            ];
    
            if (templateVariables.isEmpty()) {
                System.debug('No template variables found for the template.');
                return wrapper;
            }

            for (Template_Variable__c variable : templateVariables) {
                objectNames.add(variable.Object_Name__c);
                fieldNames.add(variable.Field_Name__c);
            }

            // Set the object names and field names to the wrapper
            wrapper.objectNames = new List<String>(objectNames);
            wrapper.fieldNames = new List<String>(fieldNames);
    
        } catch (Exception e) {
            System.debug('Error in getDynamicObjectData: ' + e.getMessage());
            ExceptionLog.exception(e.getMessage(), 'WBTemplateController', 'getDynamicObjectData', e.getLineNumber());
        }
    
        return wrapper;
    }
 
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> fetchDynamicRecordData(String objectName, List<String> fieldNames, String recordId) {
        Map<String, Object> resultMap = new Map<String, Object>();

        try {
            if (String.isEmpty(objectName) || fieldNames.isEmpty() || String.isEmpty(recordId)) {
                throw new AuraHandledException('Invalid input parameters');
            }

            String fields = String.join(fieldNames, ',');
            
            String queryString = 'SELECT ' + fields + ' FROM ' + objectName + ' WHERE Id = :recordId LIMIT 1';            
            List<SObject> queriedData = Database.query(queryString);

            if (!queriedData.isEmpty()) {
                resultMap.put('queriedData', queriedData[0]);  
            } else {
                resultMap.put('queriedData', null);
            }

        } catch (Exception e) {
            System.debug('Error in fetchDynamicRecordData: ' + e.getMessage());
            resultMap.put('error', e.getMessage());
        }

        return resultMap;
    }
    
    // It used to replace value of field with the variable placeholder in preview page.
    @AuraEnabled(cacheable=true)
    public static Map<String, String> getTemplateWithReplacedValues(String recordId) {
        try {
            Template__c template = [SELECT Id, Name, Template_Body__c, Header_Body__c FROM Template__c WITH SECURITY_ENFORCED ORDER BY CreatedDate DESC LIMIT 1];

            List<Template_Variable__c> variables = [
                SELECT Id, Object_Name__c, Field_Name__c, Type__c, Alternate_Text__c
                FROM Template_Variable__c
                WHERE Template__c = :template.Id WITH SECURITY_ENFORCED
            ];

            Map<Integer, String> headerFieldMapping = new Map<Integer, String>();
            Map<Integer, String> bodyFieldMapping = new Map<Integer, String>();
            String templateHeader = template.Header_Body__c	 != null ? template.Header_Body__c	 : '';
            String templateBody = template.Template_Body__c	 != null ? template.Template_Body__c	 : '';

            String objectName = 'Contact';
            List<String> fields = new List<String>();

            Integer headerIndex = 1;
            Integer bodyIndex = 1;
            for (Template_Variable__c var : variables) {
                objectName = var.Object_Name__c; 
                fields.add(var.Field_Name__c);
                if (var.Type__c == 'Header') {
                    headerFieldMapping.put(headerIndex, var.Field_Name__c);
                    headerIndex++;
                } else if (var.Type__c == 'Body') {
                    bodyFieldMapping.put(bodyIndex, var.Field_Name__c);
                    bodyIndex++;
                }
            }
            fields = new List<String>(new Set<String>(fields));

            String query = 'SELECT ' + String.join(fields, ',') + ' FROM ' + objectName + ' WHERE Id = :recordId WITH SECURITY_ENFORCED';
            SObject record = Database.query(query);

            for (Integer i : headerFieldMapping.keySet()) {
                String fieldName = headerFieldMapping.get(i);
                Object value = record.get(fieldName);
    
                String replacementValue = (value != null) ? value.toString() : variables[i - 1].Alternate_Text__c;
                templateHeader = templateHeader.replace('{{' + i + '}}', replacementValue);
            }
    
            for (Integer i : bodyFieldMapping.keySet()) {
                String fieldName = bodyFieldMapping.get(i);
                Object value = record.get(fieldName);
    
                String replacementValue = (value != null) ? value.toString() : variables[i - 1].Alternate_Text__c;
                templateBody = templateBody.replace('{{' + i + '}}', replacementValue);
            }

            Map<String, String> result = new Map<String, String>();
            result.put('header', templateHeader);
            result.put('body', templateBody);
            System.debug('result '+result);
            return result;

        } catch (Exception e) {
            ExceptionLog.exception(e.getMessage(), 'WBTemplateController', 'getTemplateWithReplacedValues', e.getLineNumber());
            return null;
        }
    }

    // Check if same template already exist.
    @AuraEnabled(cacheable=true)
    public static Boolean doesTemplateExist(String templateName) {
        Integer count = [SELECT COUNT() FROM Template__c WHERE Name = :templateName WITH SECURITY_ENFORCED];
        return count > 0;
    }
    
    // Get picklist value for catagory and status used in WbAllTemplatePage to filter.
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

    // Fetch country and code which used as picklist in the Create Template Page.
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

    // Fetch language and code which used as picklist in the Create Template Page.
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

    // Callout to create template in the Meta and the Body creation and response handle in CreateTemplateWrapper Class.
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
                Map<String, Object> responseBody = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                String templateId = (String) responseBody.get('templateId'); 

                response.put('success', true);
                response.put('templateId', templateId);
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

    // Method to get session Id for uploading file to meta.
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

    // Method to upload file to meta and get file handle which use to create body for image header.
    @AuraEnabled
    public static String uploadFileChunk(String serializedWrapper) {
        try {
            FileChunkWrapper fileWrapper = (FileChunkWrapper) JSON.deserialize(serializedWrapper, FileChunkWrapper.class);

            Blob fileBlob = EncodingUtil.base64Decode(fileWrapper.fileContent);

            HttpRequest req = new HttpRequest();
            Http http = new Http();

            String endpoint = 'https://graph.facebook.com/v21.0/upload:' + fileWrapper.uploadSessionId;
            req.setEndpoint(endpoint);
            req.setMethod('POST');            
            req.setHeader('Authorization', 'OAuth ' + accessToken);
            req.setHeader('file_offset', String.valueOf(fileWrapper.chunkStart)); 
            req.setHeader('Content-Range', 'bytes ' + fileWrapper.chunkStart + '-' + (fileWrapper.chunkStart + fileWrapper.chunkSize - 1) + '/' + fileBlob.size());            
            
            req.setBodyAsBlob(fileBlob);

            HttpResponse res = http.send(req);
            System.debug('File chunk upload response: ' + res.getBody());

            if (res.getStatusCode() == 200) {
                Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                String headerHandle = (String) responseMap.get('h');                
                createContentVersionAndDocument(headerHandle, fileWrapper.fileName, fileBlob);

                return headerHandle; 
            } else {
                System.debug('Error uploading file chunk: ' + res.getBody());
            }
        } catch (Exception e) {
            System.debug('Error in uploadFileChunk: ' + e.getMessage());
            ExceptionLog.exception(e.getMessage(), 'WBTemplateController', 'uploadFileChunk', e.getLineNumber());
        }
        return '';
    }

    // Store the file in content version that can be used while sending template.
    private static void createContentVersionAndDocument(String headerHandle, String fileName, Blob fileBlob) {
        try {
            ContentVersion contentVersion = new ContentVersion();
            contentVersion.Title = fileName;
            contentVersion.PathOnClient = fileName;
            contentVersion.VersionData = fileBlob;
            contentVersion.Origin = 'H'; 

            if (Schema.sObjectType.ContentVersion.isCreateable()) {
                insert contentVersion;
            }            
            
            System.debug('Created ContentVersion and ContentDocument: ' + contentVersion.Id + ', ' + contentDocument.Id);
        } catch (Exception e) {
            System.debug('Error creating ContentVersion and ContentDocument: ' + e.getMessage());
            ExceptionLog.exception(e.getMessage(), 'WBTemplateController', 'createContentVersionAndDocument', e.getLineNumber());
        }
    }

    // Method used to delete template from meta as well as from record page.
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
            ExceptionLog.exception(e.getMessage(), 'WBTemplateController', 'deleteTemplete',e.getLineNumber());
            return e.getMessage();
        }
    }

    public class FileChunkWrapper {
        @AuraEnabled public String uploadSessionId;
        @AuraEnabled public String fileContent;
        @AuraEnabled public Integer chunkStart;
        @AuraEnabled public Integer chunkSize;
        @AuraEnabled public String fileName;
    }
    public class TemplateDataWrapper {
        @AuraEnabled public Template__c template;
        // @AuraEnabled public Object queriedData;
        @AuraEnabled public List<String> objectNames;
        @AuraEnabled public List<String> fieldNames;
    }
}