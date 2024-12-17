/**
 * @description       : 
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             : 
 * @last modified on  : 12-17-2024
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
**/
@IsTest
public class WhatsAppConfigurationTest {

    @IsTest
    static void testSaveConfigurations() {
        Test.startTest();
        WhatsAppConfigurationController.saveConfiguration('123','123','123');
        Test.stopTest();
    }
}