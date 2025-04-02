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
            ExceptionHandler.logException(new Map<String, Object>{'className' => 'BroadcastMessageController','methodName' => 'getObjectConfigs', 'exceptionObj' => e,'isApiException' => false,'statusCode' => null,'chatId' => null,'moreDetails' => e.getMessage(),'apiResponse' => null});
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
            return [SELECT Id, Name, Count_of_Members__c, Description__c, Object_Name__c, Phone_Field__c FROM Broadcast_Group__c WITH SECURITY_ENFORCED ORDER BY LastModifiedDate DESC];
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static void deleteBroadcastGroup(Id groupId) {
        try {
            // Ensure user has delete permission
            if (!Schema.sObjectType.Broadcast_Group__c.isDeletable()) {
                throw new AuraHandledException('Insufficient permissions to delete this record.');
            }
            
            // Query the record with security enforced
            Broadcast_Group__c groupToDelete = [
                SELECT Id FROM Broadcast_Group__c 
                WHERE Id = :groupId 
                WITH SECURITY_ENFORCED 
                LIMIT 1
            ];
            
            if (groupToDelete == null) {
                throw new AuraHandledException('There was a problem deleting the record. ' + groupId);
            }
            
            delete groupToDelete;
        } catch (Exception e) {
            throw new AuraHandledException('An unexpected error occurred: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static List<Broadcast__c> getBroadcastRecs(){
        try {
            return [SELECT Id, Name, Recipient_Count__c, Status__c, Total_Sent__c, Total_Delivered__c, Total_Read__c, Total_Failed__c FROM Broadcast__c WITH SECURITY_ENFORCED];
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
            ExceptionHandler.logException(new Map<String, Object>{'className' => 'BroadcastMessageController','methodName' => 'getTemplatesByObject', 'exceptionObj' => e,'isApiException' => false,'statusCode' => null,'chatId' => null,'moreDetails' => e.getMessage(),'apiResponse' => null});
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
                String.isBlank(request.phoneField) ||
                String.isBlank(request.name)) { 
                throw new AuraHandledException('All fields in the request are required, including the broadcast group name');
            }
    
            Broadcast_Group__c broadcastGroup;
            Boolean isUpdate = request.isUpdate;
            
            if (isUpdate && String.isNotBlank(request.broadcastGroupId)) {
                // Fetch existing Broadcast Group
                broadcastGroup = [SELECT Id, Name, Description__c, Object_Name__c, List_View__c, Phone_Field__c
                                  FROM Broadcast_Group__c 
                                  WHERE Id = :request.broadcastGroupId 
                                  WITH SECURITY_ENFORCED 
                                  LIMIT 1];
    
                // Update existing fields
                broadcastGroup.Name = request.name;
                broadcastGroup.Description__c = request.description;
                broadcastGroup.Object_Name__c = request.objectApiName;
                broadcastGroup.List_View__c = request.listViewName;
                broadcastGroup.Phone_Field__c = request.phoneField;
    
                // Use Database.update with false for partial success
                Database.SaveResult updateResult = Database.update(broadcastGroup, false, AccessLevel.USER_MODE);
                if (!updateResult.isSuccess()) {
                    throw new AuraHandledException('Failed to update broadcast group.');
                }
    
            } else {
                // Create new Broadcast Group
                broadcastGroup = new Broadcast_Group__c();
                broadcastGroup.Name = request.name;
                broadcastGroup.Description__c = request.description;
                broadcastGroup.Object_Name__c = request.objectApiName;
                broadcastGroup.List_View__c = request.listViewName;
                broadcastGroup.Phone_Field__c = request.phoneField;
    
                // Use Database.insert with false for partial success
                Database.SaveResult insertResult = Database.insert(broadcastGroup, false, AccessLevel.USER_MODE);
                if (!insertResult.isSuccess()) {
                    throw new AuraHandledException('Failed to create broadcast group.');
                }
            }
    
            // Fetch existing members if updating
            Map<String, Broadcast_Group_Member__c> existingMembersMap = new Map<String, Broadcast_Group_Member__c>();
            if (isUpdate) {
                for (Broadcast_Group_Member__c member : [SELECT Id, Phone_Number__c FROM Broadcast_Group_Member__c WHERE Broadcast_Group_ID__c = :broadcastGroup.Id WITH SECURITY_ENFORCED ]) {
                    existingMembersMap.put(member.Phone_Number__c, member);
                }
            }
    
            // Prepare new members and track records to delete
            List<Broadcast_Group_Member__c> newMembersToInsert = new List<Broadcast_Group_Member__c>();
            Set<String> receivedPhoneNumbers = new Set<String>(request.phoneNumbers);
            Set<String> existingPhoneNumbers = existingMembersMap.keySet();
            
            // Identify new members to insert
            for (String phoneNumber : receivedPhoneNumbers) {
                if (String.isNotBlank(phoneNumber) && !existingPhoneNumbers.contains(phoneNumber)) {
                    Broadcast_Group_Member__c newMember = new Broadcast_Group_Member__c();
                    newMember.Broadcast_Group_ID__c = broadcastGroup.Id;
                    newMember.Phone_Number__c = phoneNumber;
                    newMembersToInsert.add(newMember);
                }
            }
    
            // Identify members to delete (existing ones not in new list)
            List<Broadcast_Group_Member__c> membersToDelete = new List<Broadcast_Group_Member__c>();
            for (String existingPhone : existingPhoneNumbers) {
                if (!receivedPhoneNumbers.contains(existingPhone)) {
                    membersToDelete.add(existingMembersMap.get(existingPhone));
                }
            }
    
            // Use Database.insert for bulk inserts with false for partial success
            if (!newMembersToInsert.isEmpty()) {
                Database.SaveResult[] insertResults = Database.insert(newMembersToInsert, false, AccessLevel.USER_MODE);
                for (Database.SaveResult result : insertResults) {
                    if (!result.isSuccess()) {
                        throw new AuraHandledException('Error inserting some broadcast group members.');
                    }
                }
            }
    
            // Use Database.delete for bulk deletions with false for partial success
            if (!membersToDelete.isEmpty()) {
                Database.DeleteResult[] deleteResults = Database.delete(membersToDelete, false, AccessLevel.USER_MODE);
                for (Database.DeleteResult result : deleteResults) {
                    if (!result.isSuccess()) {
                        throw new AuraHandledException('Error deleting some broadcast group members.');
                    }
                }
            }
    
        } catch (Exception e) {
            ExceptionHandler.logException(new Map<String, Object>{'className' => 'BroadcastMessageController','methodName' => 'processBroadcastMessageWithObject', 'exceptionObj' => e,'isApiException' => false,'statusCode' => null,'chatId' => null,'moreDetails' => e.getMessage(),'apiResponse' => null});
            throw new AuraHandledException('Error processing broadcast message: ' + e.getMessage());
        }
    }
    

    @AuraEnabled
    public static Map<String, Object> getBroadcastGroupDetails(String groupId) {
        try {
            // Validate input
            if (String.isBlank(groupId)) {
                throw new AuraHandledException('Group ID is required');
            }

            // Fetch Broadcast Group
            Broadcast_Group__c groupRecord = [
                SELECT Id, Name, Description__c, Object_Name__c, List_View__c, Phone_Field__c
                FROM Broadcast_Group__c
                WHERE Id = :groupId
                WITH SECURITY_ENFORCED 
                LIMIT 1
            ];

            // Fetch Group Members
            List<Broadcast_Group_Member__c> groupMembers = [
                SELECT Id, Phone_Number__c, Name
                FROM Broadcast_Group_Member__c
                WHERE Broadcast_Group_ID__c = :groupId
                WITH SECURITY_ENFORCED 
            ];

            // Construct response
            Map<String, Object> response = new Map<String, Object>();
            response.put('group', groupRecord);
            response.put('members', groupMembers);

            return response;
        } catch (Exception e) {
            ExceptionHandler.logException(new Map<String, Object>{'className' => 'BroadcastMessageController','methodName' => 'getBroadcastGroupDetails', 'exceptionObj' => e,'isApiException' => false,'statusCode' => null,'chatId' => null,'moreDetails' => e.getMessage(),'apiResponse' => null});
            throw new AuraHandledException('Error retrieving broadcast group details: ' + e.getMessage());
        }
    } 

    @AuraEnabled
    public static String createChatRecods(String templateId, List<String> groupIds, Boolean isScheduled, String timeOfMessage) {
        try {
            Broadcast__c broadcast = new Broadcast__c();
            broadcast.Template__c = templateId;
            broadcast.Status__c = 'Pending';
            broadcast.Broadcast_Group_IDs__c = String.join(groupIds, ','); // Save all group IDs as a comma-separated string

            String objectApiName = '';
            String phoneField = '';
            List<Chat__c> chatRecs = new List<Chat__c>();

            if (groupIds.size() > 0) {
                List<Broadcast_Group__c> brGroupRecs = [SELECT Id, Name, Object_Name__c, Phone_Field__c FROM Broadcast_Group__c WHERE Id IN :groupIds];
                if (brGroupRecs.size() > 0) {
                    objectApiName = brGroupRecs[0].Object_Name__c;
                    phoneField = brGroupRecs[0].Phone_Field__c;
                }
                System.debug(objectApiName);

                List<Broadcast_Group_Member__c> groupMembers = new List<Broadcast_Group_Member__c>();
                groupMembers = [SELECT Id, Name, Phone_Number__c, Broadcast_Group_ID__c FROM Broadcast_Group_Member__c WHERE Broadcast_Group_ID__c IN :groupIds];
                broadcast.Recipient_Count__c = groupMembers.size();
                insert broadcast; // Insert broadcast after setting all required fields

                System.debug(groupMembers.size());
                List<String> phoneList = new List<String>();
                if (groupMembers.size() > 0) {
                    for (Broadcast_Group_Member__c member : groupMembers) {
                        if (member.Phone_Number__c != null || member.Phone_Number__c != '') {
                            phoneList.add(member.Phone_Number__c);
                            Chat__c newChat = new Chat__c();
                            newChat.Whatsapp_Template__c = templateId;
                            newChat.Phone__c = member.Phone_Number__c;
                            newChat.Type_of_Message__c = 'OutBound Messages';
                            newChat.Message_Status__c = null;
                            newChat.Message_Type__c = 'Template';
                            newChat.WB_Broadcast__c = broadcast.Id;
                            chatRecs.add(newChat);
                        }
                    }
                }

                System.debug(chatRecs.size());
                if (chatRecs.size() > 0) {
                    insert chatRecs;
                }
            }

            if (isScheduled == false) {
                WhatsAppMessageBatch batchJob = new WhatsAppMessageBatch(templateId, chatRecs, broadcast.Id, objectApiName, phoneField);
                Database.executeBatch(batchJob, 1);
            } else {
                timeOfMessage = timeOfMessage.replace('T', ' ').replace('Z', '');

                DateTime utcDateTime = DateTime.valueOf(timeOfMessage);

                // Convert UTC to user's timezone
                TimeZone userTimeZone = UserInfo.getTimeZone();
                DateTime userDateTime = utcDateTime.addSeconds(userTimeZone.getOffset(utcDateTime) / 1000);

                // Validate that the scheduled time is in the future
                if (userDateTime < DateTime.now()) {
                    throw new AuraHandledException('Scheduled time must be in the future.');
                }

                String formattedTime = userDateTime.format('hh:mm a');

                System.debug('formattedTime ==> ' + formattedTime);
                System.debug('userDateTime ==> ' + userDateTime);

                String cronExpression = getCronExpression(userDateTime);

                WhatsAppMessageBatchSchedulable batchSchedular = new WhatsAppMessageBatchSchedulable(templateId, chatRecs, broadcast.Id, objectApiName, phoneField);

                Broadcast__c br = new Broadcast__c(Id = broadcast.Id);
                br.Schedule_DateTime__c = userDateTime;
                update br;

                String jobName = 'BroadcastSchedule_' + System.currentTimeMillis();
                System.schedule(jobName, cronExpression, batchSchedular);
            }
            return 'Success';
        } catch (Exception e) {
            System.debug('Error in sendTemplateMessage: ' + e.getMessage() + '\n' + e + '\n Exception line no: ' + e.getLineNumber());
            throw new AuraHandledException('Error in sendTemplateMessage: ' + e.getMessage());
        }
    }  

    public static String getCronExpression(DateTime dt) {
        String cronExpression = '0 ' + dt.minute() + ' ' + dt.hour() + ' ' + dt.day() + ' ' + dt.month() + ' ' + '?' + ' ' +  dt.year();
        return cronExpression;
    }

    @AuraEnabled
    public static List<Broadcast_Group__c> getBroadcastGroupsByBroadcastId(String broadcastId) {
        try {
            if (String.isBlank(broadcastId)) {
                throw new AuraHandledException('Broadcast ID is required');
            }

            // Fetch the Broadcast record
            Broadcast__c broadcast = [
                SELECT Broadcast_Group_IDs__c 
                FROM Broadcast__c 
                WHERE Id = :broadcastId 
                WITH SECURITY_ENFORCED 
                LIMIT 1
            ];

            if (broadcast.Broadcast_Group_IDs__c == null) {
                return new List<Broadcast_Group__c>();
            }

            // Split the comma-separated group IDs and fetch related groups
            List<String> groupIds = broadcast.Broadcast_Group_IDs__c.split(',');
            return [
                SELECT Id, Name, Count_of_Members__c, Description__c, Object_Name__c, Phone_Field__c
                FROM Broadcast_Group__c 
                WHERE Id IN :groupIds 
                WITH SECURITY_ENFORCED
            ];
        } catch (Exception e) {
            ExceptionHandler.logException(new Map<String, Object>{'className' => 'BroadcastMessageController','methodName' => 'getBroadcastGroupsByBroadcastId', 'exceptionObj' => e,'isApiException' => false,'statusCode' => null,'chatId' => null,'moreDetails' => e.getMessage(),'apiResponse' => null});
            throw new AuraHandledException('Error fetching broadcast groups: ' + e.getMessage());
        }
    }

    // Wrapper class for the broadcast message data
    public class BroadcastMessageRequest {
        @AuraEnabled public String objectApiName { get; set; }
        @AuraEnabled public String listViewName { get; set; }
        @AuraEnabled public List<String> phoneNumbers { get; set; }
        @AuraEnabled public String description { get; set; }
        @AuraEnabled public String name { get; set; } // Added name field
        @AuraEnabled public Boolean isUpdate { get; set; } // Added name field
        @AuraEnabled public String broadcastGroupId { get; set; } // Added name field
        @AuraEnabled public String phoneField { get; set; } // Added name field
    }
}