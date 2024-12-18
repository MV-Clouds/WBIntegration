/**
 * Class Name: PostInstallClass
 * Test Class: PostInstallClassTest
 * @description: Used to send the email to the 'wbconnect-support@mvclouds.com' to keep record of the organization which installed package 
 * Created Date: 18 Dec, 2024
 * Created By: Kevin Suvagiya
 *--------------------------------------------------------------------------------
 * Last Modified By: Kevin Suvagiya
 * Last Modified Date: 18 Dec, 2024
 * Last Modification Description: Created a method to send an email with organization and user info
 *--------------------------------------------------------------------------------
 * Modification History:
 * Date Modified - Developer Name - Description
 * 18 Dec, 2024  - Kevin Suvagiya - Created a method to send an email with organization and user info
 **/
global class PostInstallClass implements InstallHandler {

    /*
    *********************************************************
    @description     : Method is used to send the email with organization and user info
    @param           : context - {InstallContext} - Context of the installation, can be used for versioning but not used for now
    @return          : none
    ********************************************************
    */
    global void onInstall(InstallContext context) {
        String orgId = UserInfo.getOrganizationId();
        String orgName = UserInfo.getOrganizationName();
        String userNameRunningAs = UserInfo.getName();
        String userIdRunningAs = UserInfo.getUserId();
        String emailRunningAs = UserInfo.getUserEmail();
        String userTimeZone = UserInfo.getTimeZone().toString();

        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        string[] to = new string[] {'wbconnect-support@mvclouds.com'};
        
        email.setToAddresses(to);
        email.setSubject('WBConnects New Download - ' + orgId);
        email.setHtmlBody('<p style="font-family:Verdana;">Greeting WBConnect Team,<br></br><br></br>The WBConnect app has been downloaded in an Organization, following are some information:<br></br>Organization Name: ' + orgName + '<br></br>Organization Id: ' + orgId + '<br></br>User Name: ' + userNameRunningAs + '<br></br>User Id: ' + userIdRunningAs + '<br></br>User Email: ' + emailRunningAs + '<br></br>User TimeZone: ' + userTimeZone + '</p>');
        Messaging.sendEmail(new Messaging.SingleEmailMessage[] { email });
    }
}