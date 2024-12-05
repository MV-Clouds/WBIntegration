@isTest
public class ChatWindowControllerTest {

    @testSetup
    static void setup() {
        // Create test data for Contact
        Contact testContact = new Contact(LastName = 'Test Contact');
        insert testContact;

        // Create test data for Chat__c
        Chat__c testChat = new Chat__c(
            Message__c = 'Test Message',
            Contact__c = testContact.Id,
            Type_of_Message__c = 'OutBound Messages',
            Message_Status__c = 'Sent',
            Time_of_Message__c = '12:00',
            Date_of_Message__c = Date.today(),
            Message_Type__c = 'Text'
        );
        insert testChat;
    }

    @isTest
    static void testFetchAllChats() {
        // Get the Contact Id
        Contact testContact = [SELECT Id FROM Contact LIMIT 1];

        Test.startTest();
        List<Chat__c> chats = ChatWindowController.fetchAllChats(testContact.Id);
        Test.stopTest();

        // Assert that the method fetches the correct number of chats
        System.assert(chats.size() > 0, 'Chats should be returned.');
        System.assertEquals('Test Message', chats[0].Message__c, 'Chat message should match the test data.');
    }

    @isTest
    static void testCreateChat() {
        // Get the Contact Id
        Contact testContact = [SELECT Id FROM Contact LIMIT 1];

        // Create chat data map
        Map<String, String> chatData = new Map<String, String>{
            'message' => 'Hello!',
            'templateId' => null,
            'messageType' => 'Text',
            'recordId' => testContact.Id,
            'replyToChatId' => null
        };

        Test.startTest();
        Chat__c newChat = ChatWindowController.createChat(chatData);
        Test.stopTest();

        // Assert that the chat was created successfully
        System.assertNotEquals(null, newChat, 'New chat should be created.');
        System.assertEquals('Hello!', newChat.Message__c, 'Message should match the input.');
        System.assertEquals(testContact.Id, newChat.Contact__c, 'Contact ID should match.');
    }

    @isTest
    static void testCreateChatWithImage() {
        // Get the Contact Id
        Contact testContact = [SELECT Id FROM Contact LIMIT 1];

        // Create ContentVersion
        ContentVersion contentVersion = new ContentVersion(
            Title = 'Test Image',
            VersionData = Blob.valueOf('Test Content'),
            PathOnClient = 'testImage.jpg'
        );
        insert contentVersion;
        ContentVersion cv = [SELECT Id FROM ContentVersion WHERE Title = 'Test Image' LIMIT 1];

        // Create chat data map
        Map<String, String> chatData = new Map<String, String>{
            'message' => cv.Id,
            'templateId' => null,
            'messageType' => 'Image',
            'recordId' => testContact.Id,
            'replyToChatId' => null
        };

        Test.startTest();
        Chat__c newChat = ChatWindowController.createChat(chatData);
        Test.stopTest();

        // Assert that the chat was created successfully
        System.assertNotEquals(null, newChat, 'New chat should be created.');
        System.assert(newChat.Message__c.contains('/sfc/servlet.shepherd/version/download/'), 'Message should be a file link.');
    }

    @isTest
    static void testUpdateReaction() {
        // Get the Chat Id
        Chat__c testChat = [SELECT Id FROM Chat__c LIMIT 1];

        Test.startTest();
        Chat__c updatedChat = ChatWindowController.updateReaction(testChat.Id, 'Like');
        Test.stopTest();

        // Assert that the reaction was updated successfully
        System.assertNotEquals(null, updatedChat, 'Chat should be updated.');
        System.assertEquals('Like', updatedChat.Reaction__c, 'Reaction should match the input.');
    }

    @isTest
    static void testCreateChatException() {
        // Create invalid chat data map
        Map<String, String> chatData = new Map<String, String>{
            'message' => null,
            'templateId' => 'test',
            'messageType' => null,
            'recordId' => null,
            'replyToChatId' => null
        };

        Test.startTest();
        Chat__c newChat = ChatWindowController.createChat(chatData);
        Test.stopTest();

        System.assertEquals(null, newChat, 'Chat creation should fail with invalid data.');
    }
}
