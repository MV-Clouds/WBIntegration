@isTest
private class SyncTemplateBatchClassTest{
    // Mock class for HTTP callout
    public class MockFlowTemplateHttpResponse implements HttpCalloutMock{
        public HttpResponse respond(HttpRequest req){
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
                         '"text":"Hello user your flow template is ready",' + 
                         '"example":{' + 
                         '"header_text":["Alt header 1","Alt header 2"],' + 
                         '"header_handle":["https://bucket.s3.amazonaws.com/test_image.png"]' + 
                         '}' + 
                         '},' + 
                         '{' + 
                         '"type":"HEADER",' + 
                         '"format":"IMAGE",' + 
                         '"text":"Image Header Example",' + 
                         '"example":{' + 
                         '"header_text":["Alt header image"],' + 
                         '"header_handle":["https://bucket.s3.amazonaws.com/test_image2.png"]' + 
                         '}' + 
                         '},' + 
                         '{' + 
                         '"type":"BODY",' + 
                         '"text":"Body text example {{1}}",' + 
                         '"example":{' + 
                         '"body_text":[["Alt body 1","Alt body 2"]]' + 
                         '}' + 
                         '},' + 
                         '{' + 
                         '"type":"BUTTONS",' + 
                         '"buttons":[' + 
                         '{' + 
                         '"type":"FLOW",' + 
                         '"text":"Start Flow",' + 
                         '"flow_id":"Flow123",' + 
                         '"flow_action":"NAVIGATE",' + 
                         '"navigate_screen":"SCREEN_ONE"' + 
                         '},' + 
                         '{' + 
                         '"type":"URL",' + 
                         '"text":"Visit Site",' + 
                         '"url":"https://example.com"' + 
                         '},' + 
                         '{' + 
                         '"type":"PHONE_NUMBER",' + 
                         '"text":"Call Us",' + 
                         '"phone_number":"+123456789"' + 
                         '}' + 
                         ']' + 
                         '}' + 
                         '],' + 
                         '"language":"en",' + 
                         '"status":"APPROVED",' + 
                         '"category":"MARKETING",' + 
                         '"sub_category":"FORM",' + 
                         '"id":"1523027962026654",' + 
                         '"add_security_recommendation":true,' + 
                         '"code_expiration_minutes":5,' + 
                         '"message_send_ttl_seconds":3600' + 
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
    static void setupData(){

        // Required AWS Config record
        insert new MVWB__AWS_Config__c(
            MVWB__AWS_Access_Key__c = 'testAccessKey',
            MVWB__AWS_Secret_Access_Key__c = 'testSecretKey',
            MVWB__S3_Bucket_Name__c = 'test-bucket',
            MVWB__S3_Region_Name__c = 'us-east-1'
        );

        List<Template__c> templates = new List<Template__c>();

        // Template with Text Header (Marketing)
        templates.add(new Template__c(
            Template_Name__c = 'Template1', 
            Template_Category__c = 'Marketing', 
            Status__c = 'Active-Quality Pending', 
            Template_Id__c = 'testId1', 
            Language__c = 'en', 
            WBTemplate_Body__c = 'Hello {{1}}', 
            WBFooter_Body__c = 'This is footer', 
            Header_Type__c = 'Text', 
            WBHeader_Body__c = 'Header text here', 
            Template_Miscellaneous_Data__c = '{"expireTime":3600,"isCodeExpiration":false}', 
            WBButton_Body__c = '[{"type":"URL","text":"Click Me","url":"https://test.com"}]'
        ));

        // Template with Image Header (Utility + expireTime)
        templates.add(new Template__c(
            Template_Name__c = 'Template2', 
            Template_Category__c = 'Utility', 
            Status__c = 'Active-Quality Pending', 
            Template_Id__c = 'testId2', 
            Language__c = 'en', 
            WBTemplate_Body__c = 'Utility body {{1}}', 
            Header_Type__c = 'Image', 
            WBHeader_Body__c = 'https://bucket.s3.amazonaws.com/test.png', 
            Template_Miscellaneous_Data__c = '{"expireTime":7200,"isCodeExpiration":false}', 
            WBButton_Body__c = '[{"type":"PHONE_NUMBER","text":"Call Us","phone_number":"+123456789"}]'
        ));

        // Template with Authentication category (Code Expiration Footer)
        templates.add(new Template__c(
            Template_Name__c = 'Template3', 
            Template_Category__c = 'Authentication', 
            Status__c = 'Active-Quality Pending', 
            Template_Id__c = 'testId3', 
            Language__c = 'en', 
            WBTemplate_Body__c = 'Auth body {{1}}', 
            Header_Type__c = 'Document', 
            WBHeader_Body__c = 'https://bucket.s3.amazonaws.com/doc.pdf', 
            Template_Miscellaneous_Data__c = '{"expireTime":300,"isCodeExpiration":true}', 
            WBButton_Body__c = '[{"type":"FLOW","text":"Start Flow","flow_id":"Flow0","navigate_screen":"screen1","flow_action":"action1"}]'
        ));

        insert templates;

        // Template Variables for Header and Body
        List<Template_Variable__c> variables = new List<Template_Variable__c>();
        for (Template__c template : templates){
            variables.add(new Template_Variable__c(
                Template__c = template.Id, 
                Name = '{{1}}', 
                Object_Name__c = 'Contact__c', 
                Field_Name__c = 'FirstName', 
                Type__c = 'Header', 
                Alternate_Text__c = 'Header Example'
            ));
            variables.add(new Template_Variable__c(
                Template__c = template.Id, 
                Name = '{{2}}', 
                Object_Name__c = 'Contact__c', 
                Field_Name__c = 'Name', 
                Type__c = 'Body', 
                Alternate_Text__c = 'Body Example'
            ));
        }
        insert variables;

        // Flows for FLOW button testing
        List<Flow__c> flows = new List<Flow__c>();
        for (Integer i = 0; i < 2; i++){
            flows.add(new Flow__c(
                Flow_Id__c = 'Flow' + i, 
                Flow_Name__c = 'Test Flow ' + i, 
                Flow_JSON__c = '{"key": "value"}', 
                Status__c = 'Published'
            ));
        }
        insert flows;

       
    }

    // Test Template1
    @isTest
    static void testTemplate1(){
        Test.setMock(HttpCalloutMock.class, new MockFlowTemplateHttpResponse());
        Test.startTest();
        List<Map<String, Object>> templateList = new List<Map<String, Object>>{ new Map<String, Object>{ 'action' => 'orgToMeta', 'selectedOrphanTemplateAction' => 'CreateToOrg', 'templateId' => 'testId', 'templateName' => 'Template1' } };
        Database.executeBatch(new SyncTemplateBatchClass(templateList));
        Test.stopTest();
    }

    // Test Template2
    @isTest
    static void testTemplate2(){
        Test.setMock(HttpCalloutMock.class, new MockFlowTemplateHttpResponse());
        Test.startTest();
        List<Map<String, Object>> templateList = new List<Map<String, Object>>{ new Map<String, Object>{ 'action' => 'orgToMeta', 'selectedOrphanTemplateAction' => 'CreateToOrg', 'templateId' => 'testId', 'templateName' => 'Template2' } };
        Database.executeBatch(new SyncTemplateBatchClass(templateList));
        Test.stopTest();
    }

    // Test Template3
    @isTest
    static void testTemplate3(){
        Test.setMock(HttpCalloutMock.class, new MockFlowTemplateHttpResponse());
        Test.startTest();
        List<Map<String, Object>> templateList = new List<Map<String, Object>>{ new Map<String, Object>{ 'action' => 'orgToMeta', 'selectedOrphanTemplateAction' => 'CreateToOrg', 'templateId' => 'testId', 'templateName' => 'Template3' } };
        Database.executeBatch(new SyncTemplateBatchClass(templateList));
        Test.stopTest();
    }

    // Test Template4
    @isTest
    static void testTemplate4(){
        Test.setMock(HttpCalloutMock.class, new MockFlowTemplateHttpResponse());
        Test.startTest();
        List<Map<String, Object>> templateList = new List<Map<String, Object>>{ new Map<String, Object>{ 'action' => 'orgToMeta', 'selectedOrphanTemplateAction' => 'CreateToOrg', 'templateId' => 'testId', 'templateName' => 'Template4' } };
        Database.executeBatch(new SyncTemplateBatchClass(templateList));
        Test.stopTest();
    }

    // Test Template5
    @isTest
    static void testTemplate5(){
        Test.setMock(HttpCalloutMock.class, new MockFlowTemplateHttpResponse());
        Test.startTest();
        List<Map<String, Object>> templateList = new List<Map<String, Object>>{ new Map<String, Object>{ 'action' => 'orgToMeta', 'selectedOrphanTemplateAction' => 'CreateToOrg', 'templateId' => 'testId', 'templateName' => 'Template5' } };
        Database.executeBatch(new SyncTemplateBatchClass(templateList));
        Test.stopTest();
    }

    // Test Flow Template (metaToOrgFlowTemplate)
    @isTest
    static void testFlowTemplate(){
        Test.setMock(HttpCalloutMock.class, new MockFlowTemplateHttpResponse());
        Test.startTest();
        List<Map<String, Object>> templateList = new List<Map<String, Object>>{ new Map<String, Object>{ 'action' => 'metaToOrg', 'selectedOrphanTemplateAction' => 'CreateToOrg', 'templateId' => null, 'templateName' => 'test_flow_template_1' } };
        Database.executeBatch(new SyncTemplateBatchClass(templateList));
        Test.stopTest();
    }

}