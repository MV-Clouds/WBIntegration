public with sharing class WhatsAppFlowController {
    
    @AuraEnabled(cacheable=true)
    public static List<sObject> getWhatsAppFlows() {
        // List<WhatsApp_Flow__c> listName = [SELECT Id, Name, Catagories__c, Flow_ID__c, Flow_Status__c,Flow_Type__c,LastModifiedDate, CreatedDate 
        //                                          FROM WhatsApp_Flow__c WITH SECURITY_ENFORCED ORDER BY LastModifiedDate DESC];
        
        // System.debug('list name==> ' + listName);
        
        return null;
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getJSONData() {
        try {
            // StaticResource resource = [SELECT Body FROM StaticResource WHERE Name = 'WhatsappFlowJson'];
            // String jsonString = resource.Body.toString();
            // Map<String, Object> parsedJson = (Map<String, Object>) JSON.deserializeUntyped(jsonString);

            // List<Object> items = (List<Object>) parsedJson.get('items');
            List<Map<String, Object>> itemsList = new List<Map<String, Object>>();

            // if (items != null) {
            //     for (Object item : items) {
            //         itemsList.add((Map<String, Object>) item);
            //     }
            // }

            return itemsList; // Always return a valid list, even if empty
        } catch (Exception e) {
            System.debug('Error retrieving or parsing JSON: ' + e.getMessage());
            return new List<Map<String, Object>>(); // Return empty list in case of an error
        }
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, List<String>> getStatusPicklistValues() {
        Map<String, List<String>> picklistValues = new Map<String, List<String>>();
        // List<String> statusValues = new List<String>();

        // // Fetch Status__c picklist values
        // Schema.DescribeFieldResult statusFieldResult = WhatsApp_Flow__c.Flow_Status__c.getDescribe();
        // for (Schema.PicklistEntry entry : statusFieldResult.getPicklistValues()) {
        //     statusValues.add(entry.getLabel());
        // }
        // picklistValues.put('statuses', statusValues);

        return picklistValues;
    }

    @AuraEnabled
    public static String createWhatsAppFlow(String flowName, String categories) {
        try {
            String accessToken = '';
            String endpoint = 'https://graph.facebook.com/v20.0/319254377948692/flows';

            List<String> categoryList = (List<String>) JSON.deserialize(categories, List<String>.class);            
            System.debug('Categories received: ' + categoryList);

            HttpRequest request = new HttpRequest();
            request.setEndpoint(endpoint);
            request.setMethod('POST');
            request.setHeader('Authorization', 'Bearer ' + accessToken);
            request.setHeader('Content-Type', 'application/x-www-form-urlencoded');
            
            String categoriesJson = JSON.serialize(categoryList);
            
            String body = 'name=' + EncodingUtil.urlEncode(flowName, 'UTF-8') + 
                        '&categories=' + EncodingUtil.urlEncode(categoriesJson, 'UTF-8');
            request.setBody(body);
            System.debug(body);
            Http http = new Http();
            HttpResponse response = http.send(request);
            
            if (response.getStatusCode() == 200) {
                Map<String, Object> jsonResponse = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
                return 'Flow created successfully with ID: ' + (String) jsonResponse.get('id');
            } else {
                System.debug('Error response: ' + response.getBody());
                return 'Failed to create flow. Status Code: ' + response.getStatusCode() + ', Response: ' + response.getBody();
            }
        } catch (Exception e) {
            System.debug('Exception: ' + e.getMessage());
            return 'An error occurred: ' + e.getMessage();
        }
    }
}