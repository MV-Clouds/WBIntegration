@IsTest
public class PLMSControllerTest {
    
    // Mock class for HTTP callout
    class MockPLMSResponse implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);
            
            // Return a valid expiration datetime 5 days from now
            String futureDateTime = Datetime.now().addDays(5).formatGmt('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\'');
            
            res.setBody('{ "Expiration_DateTime__c": "' + futureDateTime + '" }');
            return res;
        }
    }
    
    @isTest
    static void test_getPLMSValidity_success() {
        // Step 1: Insert dummy License Configuration
        MVWB__LicenseConfig__c config = new MVWB__LicenseConfig__c(
            MVWB__Is_License_Valid__c = false
        );
        insert config;

        // Step 2: Set mock callout
        Test.setMock(HttpCalloutMock.class, new MockPLMSResponse());

        // Step 3: Call the method inside a test context
        Test.startTest();
        PLMSController.getPLMSValidity();
        Test.stopTest();
    }

    @isTest
    static void test_getPLMSValidityCustom() {
        // Step 1: Insert dummy License Configuration
        MVWB__LicenseConfig__c config = new MVWB__LicenseConfig__c(
            MVWB__Is_License_Valid__c = false
        );
        insert config;

        // Step 2: Set mock callout
        Test.setMock(HttpCalloutMock.class, new MockPLMSResponse());

        // Step 3: Call the method inside a test context
        Test.startTest();
        PLMSController.getPLMSValidityCustom();
        Test.stopTest();
    }

    @IsTest
    static void testCheckLicenseUsability_ValidLicense() {
        MVWB__LicenseConfig__c config = MVWB__LicenseConfig__c.getInstance();
        config.Is_License_Valid__c = true;
        config.Expiration_Date__c = Date.today().addDays(10);
        upsert config;

        Test.startTest();
        Boolean isUsable = PLMSController.checkLicenseUsablility();
        Test.stopTest();
    }

    @IsTest
    static void testCheckLicenseUsability_InvalidLicense() {
        MVWB__LicenseConfig__c config = MVWB__LicenseConfig__c.getInstance();
        config.Is_License_Valid__c = false;
        config.Expiration_Date__c = Date.today().addDays(10);
        upsert config;

        Test.startTest();
        Boolean isUsable = PLMSController.checkLicenseUsablility();
        Test.stopTest();
    }

    @isTest
    static void testSendEmailMethod() {
        Test.startTest();
        
        // Case 1: Send email for license expiration (isException = false)
        DateTime expiration = System.now().addDays(-1); // Past date to simulate expired
        PLMSController.sendEmail(expiration, false);
        
        // Case 2: Send email for exception (isException = true)
        PLMSController.sendEmail(null, true);
        
        Test.stopTest();
    }
    
    @IsTest
    static void test_getPLMSValidity() {
        Test.startTest();
        PLMSController.getPLMSValidity(false);
        Test.stopTest();
    }
}