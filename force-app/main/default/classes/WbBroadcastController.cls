/**
* @File Name : WbBroadcastController.cls
* @Description : This class involves functionality related to Broadcasting.
* @Author : Kajal Tiwari
* @Last Modified By :
* @Last Modified On : Decemeber 5, 2024
* @Modification Log :
*==============================================================================
* Ver | Date | Author | Modification
*==============================================================================
* 1.0 | Decemeber 4, 2024 |   | Initial Version
**/

public with sharing class WbBroadcastController {

    // Fetch Brodcast Group record to show in the Home Screen.
    @AuraEnabled(cacheable=true)
    public static List<Broadcast_Group__c> getBroadcastGroup() {
        try {
            List<Broadcast_Group__c> listName = [SELECT Id, Name, Count_of_Members__c, Description__c, LastModifiedById,LastModifiedDate, CreatedDate 
            FROM Broadcast_Group__c WITH SECURITY_ENFORCED ORDER BY LastModifiedDate DESC];

            System.debug('list name==> ' + listName);
            return listName;
        } catch (Exception e) {
            ExceptionLog.exception(e.getMessage(), 'WbBroadcastController', 'getBroadcastGroup',e.getLineNumber());
            System.debug('Error in getBroadcastGroup: ' + e.getMessage() + '\n' + e + '\n Exception line no: ' + e.getLineNumber());
            return null;
        }
    }

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

    @AuraEnabled
    public static void updateBroadcastGroup(String bgGroupId, String bgName, String bgDescription, List<Id> contactIds) {
        try {
            // Step 1: Update the Broadcast Group record
            Broadcast_Group__c broadcastGroup = [SELECT Id, Name, Description__c FROM Broadcast_Group__c WHERE Id = :bgGroupId WITH SECURITY_ENFORCED LIMIT 1];
            broadcastGroup.Name = bgName;
            broadcastGroup.Description__c = bgDescription;

            if (Broadcast_Group__c.sObjectType.getDescribe().isUpdateable()) {
                update broadcastGroup;
            }
            
            // Step 2: Delete all existing members of the Broadcast Group
            List<Broadcast_Group_Member__c> existingMembers = [
                SELECT Id 
                FROM Broadcast_Group_Member__c 
                WHERE Broadcast_Group_ID__c = :bgGroupId WITH SECURITY_ENFORCED 
            ];
            if (!existingMembers.isEmpty() && Broadcast_Group_Member__c.sObjectType.getDescribe().isDeletable()) {
                delete existingMembers;
            }
    
            // Step 3: Insert new members
            List<Broadcast_Group_Member__c> newMembers = new List<Broadcast_Group_Member__c>();
            for (Id contactId : contactIds) {
                newMembers.add(new Broadcast_Group_Member__c(
                    Broadcast_Group_ID__c = bgGroupId,
                    Contact_ID__c = contactId
                ));
            }
            if (!newMembers.isEmpty() && Broadcast_Group_Member__c.sObjectType.getDescribe().isCreateable()) {
                insert newMembers;
            }
        } catch (Exception e) {
            System.debug('Error updating broadcast group: ' + e.getMessage());
            ExceptionLog.exception(e.getMessage(), 'WbBroadcastController', 'updateBroadcastGroup', e.getLineNumber());
        }
    }
    

}