public class EmojiDataController {
    @AuraEnabled(cacheable=true)
    public static String getEmojiData() {
        Http http = new Http();
        HttpRequest request = new HttpRequest();
        request.setEndpoint('https://cdn.jsdelivr.net/npm/emoji-picker-element-data@1/en/emojibase/data.json');
        request.setMethod('GET');

        try {
            HttpResponse response = http.send(request);
            if (response.getStatusCode() == 200) {
                System.debug(response.getBody());
                return response.getBody();
            } else {
                throw new AuraHandledException('Error fetching emoji data: ' + response.getStatus());
            }
        } catch (Exception e) {
            ExceptionLog.exception(e.getMessage(), 'EmojiDataController', 'getEmojiData',e.getLineNumber());
            System.debug('Error in getEmojiData: ' + e.getMessage() + '\n' + e + '\n Exception line no: ' + e.getLineNumber());
            return null;
        }
    }
}