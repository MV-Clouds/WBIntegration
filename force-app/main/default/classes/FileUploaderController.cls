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
    @AuraEnabled
    public static String getPublicLink(String contentVersionId) {
        try {
            System.debug(contentVersionId);
            // Get the related ContentDocument Id
            ContentVersion contentVersion = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :contentVersionId LIMIT 1];
            
            // Create a new ContentDistribution (public link)
            ContentDistribution distribution = new ContentDistribution();
            distribution.Name = 'Public Link';
            distribution.ContentVersionId = contentVersion.Id;
            distribution.PreferencesAllowViewInBrowser= true;
                distribution.PreferencesLinkLatestVersion=true;
                distribution.PreferencesNotifyOnVisit=false;
                distribution.PreferencesPasswordRequired=false;
                distribution.PreferencesAllowOriginalDownload= true;

            insert distribution;
            
            // Query the created ContentDistribution to get the public URL
            distribution = [SELECT DistributionPublicUrl,ContentDownloadUrl FROM ContentDistribution WHERE Id = :distribution.Id LIMIT 1];
        
         // Return the public URL
            return distribution.ContentDownloadUrl;
        } catch (Exception e) {
            System.debug('❌ Error while creating public link: ' + e.getMessage());
            return 'Error: ' + e.getMessage();
        }
    }
}
