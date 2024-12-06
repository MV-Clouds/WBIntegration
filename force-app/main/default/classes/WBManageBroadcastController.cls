public with sharing class WBManageBroadcastController {
    @AuraEnabled(cacheable=true)
    public static List<Broadcast_Group__c> getBroadcastGroup() {
        try {
            List<Broadcast_Group__c> listName = [SELECT Id, Name, Count_of_Members__c, Description__c, LastModifiedById,LastModifiedDate, CreatedDate 
            FROM Broadcast_Group__c WITH SECURITY_ENFORCED ORDER BY LastModifiedDate DESC];

            System.debug('list name==> ' + listName);
            return listName;
        } catch (Exception e) {
            ExceptionLog.exception(e.getMessage(), 'WBManageBroadcastController', 'getBroadcastGroup',e.getLineNumber());
            System.debug('Error in getBroadcastGroup: ' + e.getMessage() + '\n' + e + '\n Exception line no: ' + e.getLineNumber());
            return null;
        }
       
    }
}