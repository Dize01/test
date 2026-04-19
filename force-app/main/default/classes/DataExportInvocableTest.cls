@IsTest
private class DataExportInvocableTest {
    @IsTest
    static void generateReturnsSuccessForAccount() {
        Account account = new Account(Name = 'Export Test Account');
        insert account;

        Contact contact = new Contact(
            LastName = 'Export Contact',
            AccountId = account.Id,
            MailingCity = 'Sydney',
            Description = 'Original description'
        );
        insert contact;

        DataExportInvocable.Request request = new DataExportInvocable.Request();
        request.recordId = account.Id;

        Test.startTest();
        List<DataExportInvocable.Response> responses = DataExportInvocable.generate(
            new List<DataExportInvocable.Request>{ request }
        );
        Test.stopTest();

        System.assertEquals(1, responses.size(), 'One response should be returned.');
        System.assertEquals(true, responses[0].success, responses[0].message);
        System.assertEquals('Data export batch started for Account: Export Test Account', responses[0].message);

        ContentDocumentLink accountFileLink = [
            SELECT ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :account.Id
            LIMIT 1
        ];

        ContentVersion csvFile = [
            SELECT VersionData
            FROM ContentVersion
            WHERE ContentDocumentId = :accountFileLink.ContentDocumentId
            LIMIT 1
        ];

        String csv = csvFile.VersionData.toString();
        System.assert(csv.contains('Id,Name,MailingStreet,MailingCity,MailingState,MailingPostalCode,MailingCountry,Description'));
        System.assert(csv.contains('Export Contact'), 'The CSV should include the Contact name.');
        System.assert(csv.contains('Sydney'), 'The CSV should include the Contact address fields.');
        System.assert(csv.contains('Original description'), 'The CSV should include the Contact description.');
    }

    @IsTest
    static void generateReturnsErrorWhenRecordIdIsMissing() {
        DataExportInvocable.Request request = new DataExportInvocable.Request();

        Test.startTest();
        List<DataExportInvocable.Response> responses = DataExportInvocable.generate(
            new List<DataExportInvocable.Request>{ request }
        );
        Test.stopTest();

        System.assertEquals(1, responses.size(), 'One response should be returned.');
        System.assertEquals(false, responses[0].success, 'Missing input should return an error response.');
        System.assertEquals('Record ID is required.', responses[0].message);
    }
}
