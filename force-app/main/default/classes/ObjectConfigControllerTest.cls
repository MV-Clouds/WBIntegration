/**
* Class Name: ObjectConfigControllerTest
* @description: Test class for ObjectConfigController.
* Created Date: 1 Apr, 2025
* Created By: Harsh Gandhi
*--------------------------------------------------------------------------------
* Last Modified By: 
* Last Modified Date: 
* Last Modification Description: 
**/
@IsTest
public with sharing class ObjectConfigControllerTest {

    @TestSetup
    static void setupTestData() {
        // Create a sample Contact record
        Contact contact = new Contact(FirstName = 'Test', LastName = 'User', Phone = '1234567890');
        insert contact;
    }

    @IsTest
    static void testGetObjectsWithPhoneField() {
        Test.startTest();
        List<Map<String, String>> result = ObjectConfigController.getObjectsWithPhoneField();
        Test.stopTest();

        System.assertNotEquals(0, result.size(), 'Expected phone field objects');
    }

    @IsTest
    static void testGetRequiredFields() {
        Test.startTest();
        List<Map<String, Object>> result = ObjectConfigController.getRequiredFields('Contact');
        Test.stopTest();

        System.assertNotEquals(0, result.size(), 'Expected required fields');
        System.assertEquals('Phone', ((List<Map<String, String>>)result[0].get('phoneFields'))[0].get('value'), 'Expected phone field');
    }

    @IsTest
    static void testGetTextAndPhoneFields() {
        Test.startTest();
        List<Map<String, Object>> result = ObjectConfigController.getTextAndPhoneFields('Contact');
        Test.stopTest();

        System.assertNotEquals(0, result.size(), 'Expected text and phone fields');
    }

    @IsTest
    static void testGetUserConfig() {
        Test.startTest();
        Map<String, String> result = ObjectConfigController.getUserConfig();
        Test.stopTest();

        System.assertNotEquals(null, result.get('ObjectConfigInfo'), 'Expected ObjectConfigInfo data');
    }

    @IsTest
    static void testSaveUserConfig() {
        Test.startTest();
        String jsonData = '{"objectApiName":"Contact","phoneField":"Phone"}';
        String jsonDataForChat = '{"Contact":{"nameField":"LastName","phoneField":"Phone"}}';

        String result = ObjectConfigController.saveUserConfig(jsonData, jsonDataForChat);
        Test.stopTest();

        System.assertNotEquals('sucess', result, 'Expected success response');
    }

    @IsTest
    static void testGetRecordName() {
        Contact testContact = [SELECT Id FROM Contact LIMIT 1];

        Test.startTest();
        String recordName = ObjectConfigController.getRecordName(testContact.Id, 'Contact');
        Test.stopTest();

        System.assertEquals('Test User', recordName, 'Expected contact name');
    }

    @IsTest
    static void testInitializeDummyConfig() {
        // Ensure no metadata records exist before the test
        // delete [SELECT Id FROM Object_Config__mdt];

        // Mock Metadata API calls
        Test.startTest();
        ObjectConfigController.initializeDummyConfig();
        Test.stopTest();

        // Verify that metadata was created
        Object_Config__mdt config = [SELECT Id, ObjectConfigInfo__c, ChatWindowConfigInfo__c FROM Object_Config__mdt LIMIT 1];
        System.assertNotEquals(null, config);
        System.assertNotEquals(null, config.ObjectConfigInfo__c);
        System.assertNotEquals(null, config.ChatWindowConfigInfo__c);

        // Validate JSON structure of ObjectConfigInfo__c
        Map<String, Object> objectConfigMap = (Map<String, Object>) JSON.deserializeUntyped(config.ObjectConfigInfo__c);
        System.assertEquals('Contact', objectConfigMap.get('objectApiName'));
        System.assertEquals('Phone', objectConfigMap.get('phoneField'));
        System.assert(objectConfigMap.containsKey('requiredFieds'));

        // Validate JSON structure of ChatWindowConfigInfo__c
        Map<String, Object> chatConfigMap = (Map<String, Object>) JSON.deserializeUntyped(config.ChatWindowConfigInfo__c);
        Map<String, Object> contactConfig = (Map<String, Object>) chatConfigMap.get('Contact');
        System.assertEquals('LastName', contactConfig.get('nameField'));
        System.assertEquals('Phone', contactConfig.get('phoneField'));

        System.debug('Test completed successfully.');
    }
}