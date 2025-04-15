public with sharing class MarketingMessageController {
    @AuraEnabled
    public static void createMarketingCampaign(String campaignData) {
        try {
            // Deserialize the JSON string into a Map
            Map<String, Object> dataMap = (Map<String, Object>) JSON.deserializeUntyped(campaignData);
            System.debug('dataMap: ' + dataMap);
            
            // Extract basic fields
            String name = (String) dataMap.get('name');
            String description = (String) dataMap.get('description');
            String objectName = (String) dataMap.get('objectName');
            Boolean isMarketingCampaign = (Boolean) dataMap.get('isMarketingCampaign');
            String selectedOption = (String) dataMap.get('selectedOption');
            String selectedDate = (String) dataMap.get('selectedDate');
            String selectedDateFields = (String) dataMap.get('selectedDateFields');
            // List<String> groupId = (List<String>) dataMap.get('groupIdList');
            List<Object> rawGroupList = (List<Object>) dataMap.get('groupIdList');
            List<String> groupId = new List<String>();

            for (Object obj : rawGroupList) {
                Map<String, Object> groupMap = (Map<String, Object>) obj;
                groupId.add((String) groupMap.get('Id'));
            }
            // ✅ Fix: safely cast each item in the list to a Map
            List<Object> rawEmailConfigs = (List<Object>) dataMap.get('emailConfigs');
            List<Map<String, Object>> emailConfigs = new List<Map<String, Object>>();
            
            for (Object rawItem : rawEmailConfigs) {
                emailConfigs.add((Map<String, Object>) rawItem);
            }
            
            Map<String, SObject> phoneToObjectMapList;
            if(selectedOption == 'related') {
                // selectedDate = selectedDateFields;
                phoneToObjectMapList  = getObjectDetails(objectName, selectedDateFields);
            }else {
                phoneToObjectMapList = new Map<String, SObject>();
            }

            System.debug('name: ' + name);
            System.debug('description: ' + description);
            System.debug('objectName: ' + objectName);
            System.debug('isMarketingCampaign: ' + isMarketingCampaign);
            System.debug('selectedOption: ' + selectedOption);
            System.debug('selectedDate: ' + selectedDate);
            System.debug('selectedDateFields: ' + selectedDateFields);
            System.debug('emailConfigs: ' + emailConfigs);
            System.debug('groupId: ' + groupId);
            System.debug('phoneToObjectMapList: ' + phoneToObjectMapList);
            System.debug('rawGroupList: ' + String.join(groupId, ','));


            // Create a new Marketing Campaign record
            WB_Marketing_campaign__c campaign = new WB_Marketing_campaign__c(
                Name = name,
                Marketing_Campaign_Description__c = description,
                Object_Name__c = objectName,
                hasExistingMarketingCampaign__c = isMarketingCampaign,
                Group_Id_List__c = String.join(groupId, ',')
            );

            // Insert the Marketing Campaign record
            Database.insert(campaign, false, AccessLevel.USER_MODE);

           
            List<WB_Marketing_campaign_group__c> campaignGroups = new List<WB_Marketing_campaign_group__c>();

            if (emailConfigs != null && !emailConfigs.isEmpty()) {
                for (Map<String, Object> emailConfig : emailConfigs) {
                    // String templateId = (String) emailConfig.get('template');
                    // String daysAfter = (String) emailConfig.get('daysAfter');
                    // String timeToSend = (String) emailConfig.get('timeToSend');
                    String templateId = String.valueOf(emailConfig.get('template'));
                    String daysAfter = String.valueOf(emailConfig.get('daysAfter'));
                    String timeToSend = String.valueOf(emailConfig.get('timeToSend'));
                    String isSendImmediately = String.valueOf(emailConfig.get('isImmediateSelected'));
            
                    // Validate Days_After__c
                    Integer daysAfterValue = null;
                    if (daysAfter != null) {
                        try {
                            System.debug('daysAfter: ' + daysAfter);
                            daysAfterValue = Integer.valueOf(daysAfter) ;
                        } catch (Exception e) {
                            System.debug(e.getLineNumber());
                            throw new AuraHandledException('Invalid value for Days_After__c: ' + daysAfter);
                        }
                    }
            
                    // Validate Time_To_Send__c
                     Time timeToSendValue = null;
                     if (timeToSend != null && String.valueOf(timeToSend).trim() != '') {
                         try {
                            System.debug('timeToSend: ' + timeToSend);

                            // Split the time string (assuming format is "HH:mm:ss")
                            List<String> timeParts = timeToSend.split(':');

                            Integer hours = Integer.valueOf(timeParts[0]);
                            Integer minutes = Integer.valueOf(timeParts[1]);
                            Integer seconds = Integer.valueOf(timeParts[2]);

                            // Create a Time instance
                            timeToSendValue = Time.newInstance(hours, minutes, seconds, 0);

                            System.debug('timeToSendValue: ' + timeToSendValue);

                         } catch (Exception e) {
                             throw new AuraHandledException('Invalid value for Time_To_Send__c: ' + timeToSend);
                         }
                     }
                     System.debug('Time to send ::: ' + timeToSendValue);
                    
                    // Create a new Marketing Campaign Group record
                    WB_Marketing_campaign_group__c campaignGroup = new WB_Marketing_campaign_group__c(
                        WB_Marketing_campaign__c = campaign.Id,
                        WB_Template__c = templateId,
                        Status__c = 'Pending',
                        Days_After__c = daysAfterValue,
                        Time_To_Send__c = timeToSendValue,
                        Is_Send_immediately__c = isSendImmediately == 'true',
                        Specific_Date__c = (selectedOption == 'specific' && selectedDate != null) ? Date.valueOf(selectedDate) : null,
                        Relate_Date_Field__c = (selectedOption == 'related' && selectedDateFields != null) ? selectedDateFields : null
                    );
                    campaignGroups.add(campaignGroup);
                }
            }
            System.debug('campaignGroups: ' + campaignGroups);

            // Insert the Marketing Campaign Group records
            if (!campaignGroups.isEmpty()) {
                // insert campaignGroups;
                Database.insert(campaignGroups, false, AccessLevel.USER_MODE);

            }

            for (WB_Marketing_campaign_group__c campaignGroupsVariable : campaignGroups) {
                Integer daysAfterValue = (campaignGroupsVariable.Days_After__c != null) ? Integer.valueOf(campaignGroupsVariable.Days_After__c) : null;
                Time timeToSendValue = campaignGroupsVariable.Time_To_Send__c; // Assuming Time_To_Send__c is the correct field for time
            
                String createChatRecord = createChatRecodsMarketing(
                    campaignGroupsVariable.WB_Template__c,
                    groupId,
                    selectedDate,
                    campaign.Id,
                    campaignGroupsVariable.Id,
                    phoneToObjectMapList,
                    selectedDateFields,
                    selectedOption,
                    daysAfterValue,
                    timeToSendValue,
                    campaignGroupsVariable.Is_Send_immediately__c
                );
                System.debug('createChatRecord: ' + createChatRecord);
            }

            // Return the ID of the newly created Marketing Campaign
            // return campaign.Id;
        } catch (Exception e) {
            // Handle any exceptions and throw a user-friendly error
            System.debug(e.getLineNumber());
            throw new AuraHandledException('Error creating Marketing Campaign: ' + e.getMessage());
        }
    }
    @AuraEnabled
    public static void updateMarketingCampaign(String campaignData) {
        try {
            // Deserialize the JSON string into a Map
            Map<String, Object> dataMap = (Map<String, Object>) JSON.deserializeUntyped(campaignData);
            System.debug('dataMap: ' + dataMap);
    
            // Extract basic fields
            String campaignId = (String) dataMap.get('id'); // Campaign ID for update
            String name = (String) dataMap.get('name');
            String description = (String) dataMap.get('description');
            String objectName = (String) dataMap.get('objectName');
            Boolean isMarketingCampaign = (Boolean) dataMap.get('isMarketingCampaign');
            String selectedOption = (String) dataMap.get('selectedOption');
            String selectedDate = (String) dataMap.get('selectedDate');
            String selectedDateFields = (String) dataMap.get('selectedDateFields');
            System.debug('selectedDateFields: ' + selectedDateFields);
            System.debug('selectedDate : '+ selectedDate);
            System.debug('selectedoption : '+selectedOption);
            System.debug('objectName : '+objectName);
    
            // Extract and process groupIdList
            List<Object> rawGroupList = (List<Object>) dataMap.get('groupIdList');
            List<String> groupId = new List<String>();
            for (Object obj : rawGroupList) {
                groupId.add((String) obj); // Each obj is just a string ID
            }
            String groupIdCommaSeparated = String.join(groupId, ',');
            System.debug('Comma-separated Group IDs: ' + groupIdCommaSeparated);
    
            // Extract email configurations
            List<Object> rawEmailConfigs = (List<Object>) dataMap.get('emailConfigs');
            List<Map<String, Object>> emailConfigs = new List<Map<String, Object>>();
            for (Object rawItem : rawEmailConfigs) {
                emailConfigs.add((Map<String, Object>) rawItem);
            }
            System.debug('Campaign Idd :: '+campaignId);
            // Fetch the existing campaign record
            WB_Marketing_campaign__c campaign = [
                SELECT Id, Name, Marketing_Campaign_Description__c, Object_Name__c, 
                       hasExistingMarketingCampaign__c, Group_Id_List__c
                FROM WB_Marketing_campaign__c
                WHERE Id = :campaignId
                LIMIT 1
            ];
    
            // Update the campaign fields
            campaign.Name = name;
            campaign.Marketing_Campaign_Description__c = description;
            campaign.Object_Name__c = objectName;
            campaign.hasExistingMarketingCampaign__c = isMarketingCampaign;
            campaign.Group_Id_List__c = groupIdCommaSeparated;
    
            // Update the campaign record
            update campaign;
            System.debug('Updated Campaign: ' + campaign);
    
            // Fetch existing campaign groups
            Map<Id, WB_Marketing_campaign_group__c> existingGroupsMap = new Map<Id, WB_Marketing_campaign_group__c>(
                [SELECT Id, WB_Template__c, Days_After__c, Time_To_Send__c, Is_Send_Immediately__c, 
                        Specific_Date__c, Relate_Date_Field__c 
                 FROM WB_Marketing_campaign_group__c 
                 WHERE WB_Marketing_campaign__c =:campaignId]
            );
                        
            
            Map<String, SObject> phoneToObjectMapList;
            if(selectedOption == 'related') {
                phoneToObjectMapList  = getObjectDetails(objectName, selectedDateFields);
            }else {
                phoneToObjectMapList = new Map<String, SObject>();
            }

            System.debug('phoneToObjectMapList11: ' + phoneToObjectMapList);
    
            // Prepare lists for insert, update, and delete
            List<WB_Marketing_campaign_group__c> groupsToInsert = new List<WB_Marketing_campaign_group__c>();
            List<WB_Marketing_campaign_group__c> groupsToUpdate = new List<WB_Marketing_campaign_group__c>();
            Set<Id> updatedGroupIds = new Set<Id>();
    
            // Process email configurations
            for (Map<String, Object> emailConfig : emailConfigs) {
                String groupIdValue = String.valueOf(emailConfig.get('groupId')); // Check if group exists
                String templateId = String.valueOf(emailConfig.get('template'));
                String daysAfter = String.valueOf(emailConfig.get('daysAfter'));
                String timeToSend = String.valueOf(emailConfig.get('timeToSend'));
                String isSendImmediately = String.valueOf(emailConfig.get('isImmediateSelected'));
    
                // Validate Days_After__c
                Integer daysAfterValue = null;
                if (daysAfter != null) {
                    try {
                        daysAfterValue = Integer.valueOf(daysAfter);
                    } catch (Exception e) {
                        throw new AuraHandledException('Invalid value for Days_After__c: ' + daysAfter);
                    }
                }
    
                // Validate Time_To_Send__c
                Time timeToSendValue = null;
                if (timeToSend != null && String.valueOf(timeToSend).trim() != '') {
                        System.debug('timeToSend: ' + timeToSend);
                        List<String> timeParts = timeToSend.split(':');
                        System.debug('timeParts: ' + timeParts);
                        Integer hours = Integer.valueOf(timeParts[0]);
                        Integer minutes = Integer.valueOf(timeParts[1]);
                        Integer seconds = Integer.valueOf(timeParts[2]);
                        System.debug('Second ::: '+seconds);
                        timeToSendValue = Time.newInstance(hours, minutes, seconds, 0);
                        System.debug('Time to send1 ::: ' + timeToSendValue);
                    
                }
                System.debug('Time to send ::: ' + timeToSendValue);
    
                // Check if the group exists
                if (groupIdValue != null && existingGroupsMap.containsKey(groupIdValue)) {
                    WB_Marketing_campaign_group__c existingGroup = existingGroupsMap.get(groupIdValue);
                    existingGroup.WB_Template__c = templateId;
                    existingGroup.Days_After__c = daysAfterValue;
                    existingGroup.Time_To_Send__c = timeToSendValue;
                    existingGroup.Is_Send_immediately__c = isSendImmediately == 'true';
                    existingGroup.Specific_Date__c = (selectedOption == 'specific' && selectedDate != null) ? Date.valueOf(selectedDate) : null;
                    existingGroup.Relate_Date_Field__c = (selectedOption == 'related' && selectedDateFields != null) ? selectedDateFields : null;
                    groupsToUpdate.add(existingGroup);
                    updatedGroupIds.add(existingGroup.Id);
                } else {
                    // Create a new group
                    WB_Marketing_campaign_group__c newGroup = new WB_Marketing_campaign_group__c(
                        WB_Marketing_campaign__c = campaign.Id,
                        WB_Template__c = templateId,
                        Status__c = 'Pending',
                        Days_After__c = daysAfterValue,
                        Time_To_Send__c = timeToSendValue,
                        Is_Send_immediately__c = isSendImmediately == 'true',
                        Specific_Date__c = (selectedOption == 'specific' && selectedDate != null) ? Date.valueOf(selectedDate) : null,
                        Relate_Date_Field__c = (selectedOption == 'related' && selectedDateFields != null) ? selectedDateFields : null
                    );
                    groupsToInsert.add(newGroup);
                }
            }
    
            // Identify groups to delete
            List<WB_Marketing_campaign_group__c> groupsToDelete = new List<WB_Marketing_campaign_group__c>();
            for (Id existingGroupId : existingGroupsMap.keySet()) {
                if (!updatedGroupIds.contains(existingGroupId)) {
                    groupsToDelete.add(existingGroupsMap.get(existingGroupId));
                }
            }
            // Perform DML operations
            if (!groupsToInsert.isEmpty()) {
                insert groupsToInsert;
                System.debug('Inserted Campaign Groups: ' + groupsToInsert);
                
                for (WB_Marketing_campaign_group__c groupRecord : groupsToInsert) {
                    String selectedOption1 = groupRecord.Relate_Date_Field__c != null ? 'related' :'specific';
                    createChatRecodsMarketing(
                        groupRecord.WB_Template__c,
                        groupId,
                        selectedDate,
                        campaign.Id,
                        groupRecord.Id,
                        phoneToObjectMapList, // Pass phoneToObjectMapList if needed
                        selectedDateFields,
                        selectedOption1,
                        Integer.valueOf(groupRecord.Days_After__c),
                        groupRecord.Time_To_Send__c,
                        groupRecord.Is_Send_immediately__c
                    );
                }

            }
            if (!groupsToUpdate.isEmpty()) {
                update groupsToUpdate;
                System.debug('Updated Campaign Groups: ' + groupsToUpdate);
                
            for (WB_Marketing_campaign_group__c groupRecord : groupsToUpdate) {
                System.debug(groupRecord);
                String selectedOption1 = groupRecord.Relate_Date_Field__c != null ? 'related' :'specific';

                updateChatRecordsMarketing(
                    groupRecord.WB_Template__c,
                    groupId,
                    selectedDate,
                    campaignId,
                    groupRecord.Id,
                    phoneToObjectMapList, // Pass phoneToObjectMapList if needed
                    selectedDateFields,
                    selectedOption1,
                    Integer.valueOf(groupRecord.Days_After__c),
                    groupRecord.Time_To_Send__c,
                    groupRecord.Is_Send_immediately__c
                );
            
            }
            }
            if (!groupsToDelete.isEmpty()) {
                delete groupsToDelete;
                System.debug('Deleted Campaign Groups: ' + groupsToDelete);
            }

        } catch (Exception e) {
            // Handle any exceptions and throw a user-friendly error
            System.debug(e.getLineNumber());
            System.debug('Error in updateMarketingCampaign: ' + e.getMessage());    
            throw new AuraHandledException('Error updating Marketing Campaign: ' + e.getMessage());
        }
    }
        /*
    *********************************************************
    @description     : Create chat records and run batch class to send it at that time or schedule batch job if needed
    @param           : groupId - Id of the Broadcast_Group__c record
    @return          : String indicating success or failure
    ********************************************************
    */
    @AuraEnabled
    public static String createChatRecodsMarketing(String templateId, List<String> groupIds, String dateFieldValue,String campaignId, String campaignGroupId,Map<String, SObject> phoneToObjectMapList,String selectedDateFields,String selectedOption,Integer dayAfter , Time timeToSend,Boolean isSendImmediate) {
        try {
           
            String objectApiName = '';
            String phoneField = '';
            List<Chat__c> chatRecs = new List<Chat__c>();
            List<WB_Marketing_campaign_member__c> marketingCampaignMembers = new List<WB_Marketing_campaign_member__c>();

            if (groupIds.size() > 0) {
                List<Broadcast_Group__c> brGroupRecs = [SELECT Id, Name, Object_Name__c FROM Broadcast_Group__c WHERE Id IN :groupIds];
                if (brGroupRecs.size() > 0) {
                    objectApiName = brGroupRecs[0].Object_Name__c;
                }

                List<Broadcast_Group_Member__c> groupMembers = new List<Broadcast_Group_Member__c>();
                groupMembers = [SELECT Id, Name, Phone_Number__c, Broadcast_Group_ID__c FROM Broadcast_Group_Member__c WHERE Broadcast_Group_ID__c IN :groupIds WITH SECURITY_ENFORCED];
                System.debug('groupMembers: ' + groupMembers);
                // broadcast.Recipient_Count__c = groupMembers.size();
                // Database.insert(broadcast, false, AccessLevel.USER_MODE);

                // List<String> phoneList = new List<String>();
                if (groupMembers.size() > 0) {
                    for (Broadcast_Group_Member__c member : groupMembers) {
                        DateTime dateValue;
                        if (selectedOption == 'related' && phoneToObjectMapList.containsKey(member.Phone_Number__c)) {
                            dateValue = (DateTime) phoneToObjectMapList.get(member.Phone_Number__c).get(selectedDateFields);
                            System.debug('Date Value :::  '+dateValue);
                        } else {
                            // Date dateFieldValue = ;
                            // dateValue = (DateTime) DateTime.newInstance(dateFieldValue, Time.newInstance(0, 0, 0, 0));
                            Date dateFieldValueStr = Date.valueOf(dateFieldValue); // convert to Date
                            dateValue = DateTime.newInstance(dateFieldValueStr, Time.newInstance(0, 0, 0, 0));
                            // dateValue = DateTime.valueOf(dateFieldValue);
                        }

                        if (dateValue != null) {
                            // Step 1: Add days
                            dateValue = dateValue.addDays(dayAfter != null ? dayAfter : 0);
                        
                            if (timeToSend != null || isSendImmediate == true) {
                                // Step 2: Apply user timezone
                                // TimeZone userTimeZone = UserInfo.getTimeZone();
                                System.debug(timeToSend);
                                // Combine date (after adding days) with the new time
                                // DateTime combinedDateTime = DateTime.newInstance(dateValue.date(), timeToSend);
                                DateTime combinedDateTime;
                                System.debug('isSendImmediate: ' + isSendImmediate);
                                if (isSendImmediate == true) {
                                        // Add 1 minute to the current date and time
                                        combinedDateTime = DateTime.now().addMinutes(1);
                                        System.debug('Combined DateTime for immediate send: ' + combinedDateTime);
                                    } else {
                                        // Combine date (after adding days) with the new time
                                        combinedDateTime = DateTime.newInstance(dateValue.date(), timeToSend);
                                    }
                                // Step 3: Adjust to user's timezone offset
                                // Integer offsetInSeconds = userTimeZone.getOffset(combinedDateTime) / 1000;
                                // System.debug('Offset in seconds: ' + offsetInSeconds);
                                // dateValue = combinedDateTime.addSeconds(offsetInSeconds);
                                dateValue = combinedDateTime;
                            }
                        }

                        System.debug('Updated DateTime: ' + dateValue);

                        if (member.Phone_Number__c != null || member.Phone_Number__c != '') {
                            // phoneList.add(member.Phone_Number__c);
                            Chat__c newChat = new Chat__c();
                            newChat.Whatsapp_Template__c = templateId;
                            newChat.Phone__c = member.Phone_Number__c;
                            newChat.Type_of_Message__c = 'OutBound Messages';
                            newChat.Message_Status__c = null;
                            newChat.Message_Type__c = 'Template';
                            chatRecs.add(newChat);

                            WB_Marketing_campaign_member__c campaignMember = new WB_Marketing_campaign_member__c();
                            campaignMember.Member_Phone__c = member.Phone_Number__c;
                            campaignMember.Name = member.Name;
                            campaignMember.Member_Name__c = member.Name;
                            campaignMember.Schedule_Date__c = dateValue;
                            campaignMember.WB_Marketing_campaign__c = campaignId;
                            campaignMember.WB_Marketing_campaign_group__c = campaignGroupId;
                            campaignMember.Chat_Record_Id__c = null;
                            campaignMember.Status__c = 'Pending';
                            marketingCampaignMembers.add(campaignMember);

                        }
                    }
                }
                System.debug('Marketing Campaign Member ::: '+ marketingCampaignMembers);
                System.debug('Chat Records ::: '+ chatRecs);
                if (chatRecs.size() > 0) {
                    Database.SaveResult[] results = Database.insert(chatRecs, false, AccessLevel.USER_MODE);
                    System.debug('results: ' + results);
                    // Database.insert(marketingCampaignMembers, false, AccessLevel.USER_MODE);
                    
                }
                 // Map Chat__c records to Campaign Members
                for (Integer i = 0; i < chatRecs.size(); i++) {
                    System.debug(chatRecs[i].Id);
                    marketingCampaignMembers[i].Chat_Record_Id__c = chatRecs[i].Id; // Assuming Chat_Record_Id__c is the field to store Chat__c ID
                }
                System.debug('Marketing Campaign Member ::: '+ marketingCampaignMembers);

                // Insert Campaign Members
                if (marketingCampaignMembers.size() > 0) {
                    Database.insert(marketingCampaignMembers, false, AccessLevel.USER_MODE);
                }
            }

            return 'Success';
        } catch (Exception e) {
            System.debug(e.getLineNumber());
            System.debug(e.getMessage());
            ExceptionHandler.logException(new Map<String, Object>{'className' => 'BroadcastMessageController','methodName' => 'createChatRecods', 'exceptionObj' => e,'isApiException' => false,'statusCode' => null,'chatId' => null,'moreDetails' => e.getMessage(),'apiResponse' => null});
            throw new AuraHandledException('Error in sendTemplateMessage: ' + e.getMessage());
        }
    }  

    @AuraEnabled
    public static void updateChatRecordsMarketing(String templateId, List<String> groupIds, String dateFieldValue, String campaignId, String campaignGroupId, Map<String, SObject> phoneToObjectMapList, String selectedDateFields, String selectedOption, Integer dayAfter, Time timeToSend, Boolean isSendImmediate) {
        try {
            System.debug('In Update REcod');
            String objectApiName = '';
            String phoneField = '';
            Set<Chat__c> chatRecsToUpdate = new Set<Chat__c>();
            Set<WB_Marketing_campaign_member__c> marketingMembersToUpdate = new Set<WB_Marketing_campaign_member__c>();

            System.debug('group Id ::: '+groupIds);
            if (groupIds.size() > 0) {
                // Fetch broadcast group details
                List<Broadcast_Group__c> brGroupRecs = [SELECT Id, Name, Object_Name__c FROM Broadcast_Group__c WHERE Id IN :groupIds];
                if (brGroupRecs.size() > 0) {
                    objectApiName = brGroupRecs[0].Object_Name__c;
                }
            System.debug('Brodcast re ::: '+brGroupRecs);


                // Fetch group members
                List<Broadcast_Group_Member__c> groupMembers = [SELECT Id, Name, Phone_Number__c, Broadcast_Group_ID__c FROM Broadcast_Group_Member__c WHERE Broadcast_Group_ID__c IN :groupIds WITH SECURITY_ENFORCED];
                System.debug('groupMembers: ' + groupMembers);

                if (groupMembers.size() > 0) {
                    for (Broadcast_Group_Member__c member : groupMembers) {
                        DateTime dateValue;
                        // System.debug()

                        System.debug('Phone Object ::: '+phoneToObjectMapList.containsKey(member.Phone_Number__c));
                        if (selectedOption == 'related' && member.Phone_Number__c !=null) {
                            dateValue = (DateTime) phoneToObjectMapList.get(member.Phone_Number__c).get(selectedDateFields);
                            System.debug('Date Value ::: ' + dateValue);
                        } else {
                            Date dateFieldValueStr = Date.valueOf(dateFieldValue); // Convert to Date
                            dateValue = DateTime.newInstance(dateFieldValueStr, Time.newInstance(0, 0, 0, 0));
                        }

                        // Add dayAfter and timeToSend to the DateTime
                        if (dateValue != null) {
                            dateValue = dateValue.addDays(dayAfter != null ? dayAfter : 0);

                            if (timeToSend != null || isSendImmediate == true) {
                                DateTime combinedDateTime;
                                if (isSendImmediate == true) {
                                    combinedDateTime = DateTime.now().addMinutes(1);
                                    System.debug('Combined DateTime for immediate send: ' + combinedDateTime);
                                } else {
                                    combinedDateTime = DateTime.newInstance(dateValue.date(), timeToSend);
                                }
                                dateValue = combinedDateTime;
                            }
                        }

                        System.debug('Updated DateTime: ' + dateValue);

                        if (member.Phone_Number__c != null && member.Phone_Number__c != '') {
                            // Fetch existing chat record
                            List<Chat__c> existingChats = [SELECT Id, Whatsapp_Template__c, Phone__c FROM Chat__c WHERE Phone__c = :member.Phone_Number__c AND Whatsapp_Template__c = :templateId LIMIT 1];
                            if (!existingChats.isEmpty()) {
                                Chat__c existingChat = existingChats[0];
                                existingChat.Whatsapp_Template__c = templateId;
                                chatRecsToUpdate.add(existingChat);
                            }

                            // Fetch existing marketing campaign member
                            List<WB_Marketing_campaign_member__c> existingMembers = [SELECT Id, Member_Phone__c, Schedule_Date__c FROM WB_Marketing_campaign_member__c WHERE Member_Phone__c = :member.Phone_Number__c AND WB_Marketing_campaign_group__c = :campaignGroupId LIMIT 1];
                            if (!existingMembers.isEmpty()) {
                                WB_Marketing_campaign_member__c existingMember = existingMembers[0];
                                existingMember.Schedule_Date__c = dateValue;
                                existingMember.Status__c = 'Pending';
                                marketingMembersToUpdate.add(existingMember);
                            }
                        }
                    }
                }
            }

            // Perform DML operations
            if (!chatRecsToUpdate.isEmpty()) {
                List<Chat__c> chatRecsToUpdateList = new List<Chat__c>(chatRecsToUpdate);
                update chatRecsToUpdateList;
                System.debug('Updated Chat Records: ' + chatRecsToUpdateList);
            }

            if (!marketingMembersToUpdate.isEmpty()) {
                List<WB_Marketing_campaign_member__c> marketingMembersToUpdateList = new List<WB_Marketing_campaign_member__c>(marketingMembersToUpdate);
                update marketingMembersToUpdateList;
                System.debug('Updated Marketing Campaign Members: ' + marketingMembersToUpdateList);
            }

            // return 'Success';
        } catch (Exception e) {
            System.debug(e.getLineNumber());
            System.debug(e.getMessage());
            ExceptionHandler.logException(new Map<String, Object>{'className' => 'MarketingMessageController','methodName' => 'updateChatRecordsMarketing','exceptionObj' => e,'isApiException' => false,'statusCode' => null,'chatId' => null,'moreDetails' => e.getMessage(),'apiResponse' => null});
            throw new AuraHandledException('Error in updateChatRecordsMarketing: ' + e.getMessage());
        }
    }

    /*
    *********************************************************
    @description     : Generate a cron expression based on the provided DateTime
    @param           : dt - DateTime object
    @return          : String representing the cron expression
    ********************************************************
    */

    public static Map<String, SObject> getObjectDetails(String objectName, String fieldName) {
        try {
            // Check if the object and field exist
            List<MVWB__Object_Config__mdt> objectConfigList = [SELECT Id, MVWB__ObjectConfigInfo__c, MVWB__ChatWindowConfigInfo__c FROM MVWB__Object_Config__mdt LIMIT 1];
            Map<String, Object> chatConfigData = (Map<String, Object>) JSON.deserializeUntyped(objectConfigList[0].MVWB__ChatWindowConfigInfo__c);Map<String, Object> chatConfig = (Map<String, Object>) chatConfigData.get(objectName);
            String phoneField = (String) chatConfig.get('phoneField');
            // if (!Schema.getGlobalDescribe().containsKey(objectName)) {
            //     throw new AuraHandledException('Object ' + objectName + ' does not exist.');
            // }
    
            // Map<String, Schema.SObjectField> fieldMap = Schema.getGlobalDescribe().get(objectName).getDescribe().fields.getMap();
            // if (!fieldMap.containsKey(fieldName)) {
            //     throw new AuraHandledException('Field ' + fieldName + ' does not exist on object ' + objectName + '.');
            // }
    
            // Build the dynamic SOQL query
            System.debug('Query ::: '+'SELECT Id,'+phoneField+' ' + fieldName + ' FROM ' + objectName);
            String query = 'SELECT Id,'+phoneField+',' + fieldName + ' FROM ' + objectName;
    
            List<SObject> getObjectList = Database.query(query);
            Map<String, SObject> phoneToObjectMap = new Map<String, SObject>();

            for (SObject objectValue : getObjectList) {
                // Assuming the phone field is named 'Phone'
                String phone = (String) objectValue.get(phoneField);
                if (phone != null && phone != '') {
                    phoneToObjectMap.put(phone, objectValue);
                }
            }

            return phoneToObjectMap;


        } catch (Exception e) {
            System.debug(e.getLineNumber());
            System.debug(e.getMessage());
            throw new AuraHandledException('Error fetching records: ' + e.getMessage());
        }
    }

    @InvocableMethod
    public static List<InvocableResult> getScheduleMessage(List<InvocableInput> inputMemberIdList) {
        List<InvocableResult> results = new List<InvocableResult>();

        try {
            System.debug('In Invocable Method');
            System.debug('memberIds: ' + inputMemberIdList);

            // Ensure the input list is not empty
            if (inputMemberIdList == null || inputMemberIdList.isEmpty()) {
                throw new AuraHandledException('No memberId provided.');
            }

            // Process each input memberId
            for (InvocableInput input : inputMemberIdList) {
                // Query the Marketing Campaign Member record
                WB_Marketing_campaign_member__c member = [
                    SELECT Id, Member_Name__c, Member_Phone__c, Schedule_Date__c, 
                           WB_Marketing_Campaign_Group__r.WB_Template__c, 
                           WB_Marketing_Campaign_Group__r.Days_After__c, 
                           WB_Marketing_Campaign_Group__r.Time_To_Send__c, 
                           WB_Marketing_Campaign_Group__r.Is_Send_immediately__c, 
                           WB_Marketing_Campaign__r.Name, 
                           WB_Marketing_Campaign__r.Marketing_Campaign_Description__c,
                           WB_Marketing_Campaign__r.Object_Name__c,
                           Status__c
                    FROM WB_Marketing_campaign_member__c
                    WHERE Id = :input.memberId
                    LIMIT 1 
                ];

                System.debug('member: ' + member);
                // Validate if the member has a phone number
                if (String.isBlank(member.Member_Phone__c)) {
                    throw new AuraHandledException('Member does not have a phone number.');
                }

                // Query the Chat__c record associated with the member's phone number
                List<Chat__c> chatList = [
                    SELECT Id, Phone__c
                    FROM Chat__c
                    WHERE Phone__c = :member.Member_Phone__c
                    LIMIT 1
                ];

                if (!chatList.isEmpty()) {
                    Chat__c chat = chatList[0];
                    String phone = chat.Phone__c;

                    // Build the dynamic query for the related object
                    List<MVWB__Object_Config__mdt> objectConfigList = [
                        SELECT Id, MVWB__ObjectConfigInfo__c, MVWB__ChatWindowConfigInfo__c 
                        FROM MVWB__Object_Config__mdt 
                        LIMIT 1
                    ];

                    Map<String, Object> chatConfigData = (Map<String, Object>) JSON.deserializeUntyped(objectConfigList[0].MVWB__ChatWindowConfigInfo__c);
                    Map<String, Object> chatConfig = (Map<String, Object>) chatConfigData.get(member.WB_Marketing_Campaign__r.Object_Name__c);
                    String phoneField = (String) chatConfig.get('phoneField');

                    String query = 'SELECT Id, ' + phoneField + ' FROM ' + member.WB_Marketing_Campaign__r.Object_Name__c + 
                                   ' WHERE ' + phoneField + ' = :phone LIMIT 1';

                    // Execute the query
                    List<SObject> records = Database.query(query);

                    if (!records.isEmpty()) {
                        // Call getTemplateData with the required parameters
                        Map<String, Object> tempData = WhatsAppMessageBatch.getTemplateData(
                            member.WB_Marketing_Campaign_Group__r.WB_Template__c,
                            phone,
                            member.WB_Marketing_Campaign__r.Object_Name__c
                        );

                        System.debug('tempData: ' + tempData);

                        // Generate the payload and send the WhatsApp message
                        String jsonData = WhatsAppMessageBatch.generatePayloadFromTemplateData(tempData, chat.Phone__c);
                        List<Chat__c> sentChats = WhatsAppMessageBatch.sendWhatsAppMessage(chat.Id, jsonData);

                        System.debug('sentChats: ' + sentChats);
                        System.debug('Chat ID: ' + chat.Id);
                        System.debug('jsonData: ' + jsonData);

                        if (!sentChats.isEmpty()) {
                            System.debug('Sent Chat');
                            // Update the chat record if the message was sent successfully
                            List<Chat__c> chatsToUpdate = new List<Chat__c>();
                            chatsToUpdate.add(sentChats[0]);
                            update chatsToUpdate;
                            member.Status__c = 'Completed';
                            update member;
                            // System.debug(Database.update(member, false, AccessLevel.USER_MODE));
                            // Add success result
                            InvocableResult result = new InvocableResult();
                            result.res = 'Success';
                            results.add(result);
                        }
                    }
                } else {
                    System.debug('Fail el1');
                    throw new AuraHandledException('No Chat__c record found for the given phone number.');
                }
            }
        } catch (Exception e) {
            System.debug('Error in getScheduleMessage: ' + e.getMessage());
            ExceptionHandler.logException(new Map<String, Object>{'className' => 'WhatsAppMessageBatch','methodName' => 'getScheduleMessage','exceptionObj' => e,'isApiException' => false,'statusCode' => null,'chatId' => null,'moreDetails' => e.getMessage(),'apiResponse' => null
            });

            // Add failure result
            InvocableResult result = new InvocableResult();
            result.res = 'Error: ' + e.getMessage();
            results.add(result);

            throw new AuraHandledException('Error in getScheduleMessage: ' + e.getMessage());
        }

        return results;
    }

    public class InvocableInput {
        @InvocableVariable(required=true label='memberId')
        public String memberId;
    }

    public class InvocableResult {
        @InvocableVariable(label='Message')
        public String res;
    }

    @AuraEnabled
    public static String deleteMarketingCampaign(Id campaignId) {
        try {
            // Query the campaign to ensure it exists
            WB_Marketing_campaign__c campaign = [SELECT Id FROM WB_Marketing_campaign__c WHERE Id = :campaignId LIMIT 1];
            
            delete campaign;
            return 'Success';
        } catch (Exception e) {
            return 'Error: ' + e.getMessage();
        }
    }


    @AuraEnabled
    public static String getCampaignDetails(String campaignId) {
        try {
            // Fetch the marketing campaign details
            WB_Marketing_campaign__c campaign = [
                SELECT Id, Name, Marketing_Campaign_Description__c, Object_Name__c, 
                    Start_Date__c, End_Date__c, hasExistingMarketingCampaign__c, 
                    Group_Id_List__c
                FROM WB_Marketing_campaign__c
                WHERE Id = :campaignId
                LIMIT 1
            ];


            // Fetch associated email configuration records
            List<WB_Marketing_campaign_group__c> emailConfigs = [
                SELECT Id, WB_Template__c, Days_After__c, Time_To_Send__c, 
                    Is_Send_Immediately__c, Relate_Date_Field__c, Specific_Date__c, Status__c
                FROM WB_Marketing_campaign_group__c
                WHERE WB_Marketing_campaign__c = :campaignId
            ];

            // Prepare the response data in a map
            Map<String, Object> response = new Map<String, Object>();
            List<Broadcast_Group__c	> broadcastGroup = new List<Broadcast_Group__c	>();
            System.debug('group Id List ::: '+campaign.Group_Id_List__c);
            if (String.isNotBlank(campaign.Group_Id_List__c)) {
                List<String> groupIds = campaign.Group_Id_List__c.split(',');
                broadcastGroup = [SELECT Id, Name FROM Broadcast_Group__c WHERE Id IN :groupIds];
            }
            System.debug('broadcastGroup: ' + broadcastGroup);

            // Convert the list of names into a comma-separated string
            List<String> groupNames = new List<String>();
            for (Broadcast_Group__c member : broadcastGroup) {
                groupNames.add(member.Name);
            }
            String groupNamesCommaSeparated = String.join(groupNames, ',');

            // Debugging
            System.debug('Comma-separated Group Names: ' + groupNamesCommaSeparated);

            // Add data to the response map
            response.put('groupNames', groupNamesCommaSeparated);
            // response.put('groupNa', groupNamesCommaSeparated);
            
            response.put('campaign', campaign);
            response.put('emailConfigs', emailConfigs);
            
            if (!emailConfigs.isEmpty()) {
                response.put('selectedDate', emailConfigs[0].Specific_Date__c);
                response.put('selectedDateFields', emailConfigs[0].Relate_Date_Field__c);
                response.put('selectedOption', emailConfigs[0].Relate_Date_Field__c != null ? 'related' : 'specific');
            }

            // Serialize the map to a JSON string and return it
            return JSON.serialize(response);

        } catch (Exception e) {
            throw new AuraHandledException('Error fetching campaign details: ' + e.getMessage());
        }
    }


    @AuraEnabled
    public static List<WB_Marketing_campaign__c> getCampaignRecs() {
        return [SELECT Id, Name, Marketing_campaign_Description__c, Start_Date__c, End_Date__c, Status__c FROM WB_Marketing_campaign__c];
    }

}