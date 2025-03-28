public with sharing class BroadcastMessageController {

    @AuraEnabled
    public static Map<String, Object> getObjectConfigs() {
        try {
            Map<String, Object> result = new Map<String, Object>();
            List<Object_Config__mdt> objectConfigList = [
                SELECT ChatWindowConfigInfo__c 
                FROM Object_Config__mdt WITH SECURITY_ENFORCED LIMIT 1
            ];
    
            if (objectConfigList.isEmpty()) {
                throw new AuraHandledException('Object Config not found!');
            }
    
            Map<String, Object> chatConfigData = (Map<String, Object>) JSON.deserializeUntyped(objectConfigList[0].ChatWindowConfigInfo__c);
            
            // Prepare return structure: { objectOptions: [...], configMap: {...} }
            List<Map<String, String>> objectOptions = new List<Map<String, String>>();
            Map<String, Map<String, String>> configMap = new Map<String, Map<String, String>>();
    
            for (String objectApiName : chatConfigData.keySet()) {
                objectOptions.add(new Map<String, String> {
                    'label' => objectApiName,
                    'value' => objectApiName
                });
                Map<String, Object> config = (Map<String, Object>) chatConfigData.get(objectApiName);
                configMap.put(objectApiName, new Map<String, String>{
                    'nameField' => (String) config.get('nameField'),
                    'phoneField' => (String) config.get('phoneField')
                });
            }
    
            result.put('objectOptions', objectOptions);
            result.put('configMap', configMap);
    
            return result;
    
        } catch (Exception e) {
            ExceptionHandler.logException(new Map<String, Object>{
                'className' => 'BroadcastMessageController',
                'methodName' => 'getObjectConfigs',
                'exceptionObj' => e,
                'isApiException' => false,
                'statusCode' => null,
                'chatId' => null,
                'moreDetails' => e.getMessage(),
                'apiResponse' => null
            });
            throw new AuraHandledException('Error fetching object configs: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static List<ListView> getListViewsForObject(String objectApiName) {
        try {
            return [SELECT Id, Name FROM ListView WHERE SobjectType = :objectApiName WITH SECURITY_ENFORCED ORDER BY LastViewedDate DESC];
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching list views: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static List<Broadcast_Group__c> getBroadcastGroups(){
        try {
            return [SELECT Id, Name, Count_of_Members__c, Description__c, Object_Name__c FROM Broadcast_Group__c WITH SECURITY_ENFORCED ORDER BY LastModifiedDate DESC];
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static List<Broadcast__c> getBroadcastRecs(){
        try {
            return [SELECT Id, Name, Broadcast_Group__r.Name, Recipient_Count__c, Status__c, Total_Sent__c, Total_Delivered__c, Total_Read__c, Failed__c FROM Broadcast__c WITH SECURITY_ENFORCED];
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static Map<String, List<Template__c>> getTemplatesByObject() {
        Map<String, List<Template__c>> objectTemplateMap = new Map<String, List<Template__c>>();
    
        try {
            // Fetch all templates with their related object names from Template_Variable__c
            List<Template__c> templates = [SELECT Id, Template_Name__c, 
                                                  (SELECT Object_Name__c FROM WB_Template_Variables__r) 
                                           FROM Template__c 
                                           WHERE Status__c = 'Active-Quality Pending'
                                           WITH SECURITY_ENFORCED 
                                           ORDER BY LastModifiedDate DESC];
    
            // Categorize templates by object name
            for (Template__c template : templates) {
                String objectName;
    
                // If the template has associated object names, use the first one; otherwise, categorize it as 'Generic'
                if (!template.WB_Template_Variables__r.isEmpty()) {
                    objectName = template.WB_Template_Variables__r[0].Object_Name__c;
                } else {
                    objectName = 'Generic'; // Templates without variables are categorized as 'Generic'
                }
    
                // Initialize list if objectName is not yet added
                if (!objectTemplateMap.containsKey(objectName)) {
                    objectTemplateMap.put(objectName, new List<Template__c>());
                }
    
                // Add template to the appropriate object name
                objectTemplateMap.get(objectName).add(template);
            }
    
        } catch (Exception e) {
            ExceptionHandler.logException(new Map<String, Object>{
                'className' => 'BroadcastMessageController',
                'methodName' => 'getTemplatesByObject',
                'exceptionObj' => e,
                'isApiException' => false,
                'statusCode' => null,
                'chatId' => null,
                'moreDetails' => e.getMessage(),
                'apiResponse' => null
            });
        }
    
        return objectTemplateMap;
    }    

    @AuraEnabled
    public static void processBroadcastMessageWithObject(BroadcastMessageRequest request) {
        try {
            // Validate the request object
            if (request == null || 
                String.isBlank(request.objectApiName) || 
                request.phoneNumbers == null || request.phoneNumbers.isEmpty() || 
                String.isBlank(request.description) || 
                String.isBlank(request.templateId) || 
                String.isBlank(request.name)) { // Added validation for name
                throw new AuraHandledException('All fields in the request are required, including the broadcast group name');
            }

            // Create the master Broadcast_Group__c record
            Broadcast_Group__c broadcastGroup = new Broadcast_Group__c();
            broadcastGroup.Name = request.name; 
            broadcastGroup.Description__c = request.description;
            broadcastGroup.Object_Name__c = request.objectApiName;
            broadcastGroup.List_View__c = request.listViewName;

            // Insert the master record with security enforcement
            Database.insert(broadcastGroup, false, AccessLevel.USER_MODE);

            // Prepare child Broadcast_Group_Member__c records
            List<Broadcast_Group_Member__c> groupMembersToInsert = new List<Broadcast_Group_Member__c>();
            
            for (String phoneNumber : request.phoneNumbers) {
                if (String.isNotBlank(phoneNumber)) {
                    Broadcast_Group_Member__c member = new Broadcast_Group_Member__c();
                    member.Broadcast_Group_ID__c = broadcastGroup.Id; // Link to master record
                    member.Phone_Number__c = phoneNumber; 
                    
                    groupMembersToInsert.add(member);
                }
            }

            // Insert child records with security enforcement
            if (!groupMembersToInsert.isEmpty()) {
                Database.insert(groupMembersToInsert, false, AccessLevel.USER_MODE);
            }

        } catch (Exception e) {
            ExceptionHandler.logException(new Map<String, Object>{
                'className' => 'BroadcastMessageController',
                'methodName' => 'processBroadcastMessageWithObject',
                'exceptionObj' => e,
                'isApiException' => false,
                'statusCode' => null,
                'chatId' => null,
                'moreDetails' => e.getMessage(),
                'apiResponse' => null
            });
            throw new AuraHandledException('Error processing broadcast message: ' + e.getMessage());
        }
    }

    // Wrapper class for the broadcast message data
    public class BroadcastMessageRequest {
        @AuraEnabled public String objectApiName { get; set; }
        @AuraEnabled public String listViewName { get; set; }
        @AuraEnabled public List<String> phoneNumbers { get; set; }
        @AuraEnabled public String description { get; set; }
        @AuraEnabled public String templateId { get; set; }
        @AuraEnabled public String name { get; set; } // Added name field
    }


}