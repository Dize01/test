@IsTest
private class DataExportBatchableTest {
    @TestSetup
    static void setupData() {
        TestDataFactory.setupData();
    }

    @IsTest
    static void batchCreatesCsvForAccount() {
        Account account = [SELECT Id FROM Account LIMIT 1];

        Test.startTest();
        String query = 'SELECT Id, Name, MailingStreet, MailingCity, MailingState, MailingPostalCode, MailingCountry, Description FROM Contact WHERE AccountId = \''
            + account.Id
            + '\'';
        Database.executeBatch(new DataExportBatchable(account.Id, query, 'test@example.com'), 200);
        Test.stopTest();

        ContentDocumentLink accountFileLink = [
            SELECT ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :account.Id
            LIMIT 1
        ];

        ContentVersion csvFile = [
            SELECT Title, PathOnClient, VersionData
            FROM ContentVersion
            WHERE ContentDocumentId = :accountFileLink.ContentDocumentId
            LIMIT 1
        ];

        String csv = csvFile.VersionData.toString();
        System.assertEquals('Data Export_1', csvFile.Title);
        System.assertEquals('DataExport_1.csv', csvFile.PathOnClient);
        System.assert(csv.contains('Id,Name,MailingStreet,MailingCity,MailingState,MailingPostalCode,MailingCountry,Description'));
        System.assert(csv.contains('First'), 'The CSV should include the first Contact.');
        System.assert(csv.contains('Second'), 'The CSV should include the second Contact.');
        System.assert(csv.contains('Sydney'), 'The CSV should include address fields.');
        System.assert(csv.contains('First description'), 'The CSV should include descriptions.');
    }
}
