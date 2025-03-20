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
            return [SELECT Id, Name, Count_of_Members__c, Description__c FROM Broadcast_Group__c WITH SECURITY_ENFORCED];
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

}