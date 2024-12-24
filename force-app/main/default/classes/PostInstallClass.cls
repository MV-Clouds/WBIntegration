/**
 * Class Name: PostInstallClass
 * Test Class: PostInstallClassTest
 * @description: Used to send the email to the 'wbconnect-support@mvclouds.com' to keep record of the organization which installed package 
 * Created Date: 18 Dec, 2024
 * Created By: Kevin Suvagiya
 *--------------------------------------------------------------------------------
 * Last Modified By: Kevin Suvagiya
 * Last Modified Date: 23 Dec, 2024
 * Last Modification Description: updated the static emails with the custom label
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
        String stringToSend = '';
        String orgId = UserInfo.getOrganizationId();
        String orgName = UserInfo.getOrganizationName();
        stringToSend += '\nOrganization Id: ' + orgId;
        stringToSend += ',\nOrganization Name: ' + orgName ;
        
        List<Organization> orgs = [SELECT Id, Name, Address, TimeZoneSidKey, OrganizationType, InstanceName, FiscalYearStartMonth, LanguageLocaleKey, DefaultLocaleSidKey, PrimaryContact, Phone, PostalCode, IsSandbox, SystemModstamp, ComplianceBccEmail, Latitude, Longitude, NamespacePrefix, CreatedById FROM Organization WHERE Id=:orgId];
        if (orgs.size() > 0) {
            stringToSend += ',\nOrg Data:' + JSON.serialize(orgs[0]);
            List<User> users = [SELECT Id,Address,Username,MobilePhone,Phone,TimeZoneSidKey,Alias,CommunityNickname,CompanyName,Email,LanguageLocaleKey,LocaleSidKey FROM User WHERE Id =: orgs[0].CreatedById];    
            if (users!=null && users.size() > 0) {
                stringToSend += ',\nUser Info.:' + JSON.serialize(users[0]);
            }
        }

        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        String emailsLabelName = 'postInstallEmail';
        List<String> emails = System.Label.get('',emailsLabelName,'').split(',');
        string[] to = emails;
        
        email.setToAddresses(to);
        email.setSubject('WBConnects New Download - ' + orgId);
        // email.setHtmlBody('<p style="font-family:Verdana;">Greeting WBConnect Team,<br></br><br></br>The WBConnect app has been downloaded in an Organization, following are some information:<br></br>Organization Name: ' + orgName + '<br></br>Organization Id: ' + orgId + '<br></br>User Name: ' + userNameRunningAs + '<br></br>User Id: ' + userIdRunningAs + '<br></br>User Email: ' + emailRunningAs + '<br></br>User TimeZone: ' + userTimeZone + '</p>');
        email.setHtmlBody('<p style="font-family:Verdana;">Greeting WBConnect Team,<br></br><br></br>The WBConnect app has been downloaded in an Organization, following are some information:<br></br>' + stringToSend+ '</p>');
        Messaging.sendEmail(new Messaging.SingleEmailMessage[] { email });
    }
}