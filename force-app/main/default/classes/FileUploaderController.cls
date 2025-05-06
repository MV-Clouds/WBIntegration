public with sharing class FileUploaderController {

    /**
     * @description Wrapper class to return both ContentVersion Id and its Public Link
     */
    public class FileUploadResponse {
        @AuraEnabled public String contentVersionId; // ID of the uploaded ContentVersion
        @AuraEnabled public String publicLink;       // Public download URL for the file

        public FileUploadResponse(String id, String link) {
            this.contentVersionId = id;
            this.publicLink = link;
        }
    }

    /**
     * @description Uploads a file to Salesforce as a ContentVersion and generates a public link.
     * @param base64Data Base64-encoded string of the file data
     * @param fileName Name of the file to be saved
     * @return FileUploadResponse object containing ContentVersion Id and public URL
     */
    @AuraEnabled
    public static FileUploadResponse uploadFile(String base64Data, String fileName) {
        try {
            ContentVersion cv = new ContentVersion();
            cv.Title = fileName;
            cv.PathOnClient = '/' + fileName;
            cv.VersionData = EncodingUtil.base64Decode(base64Data);
            insert cv;

            String publicLink = getPublicLink(cv.Id); // Generate the public link for download
            return new FileUploadResponse(cv.Id, publicLink);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * @description Deletes the file from Salesforce based on the ContentVersion Id.
     * @param contentVersionId Id of the ContentVersion to delete
     * @return Success or error message
     */
    @AuraEnabled
    public static String deleteFile(String contentVersionId) {
        try {
            List<ContentDocument> docs = [
                SELECT Id
                FROM ContentDocument
                WHERE LatestPublishedVersionId = :contentVersionId
                LIMIT 1
            ];

            if (!docs.isEmpty()) {
                delete docs; // Deleting ContentDocument also deletes associated ContentVersions
                return 'File deleted successfully!';
            } else {
                return 'No file found to delete.';
            }
        } catch (Exception e) {
            throw new AuraHandledException('Error deleting file: ' + e.getMessage());
        }
    }

    /**
     * @description Generates and returns a public download link for a given ContentVersion Id.
     * @param contentVersionId Id of the ContentVersion
     * @return Public download URL as a string
     */
    @AuraEnabled
    public static String getPublicLink(String contentVersionId) {
        try {
            // Get ContentDocumentId using ContentVersion Id
            ContentVersion contentVersion = [
                SELECT ContentDocumentId 
                FROM ContentVersion 
                WHERE Id = :contentVersionId 
                LIMIT 1
            ];

            // Create a ContentDistribution record to make the file publicly accessible
            ContentDistribution distribution = new ContentDistribution();
            distribution.Name = 'Public Link';
            distribution.ContentVersionId = contentVersion.Id;
            distribution.PreferencesAllowViewInBrowser = true;
            distribution.PreferencesLinkLatestVersion = true;
            distribution.PreferencesNotifyOnVisit = false;
            distribution.PreferencesPasswordRequired = false;
            distribution.PreferencesAllowOriginalDownload = true;

            insert distribution;

            // Query back the distribution record to fetch public URL
            distribution = [
                SELECT DistributionPublicUrl, ContentDownloadUrl 
                FROM ContentDistribution 
                WHERE Id = :distribution.Id 
                LIMIT 1
            ];

            return distribution.ContentDownloadUrl;
        } catch (Exception e) {
            // Optional: log the error using a custom exception handler
            ExceptionHandler.logException(new Map<String, Object>{
                'className' => 'FileUploaderController',
                'methodName' => 'getPublicLink',
                'exceptionObj' => e,
                'isApiException' => false,
                'statusCode' => null,
                'chatId' => null,
                'moreDetails' => e.getMessage(),
                'apiResponse' => null
            });
            return 'Error: ' + e.getMessage();
        }
    }
}
