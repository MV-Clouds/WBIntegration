public with sharing class FileUploaderController {
    @AuraEnabled
    public static String uploadFile(String base64Data, String fileName) {
        try {
            ContentVersion cv = new ContentVersion();
            cv.Title = fileName;
            cv.PathOnClient = '/' + fileName;
            cv.VersionData = EncodingUtil.base64Decode(base64Data);
            insert cv;

            // Return the Id of the inserted ContentVersion
            return cv.Id;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static String deleteFile(String contentVersionId) {
        try {
            System.debug('Deleting ContentVersion with Id: ' + contentVersionId);

            // Get related ContentDocument
            List<ContentDocument> docs = [
                SELECT Id
                FROM ContentDocument
                WHERE LatestPublishedVersionId = :contentVersionId
                LIMIT 1
            ];
            System.debug(docs.size());
            if (!docs.isEmpty()) {
                Id contentDocumentId = docs[0].Id;
                
                System.debug(contentDocumentId);
                // Delete the ContentDocument (deletes related ContentVersion)
                delete docs;
                System.debug('File deleted successfully.');
                return 'File deleted successfully!';
            } else {
                return 'No file found to delete.';
            }
        } catch (Exception e) {
            System.debug('Error deleting file: ' + e.getMessage());
            throw new AuraHandledException('Error deleting file: ' + e.getMessage());
        }
    }
}
