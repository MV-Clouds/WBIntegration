/**
 * @description       :
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             :
 * @last modified on  : 04-04-2025
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
 **/
public with sharing class ChatGeminiHandler{

    public static List<User_Theme_Preference__c> userPreferences = [SELECT Auto_Response__c FROM User_Theme_Preference__c WITH SECURITY_ENFORCED];
    
    @InvocableMethod(label = 'Generate AI Response and Send WhatsApp'description = 'Calls Gemini API, sends WhatsApp message, and creates a new Chat record.')
    public static void processChat(List<InvocableInput> chats){

        User_Theme_Preference__c userPreference = !userPreferences.isEmpty() ? userPreferences[0] : null;

        if(userPreference.Auto_Response__c){
            
            InvocableInput input = chats.get(0); // Assuming the flow only passes one record at a time.
            String chatId = input.chatId;
            System.debug('chatId:- ' + chatId);
            Chat__c chat = [SELECT Id, Message_Status__c, Message__c, Phone__c
            From Chat__c
            Where id = :chatId];
            if (chat == null){
                System.debug('No record Found');
                return;
            } else{
                System.debug('chat Record:- ' + chat);
            }
            String message = chat.Message__c;
            
            if (String.isBlank(message)){
                return; // No message to process.
            }
            
            try{
                String geminiResponse = callGeminiAPI(message, chat.Phone__c); // Call Gemini API
                
                Chat__c newChat = new Chat__c();
                newChat.Message__c = message;
                newChat.Phone__c = chat.Phone__c;
                newChat.Type_of_Message__c = 'Outbound Messages'; // Assuming outbound message for now
                newChat.Message_Status__c = 'Failed';
                // chat.Message_Type__c = 'Text';
                insert as user newChat;
                
                
                if (String.isNotBlank(geminiResponse)){
                    sendWhatsAppMessage(newChat.Id, geminiResponse); // Send WhatsApp message
                }
                
            } catch (Exception e){
                System.debug('Error processing chat: ' + e.getMessage());
                // Optionally, handle the error (e.g., log it, send an alert).
            }
        }
    }

    private static String callGeminiAPI(String message, String phone){
        // Replace with your actual Gemini API endpoint and authentication details.
        String endpoint = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=AIzaSyBDZiI4CgGbAQ_7i73Hq33jTneh2SyxZtU'; // Example: 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=AIzaSyBDZiI4CgGbAQ_7i73Hq33jTneh2SyxZtU';
        String apiKey = 'AIzaSyBDZiI4CgGbAQ_7i73Hq33jTneh2SyxZtU'; // Replace with your actual API key.
        String model = 'gemini-2.0-flash'; //Replace with your model.
        String projectId = 'YOUR_PROJECT_ID';

        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpoint);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');

        String requestBody = generateRequestBody(message, phone);

        // String requestBody = '{' +
        //     '"contents": [{' +
        //         '"parts": [{"text": "Act as a chat bot Assistant for a Salesforce based company named MV Clouds Pvt Lmt located in Ahmedabad for the given User Prompt also your are directly replying to the user so it should be direct and acurat response not suggestions and all. User Prompt: ' + String.escapeSingleQuotes(message) + '"}]' +
        //         // '"parts": [{"text": "Write a single outbound message response for the following inbound message. Message: ' + String.escapeSingleQuotes(message) + '"}]' +
        //     '}]' +
        // '}';

        req.setBody(requestBody);

        Http http = new Http();
        HttpResponse res = http.send(req);

        if (res.getStatusCode() == 200){
            // Parse the JSON response from Gemini API.
            Map<String, Object> response = (Map<String, Object>)JSON.deserializeUntyped(res.getBody());
            List<Object> candidates = (List<Object>)response.get('candidates');

            if (candidates != null && !candidates.isEmpty()){
                Map<String, Object> candidate = (Map<String, Object>)candidates.get(0);
                List<Object> parts = (List<Object>)((Map<String, Object>)candidate.get('content')).get('parts');
                if (parts != null && !parts.isEmpty()){
                    return String.valueOf(((Map<String, Object>)parts.get(0)).get('text'));
                }
            }

        } else{
            System.debug('Gemini API call failed: ' + res.getStatusCode() + ' - ' + res.getBody());
        }

        return null; // Return null if API call fails or no response is available.
    }

    public static String generateRequestBody(String message, String phone){

        Datetime twentyFourHoursAgo = System.now().addHours(-24);
        List<Chat__c> chatHistory = [SELECT Id, Message__c, Type_of_Message__c
                                     FROM Chat__c
                                     WHERE Phone__c = :phone AND CreatedDate >= :twentyFourHoursAgo
                                     ORDER BY CreatedDate ASC LIMIT 20];
                                     
        String formattedConversation = '';
        boolean isUserTurn = true; // Start with User prompt

        for (Chat__c chat : chatHistory){
            if (chat.Type_of_Message__c.containsIgnoreCase('Inbound Messages')){
                if (isUserTurn){
                    formattedConversation += 'User: ' + chat.Message__c + ', ';
                    isUserTurn = false;
                }
            } else if (chat.Type_of_Message__c.containsIgnoreCase('Outbound Messages')){
                if (!isUserTurn){
                    formattedConversation += 'Assistant: ' + chat.Message__c + ', ';
                    isUserTurn = true;
                }
            }
        }

        // Remove trailing comma and space
        if (formattedConversation.endsWith(', ')){
            formattedConversation = formattedConversation.substring(0, formattedConversation.length() - 2);
        }

        String json = '{' + 
                     '"contents": [{' + 
                     '"parts": [{"text": "Act as a chat bot Assistant for a Salesforce based company named MVClouds Private Limited owned by Dharmik Shah and located in Ahmedabad (Look for more details of MV Clouds over the web and linkedin) for the given User Prompt also your are directly replying to the user so it should be direct and acurat response not suggestions and all. Current User Prompt: ' + String.escapeSingleQuotes(message) + ' , moreever consider the below given sets of previous converations for user and assistant to provide better answer - ' + formattedConversation + ' "}]' + 
                     '}]' + 
                     '}';

        return json;
    }


    @future(callout = true)
    private static void sendWhatsAppMessage(String chatId, String message){

        List<MVWB__WBConnect_Configuration__mdt> wbConfig = MVWB__WBConnect_Configuration__mdt.getAll().values();
        Chat__c chat = [SELECT Id, Message_Status__c, Message__c, Phone__c
                        From Chat__c
                        Where id = :chatId];
        String phoneNumber = chat.Phone__c;
        if (phoneNumber != null && (wbConfig != null || !wbConfig.isEmpty())){

            // String JSON = '{ "messaging_product": "whatsapp", "to": "919428234735", "context":{ "message_id" : "wamid.HBgMOTE5NDI4MjM0NzM1FQIAERgSMEM3QjdBODJGMEMxQTkwRkEyAA=="}, "type": "text", "text": { "body" : "Hello, We hope that you are doing great!. This is a simple text message sent using the WhatsApp Cloud API."} }';// reply to
            // String jsonData = '{ "messaging_product": "whatsapp", "to": "'+ phoneNumber +'",  "type": "text", "text": { "body" : "'+ message +'"} }';
            String jsonData = '';
            HttpRequest httpReq = new HttpRequest();

            // Create a map to hold the JSON structure
            Map<String, Object> messageMap = new Map<String, Object>();
            messageMap.put('messaging_product', 'whatsapp');
            messageMap.put('to', phoneNumber);
            messageMap.put('type', 'text');

            // Create nested map for text
            Map<String, String> textMap = new Map<String, String>();
            textMap.put('body', message);

            messageMap.put('text', textMap);

            // Convert the map to a JSON string
            jsonData = JSON.serialize(messageMap);

            String accessToken = wbConfig[0].MVWB__Access_Token__c;
            String endpoint = 'https://graph.facebook.com/v21.0/' + wbConfig[0].MVWB__Phone_Number_Id__c + '/messages';
            httpReq.setEndpoint(endpoint);
            httpReq.setMethod('POST');
            httpReq.setHeader('Content-Type', 'application/json');
            httpReq.setHeader('Authorization', 'Bearer ' + accessToken);
            httpReq.setBody(jsonData);
            Http http = new Http();
            HttpResponse response = http.send(httpReq);
            Integer statusCode = response.getStatusCode();
            if (response != null && statusCode == 200){
                String responseBody = response.getBody();
                Map<String, Object> jsonMap = (Map<String, Object>)JSON.deserializeUntyped(responseBody);
                List<Object> messages = (List<Object>)jsonMap.get('messages');
                Map<String, Object> firstMessage = (Map<String, Object>)messages[0];
                String whatsAppMessageID = (String) firstMessage.get('id');
                System.debug('WhatsApp Message ID: ' + whatsAppMessageID);
                // Update the chat record
                chat.WhatsAppMessageId__c = whatsAppMessageID;
                chat.Message_Status__c = 'Sent';
            } else{
                System.debug('Error sending WhatsApp Message: ' + response.getBody());
                chat.Message_Status__c = 'Failed';
                ExceptionHandler.logException(new Map<String, Object>{ 'className' => 'ChatGeminiHandler', 'methodName' => 'sendWhatsappMessage', 'exceptionObj' => null, 'isApiException' => true, 'statusCode' => statusCode, 'chatId' => chat.Id, 'moreDetails' => 'API Exception while sending a message', 'apiResponse' => JSON.serialize(response.getBody()) });
            }

            update chat;

        } else{
            System.debug('Contact phone number not found.');
        }
    }

    public class InvocableInput {
        @InvocableVariable(required=true label='Template Id')
        public String chatId;
    }

}