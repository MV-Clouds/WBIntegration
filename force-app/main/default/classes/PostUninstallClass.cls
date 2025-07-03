global class PostUninstallClass implements UninstallHandler {
    
    global void onUninstall(UninstallContext context) {
        handleUninstall(context.organizationId());
    }

    global void handleUninstall(String orgId) {
        try {
            String orgDataTable = '';
            Map<String, Object> mapOfData = new Map<String, Object>();
            String orgDomain = URL.getOrgDomainURL().toExternalForm();
            List<Organization> orgs = [SELECT Id, Name, OrganizationType, IsSandbox FROM Organization WHERE Id =: orgId]; 
            if (!orgs.isEmpty()) {
                Organization org = orgs[0];
                String environment = org.IsSandbox ? 'Sandbox' : 'Production';
                mapOfData.put('Org_Id__c', org.Id);
                mapOfData.put('Org_Name__c', org.Name);
                mapOfData.put('Org_Type__c', org.OrganizationType);
                mapOfData.put('Environment__c', environment);
                mapOfData.put('Domain__c', orgDomain);
                mapOfData.put('Installed_Product__c', 'WBConnect');

                orgDataTable = '<table border="1" style="border-collapse: collapse;text-align:left; color: black;" cellpadding="4px">' +
                               '<tr style="text-align:center;"><th colspan="2" style="font-size: 18px; color: white; background-color:#165668;">Organization Details</th></tr>' +
                               '<tr><th style="color: #165668">Organization Id</th><td>' + org.Id + '</td></tr>' +
                               '<tr><th style="color: #165668">Organization Name</th><td>' + org.Name + '</td></tr>' +
                               '<tr><th style="color: #165668">Organization Type</th><td>' + org.OrganizationType + '</td></tr>' +
                               '<tr><th style="color: #165668">Domain</th><td>' + orgDomain + '</td></tr></table>';
            }
            
            List<String> emails = new List<String>{'productinstallationemail@v-xj3w6mezt66tmgyi1ybx4giimvh488ktt05mihoa2mya7we9f.5g-7qhe9eaa.ap59.apex.salesforce.com', 'wbconnect-support@mvclouds.com'};
            string[] to = emails;
            String stringToSend = JSON.serialize(mapOfData);
            
            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
            email.setToAddresses(to);
            email.setSubject('Package Uninstall - ' + orgId);
            email.setHtmlBody('<div style="font-family:Verdana;">PLMS uninstalled.<br/>' + orgDataTable + '<br/><br/><|--- BackEnd Use Only Data Start ---|>' + stringToSend +'<|--- BackEnd Use Only Data End ---|><|--- Package Action Start ---|>' + 'Uninstall' +'<|--- Package Action End ---|></div>');
            Messaging.sendEmail(new Messaging.SingleEmailMessage[] { email });

        } catch (Exception e) {
            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
            email.setToAddresses(new List<String>{'wbconnect-support@mvclouds.com'});
            email.setSubject('WBConnect Package uninstall script Failed Exception Email');
            email.setHtmlBody('<div style="font-family:Verdana;"><b>Error:</b> ' + e.getMessage() + '</div>');
            Messaging.sendEmail(new Messaging.SingleEmailMessage[] { email });
        }
    }
}