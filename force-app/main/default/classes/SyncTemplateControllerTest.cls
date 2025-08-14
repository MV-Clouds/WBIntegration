@isTest
private class SyncTemplateControllerTest {
    
    // Mock class for HTTP callout
    public class MockFlowTemplateHttpResponse implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);

            String payload = '{"data":[' + 
                '{' + 
                '"name":"test_flow_template_1",' + 
                '"parameter_format":"POSITIONAL",' + 
                '"components":[' + 
                '{' + 
                '"type":"HEADER",' + 
                '"format":"TEXT",' + 
                '"text":"Hello user your flow template is ready"' + 
                '},' + 
                '{' + 
                '"type":"BODY",' + 
                '"text":"Hello user your flow template is ready"' + 
                '},' + 
                '{' + 
                '"type":"BUTTONS",' + 
                '"buttons":[' + 
                '{' + 
                '"type":"FLOW",' + 
                '"text":"View Flow",' + 
                '"flow_id":"3754289068201589",' + 
                '"flow_action":"NAVIGATE",' + 
                '"navigate_screen":"QUESTION_ONE"' + 
                '}' + 
                ']' + 
                '}' + 
                '],' + 
                '"language":"en",' + 
                '"status":"APPROVED",' + 
                '"category":"MARKETING",' + 
                '"sub_category":"FORM",' + 
                '"id":"1523027962026654"' + 
                '}' + 
                '],' + 
                '"paging":{' + 
                '"cursors":{' + 
                '"before":"MAZDZD",' + 
                '"after":"MjQZD"' + 
                '}' + 
                '}' + 
                '}';

            res.setBody(payload);
            return res;
        }
    }

    @testSetup
    static void setupData() {
        // Org templates
        List<Template__c> templates = new List<Template__c>();
        for (Integer i = 1; i <= 5; i++) {
            templates.add(new Template__c(
                Template_Name__c = 'Template' + i, 
                Template_Category__c = 'Marketing', 
                Status__c = 'Active-Quality Pending', 
                Template_Id__c = 'testId' + i
            ));
        }
        insert templates;

        // Template variables
        List<Template_Variable__c> variables = new List<Template_Variable__c>();
        for (Template__c template : [SELECT Id FROM Template__c]) {
            variables.add(new Template_Variable__c(
                Template__c = template.Id, 
                Name = '{{1}}', 
                Object_Name__c = 'WBConnect_Contact__c', 
                Field_Name__c = 'FirstName', 
                Type__c = 'Header'
            ));
            variables.add(new Template_Variable__c(
                Template__c = template.Id, 
                Name = '{{1}}', 
                Object_Name__c = 'WBConnect_Contact__c', 
                Field_Name__c = 'Name', 
                Type__c = 'Body'
            ));
        }
        insert variables;

        // Contacts
        // insert new WBConnect_Contact__c(Name = 'John');

        // Flows in org (different from mocked Meta flow_id so it triggers metaToOrgFlowTemplates)
        for (Integer i = 0; i < 2; i++) {
            insert new Flow__c(
                Flow_Id__c = 'Flow' + i, 
                Flow_Name__c = 'Test Flow ' + i, 
                Flow_JSON__c = '{"key": "value"}', 
                Status__c = 'Published'
            );
        }

        // Required AWS Config record
        insert new MVWB__AWS_Config__c(
            MVWB__AWS_Access_Key__c = 'testAccessKey',
            MVWB__AWS_Secret_Access_Key__c = 'testSecretKey',
            MVWB__S3_Bucket_Name__c = 'test-bucket',
            MVWB__S3_Region_Name__c = 'us-east-1'
        );
    }

    @isTest
    static void syncTemplate_flowTemplateDetected() {
        Test.setMock(HttpCalloutMock.class, new MockFlowTemplateHttpResponse());

        Test.startTest();
        SyncTemplateController.templateListWrapper wrapper = SyncTemplateController.syncTemplate();
        System.assertNotEquals(null, wrapper, 'Wrapper should not be null');
        System.assert(wrapper.metaToOrgFlowTemplates.contains('test_flow_template_1'),
            'Flow template from Meta should be detected');

        String wrapperJson = JSON.serialize(wrapper);
        SyncTemplateController.confirmTemplateSync('CreateToOrg', true, wrapperJson);
        SyncTemplateController.buildTemplateActionData(wrapper, 'CreateToOrg');
        Test.stopTest();
    }
}
