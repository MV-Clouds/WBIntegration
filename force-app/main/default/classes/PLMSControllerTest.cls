@IsTest
public class PLMSControllerTest {
    
    @TestSetup
    static void setupData() {
        LicenseConfig__c config = new LicenseConfig__c(
            Client_Id__c = 'testClientId',
            Client_Secret__c = 'testClientSecret',
            Username__c = 'testuser@example.com',
            Password__c = 'testpassword'
        );
        insert config;
    }

    @IsTest
    static void testGetPLMSValidity_Success() {
        // Mock Access Token Response
        String accessTokenResponse = JSON.serialize(new Map<String, Object>{
            'access_token' => 'dummyAccessToken',
            'instance_url' => 'https://mvcloudsprivatelimited.my.salesforce.com',
            'id' => 'someId',
            'token_type' => 'Bearer',
            'issued_at' => String.valueOf(System.currentTimeMillis()),
            'signature' => 'someSignature'
        });

        HttpResponse authRes = new HttpResponse();
        authRes.setHeader('Content-Type', 'application/json');
        authRes.setBody(accessTokenResponse);
        authRes.setStatusCode(200);

        // Mock Product_Subscriber__c Response
        String productSubscriberResponse = JSON.serialize(new Map<String, Object>{
            'totalSize' => 1,
            'done' => true,
            'records' => new List<Object>{
                new Map<String, Object>{
                    'Id' => 'a0Axxxxxxxxxxxx',
                    'Org_Id__c' => UserInfo.getOrganizationId(),
                    'Expiration_DateTime__c' => '2026-05-01T00:00:00.000+0000'
                }
            }
        });

        HttpResponse subscriberRes = new HttpResponse();
        subscriberRes.setHeader('Content-Type', 'application/json');
        subscriberRes.setBody(productSubscriberResponse);
        subscriberRes.setStatusCode(200);

        // Chain both responses
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(authRes));
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(subscriberRes));

        Test.startTest();
        PLMSController.getPLMSValidity();
        Test.stopTest();

        LicenseConfig__c config = LicenseConfig__c.getInstance();
        System.assertEquals(true, config.Is_License_Valid__c);
        System.assertNotEquals(null, config.Expiration_Date__c);
        System.assertNotEquals(null, config.Next_Callout_Date__c);
    }

    @IsTest
    static void testCheckLicenseUsability_ValidLicense() {
        LicenseConfig__c config = LicenseConfig__c.getInstance();
        config.Is_License_Valid__c = true;
        config.Expiration_Date__c = Date.today().addDays(10);
        upsert config;

        Test.startTest();
        Boolean isUsable = PLMSController.checkLicenseUsablility();
        Test.stopTest();

        System.assertEquals(true, isUsable);
    }

    @IsTest
    static void testCheckLicenseUsability_InvalidLicense() {
        LicenseConfig__c config = LicenseConfig__c.getInstance();
        config.Is_License_Valid__c = false;
        config.Expiration_Date__c = Date.today().addDays(10);
        upsert config;

        Test.startTest();
        Boolean isUsable = PLMSController.checkLicenseUsablility();
        Test.stopTest();

        System.assertEquals(false, isUsable);
    }
}