@IsTest
private class DataExportBatchableTest {
    @IsTest
    static void batchCreatesCsvForAccount() {
        Account account = new Account(Name = 'Batch Export Account');
        insert account;

        Contact firstContact = new Contact(
            LastName = 'First',
            AccountId = account.Id,
            MailingCity = 'Sydney',
            Description = 'First description'
        );
        Contact secondContact = new Contact(
            LastName = 'Second',
            AccountId = account.Id,
            MailingCity = 'Melbourne',
            Description = 'Second description'
        );
        insert new List<Contact>{ firstContact, secondContact };

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
