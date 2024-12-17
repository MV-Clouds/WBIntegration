@isTest
public class WBTemplateControllerTest {

    @testSetup
    static void setup() {
        try{
            List<Template__c> templates = new List<Template__c>();
            for (Integer i = 1; i <= 5; i++) {
                templates.add(new Template__c(
                    Name = 'Template' + i,
                    Template_Category__c = 'Marketing',
                    Status__c = 'Active-Quality Pending'
                ));
            }
            insert templates;

            List<Template_Variable__c> variables = new List<Template_Variable__c>();
            for (Template__c template : [SELECT Id FROM Template__c]) {
                variables.add(new Template_Variable__c(
                    Template__c = template.Id,
                    Name = '{{1}}',
                    Object_Name__c = 'Contact',
                    Field_Name__c = 'FirstName'
                ));
            }
            insert variables;
    
            // Create Contacts for fetchRecordBySObject
            List<Contact> contacts = new List<Contact>();
            for (Integer i = 1; i <= 5; i++) {
                contacts.add(new Contact(FirstName = 'Test' + i, LastName = 'User' + i));
            }
            insert contacts;
        } catch (Exception e) {
            ExceptionHandler.logException(new Map<String, Object>{ 'className' => 'WBTemplateControllerTest', 'methodName' => 'setup', 'exceptionObj' => e, 'isApiException' => false, 'statusCode' => null, 'chatId' => null, 'moreDetails' => e.getMessage(), 'apiResponse' => null });
        }
    }

    @isTest
    static void testFetchWhatsAppTemplates() {
        try{
            List<Template__c> templates = WBTemplateController.getWhatsAppTemplates();
        	System.assertEquals(5, templates.size(), 'Templates count should be 5');
        } catch (Exception e) {
            ExceptionHandler.logException(new Map<String, Object>{ 'className' => 'WBTemplateControllerTest', 'methodName' => 'testFetchWhatsAppTemplates', 'exceptionObj' => e, 'isApiException' => false, 'statusCode' => null, 'chatId' => null, 'moreDetails' => e.getMessage(), 'apiResponse' => null });
        }
    }

      @isTest
    static void testGetDynamicObjectData_Success() {
        Template__c template = [SELECT Id FROM Template__c LIMIT 1];

        Test.startTest();
        WBTemplateController.TemplateDataWrapper result = WBTemplateController.getDynamicObjectData(template.Id);
        Test.stopTest();

        System.assertEquals(template.Id, result.template.Id, 'Template Id should match');
        System.assertEquals(1, result.templateVariables.size(), 'There should be one template variable');
        System.assertEquals('Contact', result.objectNames[0], 'Object Name should be Contact');
        System.assertEquals('FirstName', result.fieldNames[0], 'Field Name should be FirstName');
    }
    
      @isTest
    static void testGetRecordsBySObject() {
        Test.startTest();        
        List<sObject> records = WBTemplateController.getRecordsBySObject();
        Test.stopTest();
        
        System.assertNotEquals(null, records, 'Records should not be null');        
        Contact contactRecord = (Contact) records[0]; 
        System.assertNotEquals(null, contactRecord.Id, 'Contact Id should not be null');
        System.assertNotEquals(null, contactRecord.Name, 'Contact Name should not be null');
    }
    
    @isTest
    static void testFetchRecordBySObject() {
        try{
            Test.startTest();
            List<String> fields = WBTemplateController.getObjectFields('Contact');
            Test.stopTest();
            System.assert(fields.size() > 0, 'Records should be returned');        
            System.assert(fields.contains('Id'), 'Contact object should have an Id field');
            System.assert(fields.contains('FirstName'), 'Contact object should have FirstName field');
         } catch (Exception e) {
            ExceptionHandler.logException(new Map<String, Object>{ 'className' => 'WBTemplateControllerTest', 'methodName' => 'testFetchRecordBySObject', 'exceptionObj' => e, 'isApiException' => false, 'statusCode' => null, 'chatId' => null, 'moreDetails' => e.getMessage(), 'apiResponse' => null });
        }
    }

    @isTest
    static void testFetchDynamicRecordData() {
        try{
             Contact contact = [SELECT Id FROM Contact LIMIT 1];
            List<String> fieldNames = new List<String>{'FirstName', 'LastName', 'Email'};
              Test.startTest();
            Map<String, Object> resultMap = WBTemplateController.fetchDynamicRecordData('Contact', fieldNames, contact.Id);
            Test.stopTest();
    
            System.assertNotEquals(resultMap.get('queriedData'), null, 'Queried data should not be null');        
            Contact resultContact = (Contact)resultMap.get('queriedData');
            System.assertEquals(resultContact.FirstName, 'Test1', 'FirstName should be John');
        } catch (Exception e) {
            ExceptionHandler.logException(new Map<String, Object>{ 'className' => 'WBTemplateControllerTest', 'methodName' => 'testFetchDynamicRecordData', 'exceptionObj' => e, 'isApiException' => false, 'statusCode' => null, 'chatId' => null, 'moreDetails' => e.getMessage(), 'apiResponse' => null });
        }
    }

    @isTest
    static void testTemplateExist() {
        try{
             Boolean exists = WBTemplateController.doesTemplateExist('Template1');
            System.assertEquals(true, exists, 'Template1 should exist');
    
            Boolean notExists = WBTemplateController.doesTemplateExist('NonExistentTemplate');
            System.assertEquals(false, notExists, 'NonExistentTemplate should not exist');
        } catch (Exception e) {
            ExceptionHandler.logException(new Map<String, Object>{ 'className' => 'WBTemplateControllerTest', 'methodName' => 'testTemplateExist', 'exceptionObj' => e, 'isApiException' => false, 'statusCode' => null, 'chatId' => null, 'moreDetails' => e.getMessage(), 'apiResponse' => null });
        }
    }

    @isTest
    static void testGetPicklistValues() {
        try{
             Test.startTest();
            Map<String, List<String>> picklistValues = WBTemplateController.getCategoryAndStatusPicklistValues();
            Test.stopTest();
    
            System.assertNotEquals(picklistValues, null, 'Picklist values should not be null');
            System.assert(picklistValues.containsKey('categories'), 'Picklist should contain "categories" key');
        } catch (Exception e) {
            ExceptionHandler.logException(new Map<String, Object>{ 'className' => 'WBTemplateControllerTest', 'methodName' => 'testGetPicklistValues', 'exceptionObj' => e, 'isApiException' => false, 'statusCode' => null, 'chatId' => null, 'moreDetails' => e.getMessage(), 'apiResponse' => null });
        }
    }

    @isTest
    static void testGetCountryCodesAndLanguages() {
        try{
             Test.startTest();
            List<Map<String, String>> countryValues = WBTemplateController.getCountryCodes();
            List<Map<String, String>> languageValues = WBTemplateController.getLanguages();
            Test.stopTest();
            System.assertNotEquals(null, countryValues, 'Country codes should not be null');
            System.assertNotEquals(null, languageValues, 'Languages should not be null');
        } catch (Exception e) {
            ExceptionHandler.logException(new Map<String, Object>{ 'className' => 'WBTemplateControllerTest', 'methodName' => 'testGetCountryCodesAndLanguages', 'exceptionObj' => e, 'isApiException' => false, 'statusCode' => null, 'chatId' => null, 'moreDetails' => e.getMessage(), 'apiResponse' => null });
        }
    }

    @isTest
    static void testCreateWhatsappTemplate_Success() {
        CreateTemplateWrapper.TemplateWrapper mockTemplateWrapper = new CreateTemplateWrapper.TemplateWrapper();
        mockTemplateWrapper.templateName = 'Test Template';
        mockTemplateWrapper.tempLanguage = 'en';
        String serializedWrapper = JSON.serialize(mockTemplateWrapper);
        Test.startTest();
        Map<String, Object> response = WBTemplateController.createWhatsappTemplate(serializedWrapper);
        test.setMock(HttpCalloutMock.class, new TestHttpResponse(201));
        Test.stopTest();
    }

     @isTest
    static void testCreateTemplateFailed() {
        CreateTemplateWrapper.TemplateWrapper mockTemplateWrapper = new CreateTemplateWrapper.TemplateWrapper();
        mockTemplateWrapper.templateName = 'Invalid Template';
        mockTemplateWrapper.tempLanguage = 'en';

        String serializedWrapper = JSON.serialize(mockTemplateWrapper);

        Test.startTest();
        Map<String, Object> response = WBTemplateController.createWhatsappTemplate(serializedWrapper);
		test.setMock(HttpCalloutMock.class, new TestHttpResponse(404));
        Test.stopTest();
    }

     @isTest
    static void testStartUploadSession_Success() {
        Test.setMock(HttpCalloutMock.class, new TestHttpResponse(200));

        Test.startTest();
        String sessionId = WBTemplateController.startUploadSession('testFile.txt', 1024, 'text/plain');
        Test.stopTest();

    }

    @isTest
    static void testStartUploadSession_Failure() {
        Test.setMock(HttpCalloutMock.class, new TestHttpResponse(400));

        Test.startTest();
        String sessionId = WBTemplateController.startUploadSession('testFile.txt', 1024, 'text/plain');
        Test.stopTest();

        System.assertEquals(sessionId, null, 'The session ID should be null in case of failure');
    }

       @isTest
    static void testUploadFileChunk_Success() {
        String mockResponseBody = '{"h": "header123"}';
        Test.setMock(HttpCalloutMock.class, new TestHttpResponse(200));
      
        WBTemplateController.FileChunkWrapper fileWrapper = new WBTemplateController.FileChunkWrapper();
        fileWrapper.uploadSessionId = 'upload123';
        fileWrapper.fileName = 'testFile.txt';
        fileWrapper.fileContent = EncodingUtil.base64Encode(Blob.valueOf('test content'));
        fileWrapper.chunkStart = 0;
        fileWrapper.chunkSize = 10;

        String serializedWrapper = JSON.serialize(fileWrapper);

        Test.startTest();
        String result = WBTemplateController.uploadFileChunk(serializedWrapper);
        Test.stopTest();
    }
    
     @isTest
    static void testUploadFileChunk_Failure() {
        String mockResponseBody = '{"error": "Invalid file chunk"}';
        Test.setMock(HttpCalloutMock.class, new TestHttpResponse(200));
      
        WBTemplateController.FileChunkWrapper fileWrapper = new WBTemplateController.FileChunkWrapper();
        fileWrapper.uploadSessionId = 'upload123';
        fileWrapper.fileName = 'testFile.txt';
        fileWrapper.fileContent = EncodingUtil.base64Encode(Blob.valueOf('test content'));
        fileWrapper.chunkStart = 0;
        fileWrapper.chunkSize = 10;

        String serializedWrapper = JSON.serialize(fileWrapper);

        Test.startTest();
        String result = WBTemplateController.uploadFileChunk(serializedWrapper);
        Test.stopTest();

        System.assertEquals(result, '', 'The result should be empty in case of failure');
    }
    
      @isTest
    static void testCreateContentVersionAndDocument() {
        Blob fileBlob = Blob.valueOf('test content');

        String fileName = 'testFile.txt';

        Test.startTest();
        String result = WBTemplateController.createContentVersionAndDocument(fileName, fileBlob);
        Test.stopTest();

        System.assert(result.contains('/sfc/servlet.shepherd/version/download/'), 'The result should contain the expected image URL');
    }
     @isTest
    static void testDeleteTemplate_Success() {
		 Template__c template = new Template__c(Name = 'Test Template',Template_Category__c = 'Marketing');
        insert template;

     	Test.setMock(HttpCalloutMock.class, new TestHttpResponse(200));
        Test.startTest();
        String result = WBTemplateController.deleteTemplete(template.Id);
        Test.stopTest();
	}

     public class TestHttpResponse implements HttpCalloutMock {

        Integer statusCode;

        TestHttpResponse(Integer statusCode){
            this.statusCode = statusCode;
        }

        public HTTPResponse respond(HTTPRequest req) {

            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(statusCode);
            return res;
        }
    }
}