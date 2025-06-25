/**
* @File Name : SendWhatsAppMessageTest.cls
* @Description :
* @Author :
* @Last Modified By :
* @Last Modified On : June 25, 2025
* @Modification Log :
*==============================================================================
* Ver | Date | Author | Modification
*==============================================================================
* 1.0 | June 25, 2025 |  Harsh Gandhi  | Initial Version
**/

@isTest
private class SendWhatsAppMessageTest {

    // Mock response class
    private class MockHttpResponseGenerator implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"messages": [{"id": "wamid.HBgLMj..."}]}');
            res.setStatusCode(200);
            return res;
        }
    }

    @isTest
    static void testSendWAMessage_Success() {
        // Set mock callout
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());

        // Prepare body
        String jsonBody = '{"to":"919999999999","type":"text","text":{"body":"Hello"}}';

        // Call the method
        Test.startTest();
        HttpResponse response = SendWhatsAppMessage.sendWAMessage(jsonBody);
        Test.stopTest();

        // Assertions
        System.assertNotEquals(null, response, 'Response should not be null');
        System.assertEquals(200, response.getStatusCode(), 'Expected status code 200');
        System.assert(response.getBody().contains('wamid'), 'Expected valid response body');
    }
}