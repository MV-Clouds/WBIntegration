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
        try {
            List<EmbeddedSignUpConfig__c> embeddedSignUpConfigRecord = new List<EmbeddedSignUpConfig__c>();
            List<Profile> systemAdminProfile = [SELECT Id, Name FROM Profile WHERE Name = 'System Administrator'];
            embeddedSignUpConfigRecord = [SELECT Id, Client_Id__c, Client_Secret__c, Config_Id__c, SetupOwnerId FROM EmbeddedSignUpConfig__c LIMIT 1];
            if(embeddedSignUpConfigRecord.size() > 0){
                EmbeddedSignUpConfig__c configRec = embeddedSignUpConfigRecord[0];
                configRec.Client_Id__c = '514916280628381';
                configRec.Client_Secret__c = '6e1719dde4e730a3a55e0eab8899f62b';
                configRec.Config_Id__c = '8971126402921271';
                configRec.SetupOwnerId = systemAdminProfile[0].Id;
                update configRec;
            } else {
                EmbeddedSignUpConfig__c config = new EmbeddedSignUpConfig__c(
                    Client_Id__c = '514916280628381',
                    Client_Secret__c = '6e1719dde4e730a3a55e0eab8899f62b',
                    Config_Id__c = '8971126402921271',
                    SetupOwnerId = systemAdminProfile[0].Id
                );
                insert config;
            }
            if(context.previousVersion() == null || Test.isRunningTest()) {
                String orgDataTable = '';
                String userDataTable = '';
                Map<String, Object> mapOfData = new Map<String, Object>();
                String orgId = context.organizationId();
                String orgDomain = URL.getOrgDomainURL().toExternalForm();
                List<Organization> orgs = [SELECT Id, Name, OrganizationType, IsSandbox FROM Organization WHERE Id =: orgId];    
                if (orgs!=null && orgs.size() > 0) {
                    Organization org = orgs[0];
                    String environment = Boolean.valueOf(org.IsSandbox) ? 'Sandbox' : 'Production';
                    mapOfData.put('Org_Id__c',org.Id);
                    mapOfData.put('Org_Name__c',org.Name);
                    mapOfData.put('Org_Type__c',org.OrganizationType);
                    mapOfData.put('Environment__c', environment);
                    mapOfData.put('Domain__c', orgDomain);
                    mapOfData.put('Installed_Product__c', 'WBConnect');
                    orgDataTable = '<table border="1" style="border-collapse: collapse;text-align:left; color: black;" cellpadding="4px">' +
                                    '<tr style="text-align:center;">' +
                                        '<th colspan="2" style="font-size: 18px; color: white; background-color:#165668;">Organization Details</th>' +
                                    '</tr>' +
                                    '<tr>' +
                                        '<th style="color: #165668">Organization Id</th>' +
                                        '<td>' + org.Id + '</td>' +
                                    '</tr>' +
                                    '<tr>' +
                                        '<th style="color: #165668">Organization Name</th>' +
                                        '<td>' + org.Name + '</td>' +
                                    '</tr>' +
                                    '<tr>' +
                                        '<th style="color: #165668">Organization Type</th>' +
                                        '<td>' + org.OrganizationType + '</td>' +
                                    '</tr>' +
                                    '<tr>' +
                                        '<th style="color: #165668">Environment</th>' +
                                        '<td>' + environment + '</td>' +
                                    '</tr>' +
                                    '<tr>' +
                                        '<th style="color: #165668">Domain</th>' +
                                        '<td>' + orgDomain + '</td>' +
                                    '</tr>' +
                                    '</table>';
                }
                List<User> users = [SELECT Id,Address,FirstName,LastName,Username,MobilePhone,Phone,TimeZoneSidKey,Email FROM User WHERE Id =: context.installerId()];    
                if (users!=null && users.size() > 0) {
                    User u = users[0];
                    Address address = u.Address;
                    String addressString = '';
                    
                    if(address != null){
                        if (address.getStreet() != null) {
                            addressString += address.getStreet() + ', ';
                        }
                        if (address.getCity() != null) {
                            addressString += address.getCity() + ', ';
                        }
                        if (address.getState() != null) {
                            addressString += address.getState() + ', ';
                        }
                        if (address.getPostalCode() != null) {
                            addressString += address.getPostalCode() + ', ';
                        }
                        if (address.getCountry() != null) {
                            addressString += address.getCountry();
                        }
                        if (addressString.endsWith(', ')) {
                            addressString = addressString.substring(0, addressString.length() - 2);
                        }
                    }
    
                    mapOfData.put('User_Id__c', u.Id);
                    mapOfData.put('Username__c', u.Username);
                    mapOfData.put('First_Name__c', u.FirstName);
                    mapOfData.put('Last_Name__c', u.LastName);
                    mapOfData.put('Email__c', u.Email);
                    mapOfData.put('Phone__c', u.Phone);
                    mapOfData.put('Mobile_Phone__c', u.MobilePhone);
                    mapOfData.put('Address__c', addressString);
                    mapOfData.put('TimeZoneSidKey__c', u.TimeZoneSidKey);
    
                    // also need to pull the type of the org, prod or sandbox
    
                    userDataTable = '<table border="1" style="border-collapse: collapse;text-align:left; color: black;" cellpadding="4px">' +
                                    '<tr style="text-align:center;">' +
                                        '<th colspan="2" style="font-size: 18px; color: white; background-color:#165668;">User Details</th>' +
                                    '</tr>' +
                                    '<tr>' +
                                        '<th style="color: #165668">User Id</th>' +
                                        '<td>' + u.Id + '</td>' +
                                    '</tr>' +
                                    '<tr>' +
                                        '<th style="color: #165668">User Name</th>' +
                                        '<td>' + u.Username + '</td>' +
                                    '</tr>' +
                                    '<tr>' +
                                        '<th style="color: #165668">FirstName</th>' +
                                        '<td>' + (String.isBlank(u.FirstName) ? '-' : u.FirstName) + '</td>' +
                                    '</tr>' +
                                    '<tr>' +
                                        '<th style="color: #165668">LastName</th>' +
                                        '<td>' + (String.isBlank(u.LastName) ? '-' : u.LastName) + '</td>' +
                                    '</tr>' +
                                    '<tr>' +
                                        '<th style="color: #165668">Email</th>' +
                                        '<td>' + (String.isBlank(u.Email) ? '-' : u.Email) + '</td>' +
                                    '</tr>' +
                                    '<tr>' +
                                        '<th style="color: #165668">Phone</th>' +
                                        '<td>' + (String.isBlank(u.Phone) ? '-' : u.Phone) + '</td>' +
                                    '</tr>' +
                                    '<tr>' +
                                        '<th style="color: #165668">Mobile Phone</th>' +
                                        '<td>' + (String.isBlank(u.MobilePhone) ? '-' : u.MobilePhone) + '</td>' +
                                    '</tr>' +
                                    '<tr>' +
                                        '<th style="color: #165668">Address</th>' +
                                        '<td>' + (addressString!=''? addressString : '-') + '</td>' +
                                    '</tr>' +
                                    '<tr>' +
                                        '<th style="color: #165668">Time Zone SidKey</th>' +
                                        '<td>' + (String.isBlank(u.TimeZoneSidKey) ? '-' : u.TimeZoneSidKey) + '</td>' +
                                    '</tr>' +
                                    '</table>';
                }
        
                Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
                List<String> emails = new List<String>{'productinstallationemail@v-xj3w6mezt66tmgyi1ybx4giimvh488ktt05mihoa2mya7we9f.5g-7qhe9eaa.ap59.apex.salesforce.com', 'wbconnect-support@mvclouds.com'};
                string[] to = emails;
    
                String stringToSend = JSON.serialize(mapOfData);
                
                email.setToAddresses(to);
                email.setSubject('WBConnect New Install - ' + orgId);
                email.setHtmlBody('<div style="font-family:Verdana;">Congrats WBConnect Team 🎉,<br></br><br></br>The WBConnect app has been installed in an Organization, Below are some Details about the client org.<br></br><br></br>' + orgDataTable+ '<br></br>' + userDataTable + '<br></br><br></br> <|--- BackEnd Use Only Data Start ---|>' + stringToSend +'<|--- BackEnd Use Only Data End ---|> </div>');
                Messaging.sendEmail(new Messaging.SingleEmailMessage[] { email });
            }
        } catch (Exception e) {
            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
            List<String> emails = new List<String>{'wbconnect-support@mvclouds.com'};
            string[] to = emails;

            // Enhanced error details
            String errorDetails = '<b>Error Message:</b> ' + e.getMessage() + '<br>' + '<b>Exception Type:</b> ' + 'PostInstallClass' + '<br>' + '<b>Line Number:</b> ' + e.getLineNumber() + '<br>' + '<b>Stack Trace:</b> <b>' + e.getStackTraceString() + '</b>';

            email.setToAddresses(to);
            email.setSubject('WBConnect Package Install Failed Exception Email');
            email.setHtmlBody( '<div style="font-family:Verdana;">' + '<b>Error Details:</b><br>' + errorDetails + '<br><br> <|--- BackEnd Use Only Data Start ---|>' + e  + '<|--- BackEnd Use Only Data End ---|> </div>');
            Messaging.sendEmail(new Messaging.SingleEmailMessage[] { email });
        }
    }
}