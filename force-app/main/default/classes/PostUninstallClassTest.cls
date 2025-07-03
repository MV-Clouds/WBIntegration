@IsTest
public with sharing class PostUninstallClassTest {
    
    @IsTest
    static void testOnUninstall() {
        Test.startTest();

        PostUninstallClass postuninstall = new PostUninstallClass();
        postuninstall.handleUninstall(UserInfo.getOrganizationId());
        
        Test.stopTest();
    }
}