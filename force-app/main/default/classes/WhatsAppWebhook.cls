/**
* @File Name : WhatsAppWebhook.cls
* @Description :
* @Author :
* @Last Modified By : Kajal Tiwari
* @Last Modified On : December 2, 2024
* @Modification Log : Added updateWhatsAppTemplateStatus to get updated status of template and record updated.
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
        if(request.params.get('hub.verify_token') == 'WHATSAPPSCRATCHTOKEN'){
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
        parseMessages(jsonString);
	}

    public static void parseMessages(String jsonString) {
        try {
            Map<String, Object> jsonMap = (Map<String, Object>) JSON.deserializeUntyped(jsonString);
            List<Object> entries = (List<Object>) jsonMap.get('entry');
            
            if (entries != null && !entries.isEmpty()) {
                for (Object entryObj : entries) {
                    Map<String, Object> entry = (Map<String, Object>) entryObj;
                    List<Object> changes = (List<Object>) entry.get('changes');
                    
                    if (changes != null && !changes.isEmpty()) {
                        for (Object changeObj : changes) {
                            Map<String, Object> change = (Map<String, Object>) changeObj;
                            Map<String, Object> value = (Map<String, Object>) change.get('value');

                            if (value.containsKey('event')) {
                                String event = (String) value.get('event');
                                String templateId = String.valueOf(value.get('message_template_id'));
                                updateWhatsAppTemplateStatus(templateId, event);
                            }
                        }
                    }
                }
            }
        } catch (Exception e) {
            ExceptionLog.exception(e.getMessage(), 'WhatsAppWebhook', 'parseMessages',e.getLineNumber());
            System.debug('Error in parseMessages: ' + e.getMessage() + '\n' + e + '\n Exception line no: ' + e.getLineNumber());
        }
    }

     // Used in WhatsappWebhook class to update status field as per webhook response
    // @future (callout=true)
    public static void updateWhatsAppTemplateStatus(String templateId, String event) {
        try {
            List<Template__c> templates = [SELECT Id, Status__c FROM Template__c WHERE Template_Id__c = :templateId LIMIT 1]; // Not include security enforced because it call in webhook and guest user not have permission to edit.
            
            if (!templates.isEmpty()) {
                Template__c wbTemplate = templates[0];
                
                if (event == 'APPROVED') {
                    wbTemplate.Status__c = 'Active-Quality Pending';
                } else if (event == 'PENDING') {
                    wbTemplate.Status__c = 'In-Review';
                } else if (event == 'REJECTED') {
                    wbTemplate.Status__c = 'Rejected';
                }
                
                // if(Template__c.SobjectType.getDescribe().isUpdateable()){
                update wbTemplate;
                // }
               
            } else {
                System.debug('No WhatsApp Template found for Template Id: ' + templateId);
            }
        } catch (Exception e) {
            System.debug('Exception in updateWhatsAppTemplateStatus: ' + e.getMessage());
            ExceptionLog.exception(e.getMessage(), 'WBTemplateController', 'updateWhatsAppTemplateStatus',e.getLineNumber());
        }
    }
}