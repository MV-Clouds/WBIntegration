@isTest
public class CreateTemplateWrapperTest{

     @isTest
    static void testBuildPayload() {
        CreateTemplateWrapper.TemplateWrapper templateWrapper = new CreateTemplateWrapper.TemplateWrapper(); 
        templateWrapper.templateName = 'WB Template';
        templateWrapper.tempLanguage = 'en';
        templateWrapper.templateCategory = 'Marketing';
        templateWrapper.templateType = 'Email';
        templateWrapper.tempHeaderFormat = 'Text';
        templateWrapper.tempHeaderHandle = 'header1';
        templateWrapper.tempHeaderText = 'Welcome to WB Template';
        templateWrapper.tempHeaderExample = new List<String>{'Header Example 1', 'Header Example 2'};
        templateWrapper.headAlternateTexts = new List<String>{'Alt Text 1', 'Alt Text 2'};
        templateWrapper.varAlternateTexts = new List<String>{'Var Text 1', 'Var Text 2'};
        templateWrapper.templateBody = 'This is a sample body';
        templateWrapper.templateBodyText = new List<String>{'Body Text 1', 'Body Text 2'};
        templateWrapper.tempFooterText = 'Footer Text';
        templateWrapper.typeOfButton = '[{\"id\":1,\"selectedActionType\":\"PHONE_NUMBER\",\"iconName\":\"utility:call\",\"btntext\":\"Call Phone Number\",\"webURL\":\"\",\"phonenum\":\"1231123123\",\"offercode\":\"\",\"selectedUrlType\":\"Static\",\"selectedCountryType\":\"+682\",\"isCallPhone\":true,\"isVisitSite\":false,\"isOfferCode\":false,\"hasError\":false,\"errorMessage\":\"\",\"isDisabled\":false}]';
        templateWrapper.buttonPhoneText = 'Call Us';
        templateWrapper.phoneNumber = '1234567890';
        templateWrapper.buttonURLText = 'Visit Website';
        templateWrapper.url = 'http://example.com';
        templateWrapper.quickText = 'Quick Message';
        templateWrapper.copyCode = 'COPY123';
        templateWrapper.tempImgUrl = 'http://example.com/image.png';
        
        // Debug statement to confirm field values
        System.debug('TemplateWrapper: ' + templateWrapper);
        CreateTemplateWrapper.buildPayload(templateWrapper);

        templateWrapper.tempHeaderFormat = 'Image';
        templateWrapper.typeOfButton = '[{\"id\":1,\"selectedActionType\":\"QUICK_REPLY\",\"iconName\":\"utility:call\",\"btntext\":\"Call Phone Number\",\"webURL\":\"\",\"phonenum\":\"1231123123\",\"offercode\":\"\",\"selectedUrlType\":\"Static\",\"selectedCountryType\":\"+682\",\"isCallPhone\":true,\"isVisitSite\":false,\"isOfferCode\":false,\"hasError\":false,\"errorMessage\":\"\",\"isDisabled\":false}]';
        CreateTemplateWrapper.buildPayload(templateWrapper);
        templateWrapper.typeOfButton = '[{\"id\":1,\"selectedActionType\":\"URL\",\"iconName\":\"utility:call\",\"btntext\":\"Call Phone Number\",\"webURL\":\"\",\"phonenum\":\"1231123123\",\"offercode\":\"\",\"selectedUrlType\":\"Static\",\"selectedCountryType\":\"+682\",\"isCallPhone\":true,\"isVisitSite\":false,\"isOfferCode\":false,\"hasError\":false,\"errorMessage\":\"\",\"isDisabled\":false}]';
        CreateTemplateWrapper.buildPayload(templateWrapper);
        templateWrapper.typeOfButton = '[{\"id\":1,\"selectedActionType\":\"COPY_CODE\",\"iconName\":\"utility:call\",\"btntext\":\"Call Phone Number\",\"webURL\":\"\",\"phonenum\":\"1231123123\",\"offercode\":\"\",\"selectedUrlType\":\"Static\",\"selectedCountryType\":\"+682\",\"isCallPhone\":true,\"isVisitSite\":false,\"isOfferCode\":false,\"hasError\":false,\"errorMessage\":\"\",\"isDisabled\":false}]';
        CreateTemplateWrapper.buildPayload(templateWrapper);
        templateWrapper.typeOfButton = '[{\"id\":1,\"selectedActionType\":\"Marketing opt-out\"}]';
        CreateTemplateWrapper.buildPayload(templateWrapper);

        HttpResponse res = new HttpResponse();
        res.setStatusCode(200);
        res.setBody('{\"success\": true}');

        Map<String, Object> payload = new Map<String, Object>();

        // Adding data to the map
        payload.put('category', 'Marketing');
        payload.put('language', 'en_US');
        payload.put('name', 'test_temp_55');

        // Adding components as a list of maps
        payload.put('components', new List<Map<String, Object>> {
            new Map<String, Object> { 'format' => 'Image', 'type' => 'HEADER', 'text' => 'something \\{\\{(\\d+)\\}\\} ', 'example' => new Map<String, Object>{'header_text' => new List<Object> {'some{{1}}thing', 'something2'}, 'body_text' => new List<Object> {'some {{3}}thing', 'something2'}} },
            new Map<String, Object> { 'text' => 'HelloThis is Sample.', 'type' => 'BODY', 'bodyText' => 'Something text' },
            new Map<String, Object> {
                'buttons' => new List<Map<String, Object>> {
                    new Map<String, Object> { 'text' => 'Quick reply', 'type' => 'QUICK_REPLY' }
                },
                'type' => 'BUTTONS'
            },
            new Map<String, Object> { 'format' => 'text', 'type' => 'HEADER'}
        });

        Map<String, Object> response = new Map<String, Object>();
        response.put('success', 'true');
        response.put('is', 'someId');
        CreateTemplateWrapper.handleSuccessResponse(res, payload, response, templateWrapper);

    }

    static void testHandleSuccessResponse(){
        
        
        
    }


    @isTest
    public static void testBuildPayloadException() {
        Map<String, Object> result = CreateTemplateWrapper.buildPayload(null);   
        System.assertEquals(result.size(), 0, 'The result should be an empty map in case of an exception');
    }
    }