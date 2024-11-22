/**
* @File Name : WhatsAppWebhook.cls
* @Description :
* @Author :
* @Last Modified By :
* @Last Modified On : November 18, 2024
* @Modification Log :
*==============================================================================
* Ver | Date | Author | Modification
*==============================================================================
* 1.0 | November 18, 2024 |   | Initial Version
**/

@RestResource(urlMapping='/WBI/webhooks/v1/*')
global without sharing class WhatsAppWebhook {

    public static String currentTime = System.now().format('yyyy-MM-dd HH:mm:ss');
    public static String phoneNumberId = '';
    public static List<Object> messages = new List<Object>();    

    @HttpGet // GET
    global static void doGet() {
        RestResponse response = RestContext.response;
        System.debug('Response ==>' + response);
        RestRequest request = RestContext.request;
        System.debug('request ==>' + request);
        if(request.params.get('hub.verify_token') == 'WHATSAPPTOKEN'){
            response.responseBody = Blob.valueOf( request.params.get('hub.challenge') );
        }
    }

    @HttpPost
    global static void doPost() {
        System.debug('InDoPost Method'+RestContext.request.headers.get('hub.verify_token'));
        System.debug('InDoPost Method2 '+RestContext.request.params.get('hub.verify_token'));
            // Verify Token (Replace with your Verify Token)
        String verifyToken = '7fa1634d4f849b8ced3a249ec4ce8bb7db4d8046';
        if (RestContext.request.headers.get('hub.verify_token') != verifyToken) {
            System.debug('InDoPost Method If condition');
            RestContext.response.statusCode = 403;
        }
        // Get WhatsApp's raw JSON data
        System.debug('InDoPost Method before Payload');
        String jsonString = RestContext.request.requestBody.toString();
        System.debug('InDoPost Method after payload:- '+jsonString);
        try {
            processWhatsAppPayload(jsonString);
        } catch (Exception e) {
            // ErrorHandler.insert_errordata(e, 'WhatsAppWebhook', 'doPost', e.getMessage());
            System.debug('Error processing WhatsApp payload: ' + e.getMessage());
        }
    }

	private static void processWhatsAppPayload(String jsonString){
		System.debug('jsonString: ' + jsonString);
	}
}