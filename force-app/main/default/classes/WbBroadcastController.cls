public with sharing class WbBroadcastController {
    // Fetch records based on the object name and map fields
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getRecordsBySObject(String sObjectName) {
        // String sObjectName = 'Contact';
        List<Map<String, String>> records = new List<Map<String, String>>();

        try {
            String query = 'SELECT Id, Name, Phone FROM ' + sObjectName + ' WHERE Phone != null LIMIT 100';
            List<sObject> queryResults = Database.query(query);            

            for (sObject record : queryResults) {
                records.add(new Map<String, String>{ 'label' => (String)record.get('Name'), 'value' => (String)record.get('Id'),'phone' => (String)record.get('Phone') });
            }

            System.debug('Fetched records: ' + records);
        } catch (Exception e) {
            System.debug('Error fetching records: ' + e.getMessage());
            ExceptionLog.exception(e.getMessage(), 'WbBroadcastController', 'getRecordsBySObject', e.getLineNumber());
        }

        return records;
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getMembersWithContactData(Id broadcastGroupId) {
        try {
            Broadcast_Group__c broadcastGroup = [SELECT Id, Name, Description__c 
                                                 FROM Broadcast_Group__c 
                                                 WHERE Id = :broadcastGroupId WITH SECURITY_ENFORCED LIMIT 1];
            
            List<Broadcast_Group_Member__c> members = [
                SELECT Id, Name, Contact_ID__c, Contact_ID__r.Name, Contact_ID__r.Phone 
                FROM Broadcast_Group_Member__c
                WHERE Broadcast_Group_ID__c = :broadcastGroupId WITH SECURITY_ENFORCED
            ];
            
            Map<String, Object> result = new Map<String, Object>();
            result.put('broadcastGroupName', broadcastGroup.Name);
            result.put('broadcastGroupDescription', broadcastGroup.Description__c);
            result.put('members', members);
            
            return result;
        } catch (Exception e) {
            ExceptionLog.exception(e.getMessage(), 'WbBroadcastController', 'getMembersWithContactData', e.getLineNumber());
            return null;
        }
    }

    @AuraEnabled
    public static void createBroadcastGroup(String bgName, String bgDescription, List<Id> contactIds){
        try {
            Broadcast_Group__c bgGroup = new Broadcast_Group__c(
                Name = bgName,
                Description__c = bgDescription
            );

            if (Broadcast_Group__c.sObjectType.getDescribe().isCreateable()) {
                insert bgGroup;
            }
            
            List<Broadcast_Group_Member__c> bgMembers = new List<Broadcast_Group_Member__c>();
            if (bgGroup.Id != null) {
                for (Id contactId : contactIds) {
                    bgMembers.add(new Broadcast_Group_Member__c(
                        Broadcast_Group_ID__c = bgGroup.Id, 
                        Contact_ID__c = contactId
                    ));
                }
    
                if (!bgMembers.isEmpty() && Broadcast_Group_Member__c.sObjectType.getDescribe().isCreateable()) {
                    insert bgMembers;
                }
            }
            
        } catch (Exception e) {
            System.debug('Error fetching records: ' + e.getMessage());
            ExceptionLog.exception(e.getMessage(), 'WbBroadcastController', 'createBroadcastGroup', e.getLineNumber());
        }
    }
   
}