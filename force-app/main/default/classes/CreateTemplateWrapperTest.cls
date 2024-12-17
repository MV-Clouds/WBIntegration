@isTest
public class CreateTemplateWrapperTest{
    static CreateTemplateWrapper.TemplateWrapper templateWrapper;

    @testSetup
    static void setupTestData() {
        templateWrapper = new CreateTemplateWrapper.TemplateWrapper(); 
        templateWrapper.templateName = 'WB Template';
        templateWrapper.tempLanguage = 'en';
        templateWrapper.templateCategory = 'Marketing';
        templateWrapper.templateType = 'Email';
        templateWrapper.tempHeaderFormat = 'Plain';
        templateWrapper.tempHeaderHandle = 'header1';
        templateWrapper.tempHeaderText = 'Welcome to WB Template';
        templateWrapper.tempHeaderExample = new List<String>{'Header Example 1', 'Header Example 2'};
        templateWrapper.headAlternateTexts = new List<String>{'Alt Text 1', 'Alt Text 2'};
        templateWrapper.varAlternateTexts = new List<String>{'Var Text 1', 'Var Text 2'};
        templateWrapper.templateBody = 'This is a sample body';
        templateWrapper.templateBodyText = new List<String>{'Body Text 1', 'Body Text 2'};
        templateWrapper.tempFooterText = 'Footer Text';
        templateWrapper.typeOfButton = 'Submit';
        templateWrapper.buttonPhoneText = 'Call Us';
        templateWrapper.phoneNumber = '1234567890';
        templateWrapper.buttonURLText = 'Visit Website';
        templateWrapper.url = 'http://example.com';
        templateWrapper.quickText = 'Quick Message';
        templateWrapper.copyCode = 'COPY123';
        templateWrapper.tempImgUrl = 'http://example.com/image.png';
        
        // Debug statement to confirm field values
        System.debug('TemplateWrapper: ' + templateWrapper);
    }    
    
    // Test method for buildPayload
    @isTest
    static void testBuildPayload() {
        Map<String, Object> result = CreateTemplateWrapper.buildPayload(templateWrapper);
        System.debug('Template Wrapper Before: ' + templateWrapper);  
        System.debug('result '+result);
        if (result == null) {
            templateWrapper = new CreateTemplateWrapper.TemplateWrapper();
            templateWrapper.templateName = 'WB Template';
            templateWrapper.tempLanguage = 'en';
            templateWrapper.templateCategory = 'Marketing';
        }
        System.assertNotEquals(result, null, 'The result should not be null');
        System.assertEquals(result.get('name'), 'WB Template', 'The template name should match');
        System.assertEquals(result.get('language'), 'en', 'The language should match');
        System.assertEquals(result.get('category'), 'Marketing', 'The category should match');
        
        if (result.containsKey('components')) {
            List<Map<String, Object>> components = (List<Map<String, Object>>) result.get('components');
            System.assertNotEquals(components.size(), 0, 'The components list should not be empty');
        }
    }

    @isTest
    public static void testBuildPayloadException() {
        Map<String, Object> result = CreateTemplateWrapper.buildPayload(null);   
        System.assertEquals(result.size(), 0, 'The result should be an empty map in case of an exception');
    }
    }
    
