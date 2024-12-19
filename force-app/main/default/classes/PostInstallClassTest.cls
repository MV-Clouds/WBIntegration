@isTest
public with sharing class PostInstallClassTest {
    @isTest
    static void testInstallScript() {

        Test.startTest();
        PostInstallClass postinstall = new PostInstallClass();
        Test.testInstall(postinstall, null);
        Integer invocations = Limits.getEmailInvocations();
        Test.stopTest();

        system.assertEquals(1, invocations, 'An email should be sent');
    }
}