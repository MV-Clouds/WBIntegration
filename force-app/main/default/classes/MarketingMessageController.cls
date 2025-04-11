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


            // Create a new Marketing Campaign record
            WB_Marketing_Campaign__c campaign = new WB_Marketing_Campaign__c(
                Name = name,
                Marketing_Campaign_Description__c = description,
                Object_Name__c = objectName,
                hasExistingMarketingCampaign__c = isMarketingCampaign
            );

            // Insert the Marketing Campaign record
            Database.insert(campaign, false, AccessLevel.USER_MODE);

           
            List<WB_Marketing_Campaign_Group__c> campaignGroups = new List<WB_Marketing_Campaign_Group__c>();

            if (emailConfigs != null && !emailConfigs.isEmpty()) {
                for (Map<String, Object> emailConfig : emailConfigs) {
                    // String templateId = (String) emailConfig.get('template');
                    // String daysAfter = (String) emailConfig.get('daysAfter');
                    // String timeToSend = (String) emailConfig.get('timeToSend');
                    String templateId = String.valueOf(emailConfig.get('template'));
                    String daysAfter = String.valueOf(emailConfig.get('daysAfter'));
                    String timeToSend = String.valueOf(emailConfig.get('timeToSend'));
            
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
                             // Split the time string into components
                            //  List<String> timeParts = String.valueOf(timeToSend).split(':');
                            //  Integer hours = Integer.valueOf(timeParts[0]);
                            //  Integer minutes = Integer.valueOf(timeParts[1]);
                            //  Integer seconds = Integer.valueOf(timeParts[2].split('\\.')[0]); // Handle milliseconds if present
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
                    WB_Marketing_Campaign_Group__c campaignGroup = new WB_Marketing_Campaign_Group__c(
                        WB_Marketing_Campaign__c = campaign.Id,
                        WB_Template__c = templateId,
                        Status__c = 'Pending',
                        Days_After__c = daysAfterValue,
                        Time_To_Send__c = timeToSendValue
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

            for (WB_Marketing_Campaign_Group__c campaignGroupsVariable : campaignGroups) {
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
                    timeToSendValue
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
        /*
    *********************************************************
    @description     : Create chat records and run batch class to send it at that time or schedule batch job if needed
    @param           : groupId - Id of the Broadcast_Group__c record
    @return          : String indicating success or failure
    ********************************************************
    */
    @AuraEnabled
    public static String createChatRecodsMarketing(String templateId, List<String> groupIds, String dateFieldValue,String campaignId, String campaignGroupId,Map<String, SObject> phoneToObjectMapList,String selectedDateFields,String selectedOption,Integer dayAfter , Time timeToSend) {
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

                        // Add dayAfter and timeToSend to the DateTime
                        // if (dateValue != null) {
                        //     dateValue = dateValue.addDays(dayAfter != null ? dayAfter : 0);
                        //     if (timeToSend != null) {
                        //         DateTime utcDateTime = DateTime.valueOf(timeOfMessage);

                        //         // Convert UTC to user's timezone
                        //         TimeZone userTimeZone = UserInfo.getTimeZone();
                        //         DateTime userDateTime = utcDateTime.addSeconds(userTimeZone.getOffset(utcDateTime) / 1000);
                
                        //         dateValue = DateTime.newInstance(dateValue.date(), timeToSend);
                        //     }
                        // }
                        if (dateValue != null) {
                            // Step 1: Add days
                            dateValue = dateValue.addDays(dayAfter != null ? dayAfter : 0);
                        
                            if (timeToSend != null) {
                                // Step 2: Apply user timezone
                                TimeZone userTimeZone = UserInfo.getTimeZone();
                                System.debug(timeToSend);
                                // Combine date (after adding days) with the new time
                                DateTime combinedDateTime = DateTime.newInstance(dateValue.date(), timeToSend);
                        
                                // Step 3: Adjust to user's timezone offset
                                Integer offsetInSeconds = userTimeZone.getOffset(combinedDateTime) / 1000;
                                System.debug('Offset in seconds: ' + offsetInSeconds);
                                dateValue = combinedDateTime.addSeconds(offsetInSeconds);
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
                            campaignMember.WB_Marketing_Campaign_Group__c = campaignGroupId;
                            marketingCampaignMembers.add(campaignMember);

                        }
                    }
                }
                System.debug('Marketing Campaign Member ::: '+ marketingCampaignMembers);

                if (chatRecs.size() > 0) {
                    Database.insert(chatRecs, false, AccessLevel.USER_MODE);
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
            System.debug('Query ::: '+'SELECT Id,'+phoneField+', ' + fieldName + ' FROM ' + objectName);
            String query = 'SELECT Id,'+phoneField+', ' + fieldName + ' FROM ' + objectName;
    
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
    public static void getScheduleMessage(String memberId){
        
    }

}