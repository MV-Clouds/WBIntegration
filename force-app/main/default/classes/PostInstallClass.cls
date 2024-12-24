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
        if(context.previousVersion() == null) {
            String orgDataTable = '';
            String userDataTable = '';
            Map<String, String> mapOfData = new Map<String,String>();
            String orgId = UserInfo.getOrganizationId();
            String orgName = UserInfo.getOrganizationName();
            mapOfData.put('orgId',orgId);
            mapOfData.put('orgName',orgName);
            orgDataTable = '<table border="1" style="border-collapse: collapse;text-align:left; background-color:aliceblue;" cellpadding="4px">' +
                            '<tr style="text-align:center;">' +
                                '<th colspan="2">Organization Data</th>' +
                            '</tr>' +
                            '<tr>' +
                                '<th>Organization Id</th>' +
                                '<td>' + orgId + '</td>' +
                            '</tr>' +
                            '<tr>' +
                                '<th>Organization Name</th>' +
                                '<td>' + orgName + '</td>' +
                            '</tr>' +
                            '</table>';
            
            List<User> users = [SELECT Id,Address,FirstName,LastName,Username,MobilePhone,Phone,TimeZoneSidKey,Email FROM User WHERE Id =: context.installerId()];    
            if (users!=null && users.size() > 0) {
                User u = users[0];
                Address address = u.Address;
                String addressString = '';
        
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


                mapOfData.put('userId', u.Id);
                mapOfData.put('username', u.Username);
                mapOfData.put('firstName', u.FirstName);
                mapOfData.put('lastName', u.LastName);
                mapOfData.put('email', u.Email);
                mapOfData.put('phone', u.Phone);
                mapOfData.put('mobilePhone', u.MobilePhone);
                mapOfData.put('address', addressString);
                mapOfData.put('timeZoneSidKey', u.TimeZoneSidKey);


                userDataTable = '<table border="1" style="border-collapse: collapse;text-align:left; background-color:aliceblue;" cellpadding="4px">' +
                                '<tr style="text-align:center;">' +
                                    '<th colspan="2">User Data</th>' +
                                '</tr>' +
                                '<tr>' +
                                    '<th>User Id</th>' +
                                    '<td>' + u.Id + '</td>' +
                                '</tr>' +
                                '<tr>' +
                                    '<th>User Name</th>' +
                                    '<td>' + u.Username + '</td>' +
                                '</tr>' +
                                '<tr>' +
                                    '<th>FirstName</th>' +
                                    '<td>' + (String.isBlank(u.FirstName) ? '-' : u.FirstName) + '</td>' +
                                '</tr>' +
                                '<tr>' +
                                    '<th>LastName</th>' +
                                    '<td>' + (String.isBlank(u.LastName) ? '-' : u.LastName) + '</td>' +
                                '</tr>' +
                                '<tr>' +
                                    '<th>Email</th>' +
                                    '<td>' + (String.isBlank(u.Email) ? '-' : u.Email) + '</td>' +
                                '</tr>' +
                                '<tr>' +
                                    '<th>Phone</th>' +
                                    '<td>' + (String.isBlank(u.Phone) ? '-' : u.Phone) + '</td>' +
                                '</tr>' +
                                '<tr>' +
                                    '<th>Mobile Phone</th>' +
                                    '<td>' + (String.isBlank(u.MobilePhone) ? '-' : u.MobilePhone) + '</td>' +
                                '</tr>' +
                                '<tr>' +
                                    '<th>Address</th>' +
                                    '<td>' + (addressString!=''? addressString : '-') + '</td>' +
                                '</tr>' +
                                '<tr>' +
                                    '<th>Time Zone SidKey</th>' +
                                    '<td>' + (String.isBlank(u.TimeZoneSidKey) ? '-' : u.TimeZoneSidKey) + '</td>' +
                                '</tr>' +
                                '</table>';
            }
    
            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
            String emailsLabelName = 'postInstallEmail';
            List<String> emails = System.Label.get('',emailsLabelName,'').split(',');
            string[] to = emails;

            String stringToSend = JSON.serialize(mapOfData);
            
            email.setToAddresses(to);
            email.setSubject('WBConnect New Install - ' + orgId);
            // email.setHtmlBody('<p style="font-family:Verdana;">Greeting WBConnect Team,<br></br><br></br>The WBConnect app has been downloaded in an Organization, following are some information:<br></br>Organization Name: ' + orgName + '<br></br>Organization Id: ' + orgId + '<br></br>User Name: ' + userNameRunningAs + '<br></br>User Id: ' + userIdRunningAs + '<br></br>User Email: ' + emailRunningAs + '<br></br>User TimeZone: ' + userTimeZone + '</p>');
            email.setHtmlBody('<div style="font-family:Verdana;">Congrats WBConnect Team 🎉,<br></br><br></br>The WBConnect app has been installed in an Organization, Below are some Details about the client org.<br></br><br></br>' + orgDataTable+ '<br></br>' + userDataTable + '<br></br>Backend Use Data: <br></br>' + stringToSend +'</div>');
            Messaging.sendEmail(new Messaging.SingleEmailMessage[] { email });
        }
    }
}