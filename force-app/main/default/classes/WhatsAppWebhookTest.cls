/**
 * @description       : 
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             : 
 * @last modified on  : 12-16-2024
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
**/
@IsTest
private class WhatsAppWebhookTest {

    @testSetup static void setup() {
        // Create common test contact
        Contact testContact = new Contact(
                LastName = 'Test Contact', 
                Phone = '+919501082174'
            );
        insert testContact;       
    }
    
    @IsTest
    static void testDoGetWithValidToken() {
        // Setup mock HTTP request for GET
        RestRequest req = new RestRequest();
        req.requestURI = '/WBI/webhooks/v1/';
        req.httpMethod = 'GET';
        req.addParameter('hub.verify_token', 'WHATSAPPTOKEN');
        req.addParameter('hub.challenge', '319254377948692');
        RestContext.request = req;
        RestContext.response = new RestResponse();

        // Execute the GET method
        WhatsAppWebhook.doGet();

        // Assert the response contains the expected challenge
        System.assertEquals('319254377948692', RestContext.response.responseBody.toString(), 'Expected the challenge to be returned.');
    }

    @IsTest
    static void testDoPostWithValidToken() {
        // Setup mock HTTP request for POST
        RestRequest req = new RestRequest();
        req.requestURI = '/WBI/webhooks/v1/';
        req.httpMethod = 'POST';
        req.addHeader('hub.verify_token', '7fa1634d4f849b8ced3a249ec4ce8bb7db4d8046');
        req.requestBody = Blob.valueOf('{"object":"whatsapp_business_account","entry":[{"id":"319254377948692","changes":[{"value":{"messaging_product":"whatsapp","metadata":{"display_phone_number":"919558019600","phone_number_id":"397858113402150"},"contacts":[{"profile":{"name":"Kevin Suvagiya"},"wa_id":"919428234735"}],"messages":[{"context":{"from":"919558019600","id":"wamid.HBgMOTE5NDI4MjM0NzM1FQIAERgSRjAwQzUxODZDQTcwQTIxREQwAA=="},"from":"919428234735","id":"wamid.HBgMOTE5NDI4MjM0NzM1FQIAEhggQkYwODA3RkY0RDJGMDg1REFENzU0OEM5MUEzMUFDMTUA","timestamp":"1734343632","type":"button","button":{"payload":"OPT-OUT","text":"OPT-OUT"}}]},"field":"messages"}]}]}');
        RestContext.request = req;
        RestContext.response = new RestResponse();

        // Execute the POST method
        WhatsAppWebhook.doPost();

    }

    @IsTest
    static void testDoPostWithInvalidToken() {
        // Setup mock HTTP request for POST with invalid token
        RestRequest req = new RestRequest();
        req.requestURI = '/WBI/webhooks/v1/';
        req.httpMethod = 'POST';
        req.addHeader('hub.verify_token', 'INVALIDTOKEN');
        req.requestBody = Blob.valueOf('{"object":"whatsapp_business_account","entry":[{"id":"319254377948692","changes":[{"value":{"messaging_product":"whatsapp","metadata":{"display_phone_number":"919558019600","phone_number_id":"397858113402150"},"contacts":[{"profile":{"name":"Kevin Suvagiya"},"wa_id":"919428234735"}],"messages":[{"from":"919428234735","id":"wamid.HBgMOTE5NDI4MjM0NzM1FQIAEhggRDNCQzM4RjNDMkEwNzJDMUVBQkFGREZGOUFDRkZGN0EA","timestamp":"1734009524","text":{"body":"Reply to first one"},"type":"text"}]},"field":"messages"}]}]}');
        RestContext.request = req;
        RestContext.response = new RestResponse();

        // Execute the POST method
        WhatsAppWebhook.doPost();

        // Assert the response status code is 403
        System.assertEquals(403, RestContext.response.statusCode, 'Expected status code 403 for invalid token.');
    }

    @IsTest
    static void testProcessWhatsAppPayload() {
        String jsonPayload = '{"object":"whatsapp_business_account","entry":[{"id":"319254377948692","changes":[{"value":{"messaging_product":"whatsapp","metadata":{"display_phone_number":"919558019600","phone_number_id":"397858113402150"},"contacts":[{"profile":{"name":"Kevin Suvagiya"},"wa_id":"919428234735"}],"messages":[{"from":"919428234735","id":"wamid.HBgMOTE5NDI4MjM0NzM1FQIAEhggRDNCQzM4RjNDMkEwNzJDMUVBQkFGREZGOUFDRkZGN0EA","timestamp":"1734009524","text":{"body":"Reply to first one"},"type":"text"}]},"field":"messages"}]}]}';
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new WhatsAppHttpMock());
        WhatsAppWebhook.processWhatsAppPayload(jsonPayload);
        Test.stopTest();
        System.assertEquals('397858113402150', WhatsAppWebhook.phoneNumberId, 'Expected phone number ID to be set.');
    }

    @IsTest
    static void testProcessWhatsAppPayload2() {
        String videojsonPayload = '{"object":"whatsapp_business_account","entry":[{"id":"319254377948692","changes":[{"value":{"messaging_product":"whatsapp","metadata":{"display_phone_number":"919558019600","phone_number_id":"397858113402150"},"contacts":[{"profile":{"name":"Kevin Suvagiya"},"wa_id":"919428234735"}],"messages":[{"from":"919428234735","id":"wamid.HBgMOTE5NDI4MjM0NzM1FQIAEhggNDE0MjFDQjJDOUZGNEIzMjI5RDc1NDlEODU5RUE5QzEA","timestamp":"1734343457","type":"video","video":{"mime_type":"video/mp4","sha256":"T1dLSnJNE3t4mnzLZWSjBWCe61sptppyhF/K//Brx4U=","id":"3827582537491666"}}]},"field":"messages"}]}]}';
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new WhatsAppHttpMock());
        WhatsAppWebhook.processWhatsAppPayload(videojsonPayload);
        Test.stopTest();
        System.assertEquals('397858113402150', WhatsAppWebhook.phoneNumberId, 'Expected phone number ID to be set.');
    }

    @IsTest
    static void testProcessWhatsAppPayload3() {
        String audiojsonPayload = '{"object":"whatsapp_business_account","entry":[{"id":"319254377948692","changes":[{"value":{"messaging_product":"whatsapp","metadata":{"display_phone_number":"919558019600","phone_number_id":"397858113402150"},"contacts":[{"profile":{"name":"Kevin Suvagiya"},"wa_id":"919428234735"}],"messages":[{"from":"919428234735","id":"wamid.HBgMOTE5NDI4MjM0NzM1FQIAEhggNDE0MjFDQjJDOUZGNEIzMjI5RDc1NDlEODU5RUE5QzEA","timestamp":"1734343457","type":"audio","audio":{"mime_type":"audio/mp3","sha256":"T1dLSnJNE3t4mnzLZWSjBWCe61sptppyhF/K//Brx4U=","id":"3827582537491666"}}]},"field":"messages"}]}]}';
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new WhatsAppHttpMock());
        WhatsAppWebhook.processWhatsAppPayload(audiojsonPayload);
        Test.stopTest();
        System.assertEquals('397858113402150', WhatsAppWebhook.phoneNumberId, 'Expected phone number ID to be set.');
    }

    @IsTest
    static void testProcessWhatsAppPayload4() {
        String imagejsonPayload = '{"object":"whatsapp_business_account","entry":[{"id":"319254377948692","changes":[{"value":{"messaging_product":"whatsapp","metadata":{"display_phone_number":"919558019600","phone_number_id":"397858113402150"},"contacts":[{"profile":{"name":"Kevin Suvagiya"},"wa_id":"919428234735"}],"messages":[{"from":"919428234735","id":"wamid.HBgMOTE5NDI4MjM0NzM1FQIAEhggNDE0MjFDQjJDOUZGNEIzMjI5RDc1NDlEODU5RUE5QzEA","timestamp":"1734343457","type":"image","image":{"mime_type":"image/png","sha256":"T1dLSnJNE3t4mnzLZWSjBWCe61sptppyhF/K//Brx4U=","id":"3827582537491666"}}]},"field":"messages"}]}]}';
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new WhatsAppHttpMock());
        WhatsAppWebhook.processWhatsAppPayload(imagejsonPayload);
        Test.stopTest();
        System.assertEquals('397858113402150', WhatsAppWebhook.phoneNumberId, 'Expected phone number ID to be set.');
    }

    @IsTest
    static void testProcessWhatsAppPayload5() {
        String documentjsonPayload = '{"object":"whatsapp_business_account","entry":[{"id":"319254377948692","changes":[{"value":{"messaging_product":"whatsapp","metadata":{"display_phone_number":"919558019600","phone_number_id":"397858113402150"},"contacts":[{"profile":{"name":"Kevin Suvagiya"},"wa_id":"919428234735"}],"messages":[{"from":"919428234735","id":"wamid.HBgMOTE5NDI4MjM0NzM1FQIAEhggNDE0MjFDQjJDOUZGNEIzMjI5RDc1NDlEODU5RUE5QzEA","timestamp":"1734343457","type":"document","document":{"mime_type":"document/pdf","sha256":"T1dLSnJNE3t4mnzLZWSjBWCe61sptppyhF/K//Brx4U=","id":"3827582537491666"}}]},"field":"messages"}]}]}';
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new WhatsAppHttpMock());
        WhatsAppWebhook.processWhatsAppPayload(documentjsonPayload);
        Test.stopTest();
        System.assertEquals('397858113402150', WhatsAppWebhook.phoneNumberId, 'Expected phone number ID to be set.');
    }

    @IsTest
    static void testHandleMediaAttachment() {
        String documentId = '3827582537491666';
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new WhatsAppHttpMock());
        WhatsAppWebhook.handleMediaAttachment(documentId);
        Test.stopTest();
    }
    
    @IsTest
    static void testSaveMediaToSalesforce() {
        String documentId = '3827582537491666';
        Contact testcontact = [SELECT Id from Contact LIMIT 1];
        Test.startTest();
        WhatsAppWebhook.saveMediaToSalesforce(Blob.valueOf('mock-binary-data'), 'filename', 'filetype', testcontact.Id);
        Test.stopTest();
    }
}