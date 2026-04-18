@IsTest
private class DataExportInvocableTest {
    @IsTest
    static void exportRecordsCreatesCsvFile() {
        Account account = new Account(Name = 'Export Test Account');
        insert account;

        DataExportInvocable.Request request = new DataExportInvocable.Request();
        request.objectApiName = 'Account';
        request.fieldApiNames = 'Id,Name';
        request.recordIds = account.Id;
        request.fileName = 'AccountExport';

        Test.startTest();
        List<DataExportInvocable.Response> responses = DataExportInvocable.exportRecords(
            new List<DataExportInvocable.Request>{ request }
        );
        Test.stopTest();

        System.assertEquals(1, responses.size(), 'One response should be returned.');
        System.assertEquals(true, responses[0].success, responses[0].message);
        System.assertEquals(1, responses[0].rowsExported, 'One account should be exported.');
        System.assertNotEquals(null, responses[0].contentVersionId, 'A file version should be created.');
        System.assertNotEquals(null, responses[0].contentDocumentId, 'A file document should be created.');

        ContentVersion csvFile = [
            SELECT Title, PathOnClient, VersionData
            FROM ContentVersion
            WHERE Id = :responses[0].contentVersionId
            LIMIT 1
        ];

        String csv = csvFile.VersionData.toString();
        System.assertEquals('AccountExport', csvFile.Title, 'The file title should omit the extension.');
        System.assertEquals('AccountExport.csv', csvFile.PathOnClient, 'The file path should include the extension.');
        System.assert(csv.contains('Id,Name'), 'The CSV should include a header row.');
        System.assert(csv.contains('Export Test Account'), 'The CSV should include exported data.');
    }

    @IsTest
    static void exportRecordsReturnsValidationError() {
        DataExportInvocable.Request request = new DataExportInvocable.Request();
        request.objectApiName = 'NotARealObject__c';
        request.fieldApiNames = 'Name';
        request.recordIds = UserInfo.getUserId();

        Test.startTest();
        List<DataExportInvocable.Response> responses = DataExportInvocable.exportRecords(
            new List<DataExportInvocable.Request>{ request }
        );
        Test.stopTest();

        System.assertEquals(1, responses.size(), 'One response should be returned.');
        System.assertEquals(false, responses[0].success, 'Invalid input should return an error response.');
        System.assert(responses[0].message.contains('Object API Name is not valid'), responses[0].message);
    }
}
