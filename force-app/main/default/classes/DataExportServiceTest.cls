@IsTest
private class DataExportServiceTest {
    @TestSetup
    static void setupData() {
        TestDataFactory.setupData();
    }

    // createCsvFile - no file number

    @IsTest
    static void createCsvFileCreatesFileWithNoSuffix() {
        Account account = [SELECT Id FROM Account LIMIT 1];
        List<Contact> contacts = [SELECT Id, LastName, MailingCity FROM Contact WHERE AccountId = :account.Id];

        Test.startTest();
        DataExportService.createCsvFile(account.Id, new List<String>{ 'LastName', 'MailingCity' }, contacts);
        Test.stopTest();

        ContentDocumentLink link = [SELECT ContentDocumentId FROM ContentDocumentLink WHERE LinkedEntityId = :account.Id LIMIT 1];
        ContentVersion csvFile = [SELECT Title, PathOnClient, VersionData FROM ContentVersion WHERE ContentDocumentId = :link.ContentDocumentId LIMIT 1];

        System.assertEquals('Data Export', csvFile.Title);
        System.assertEquals('DataExport.csv', csvFile.PathOnClient);

        String csv = csvFile.VersionData.toString();
        System.assert(csv.contains('LastName,MailingCity'), 'CSV should contain the header row.');
        System.assert(csv.contains('First'), 'CSV should contain the first contact.');
        System.assert(csv.contains('Sydney'), 'CSV should contain the city field.');
    }

    // createCsvFile - with file number

    @IsTest
    static void createCsvFileCreatesFileWithNumberedSuffix() {
        Account account = [SELECT Id FROM Account LIMIT 1];
        List<Contact> contacts = [SELECT Id, LastName FROM Contact WHERE AccountId = :account.Id];

        Test.startTest();
        DataExportService.createCsvFile(account.Id, new List<String>{ 'LastName' }, contacts, 2);
        Test.stopTest();

        ContentDocumentLink link = [SELECT ContentDocumentId FROM ContentDocumentLink WHERE LinkedEntityId = :account.Id LIMIT 1];
        ContentVersion csvFile = [SELECT Title, PathOnClient FROM ContentVersion WHERE ContentDocumentId = :link.ContentDocumentId LIMIT 1];

        System.assertEquals('Data Export_2', csvFile.Title);
        System.assertEquals('DataExport_2.csv', csvFile.PathOnClient);
    }

    // createCsvFile - CSV escaping

    @IsTest
    static void createCsvFileQuotesValuesContainingCommas() {
        Account account = [SELECT Id FROM Account LIMIT 1];
        Contact contact = TestDataFactory.createContact(account.Id, 'Comma', 'Sydney', 'value, with comma');
        List<Contact> contacts = [SELECT Id, LastName, Description FROM Contact WHERE Id = :contact.Id];

        Test.startTest();
        DataExportService.createCsvFile(account.Id, new List<String>{ 'LastName', 'Description' }, contacts);
        Test.stopTest();

        ContentDocumentLink link = [SELECT ContentDocumentId FROM ContentDocumentLink WHERE LinkedEntityId = :account.Id LIMIT 1];
        ContentVersion csvFile = [SELECT VersionData FROM ContentVersion WHERE ContentDocumentId = :link.ContentDocumentId LIMIT 1];

        System.assert(csvFile.VersionData.toString().contains('"value, with comma"'), 'Values containing commas should be wrapped in quotes.');
    }

    @IsTest
    static void createCsvFileEscapesQuoteCharacters() {
        Account account = [SELECT Id FROM Account LIMIT 1];
        Contact contact = TestDataFactory.createContact(account.Id, 'Quoted', 'Sydney', 'value with "quotes"');
        List<Contact> contacts = [SELECT Id, LastName, Description FROM Contact WHERE Id = :contact.Id];

        Test.startTest();
        DataExportService.createCsvFile(account.Id, new List<String>{ 'LastName', 'Description' }, contacts);
        Test.stopTest();

        ContentDocumentLink link = [SELECT ContentDocumentId FROM ContentDocumentLink WHERE LinkedEntityId = :account.Id LIMIT 1];
        ContentVersion csvFile = [SELECT VersionData FROM ContentVersion WHERE ContentDocumentId = :link.ContentDocumentId LIMIT 1];

        System.assert(csvFile.VersionData.toString().contains('"value with ""quotes"""'), 'Quote characters should be doubled and the value wrapped in quotes.');
    }

    @IsTest
    static void createCsvFileRendersNullFieldsAsEmpty() {
        Account account = [SELECT Id FROM Account LIMIT 1];
        Contact contact = TestDataFactory.createContact(account.Id, 'NoDesc', 'Sydney', null);
        List<Contact> contacts = [SELECT Id, LastName, Description FROM Contact WHERE Id = :contact.Id];

        Test.startTest();
        DataExportService.createCsvFile(account.Id, new List<String>{ 'LastName', 'Description' }, contacts);
        Test.stopTest();

        ContentDocumentLink link = [SELECT ContentDocumentId FROM ContentDocumentLink WHERE LinkedEntityId = :account.Id LIMIT 1];
        ContentVersion csvFile = [SELECT VersionData FROM ContentVersion WHERE ContentDocumentId = :link.ContentDocumentId LIMIT 1];

        System.assert(csvFile.VersionData.toString().contains('NoDesc,'), 'Null field values should produce an empty CSV column.');
    }

    // extractFieldApiNames

    @IsTest
    static void extractFieldApiNamesReturnsFieldsFromValidQuery() {
        List<String> fields = DataExportService.extractFieldApiNames('SELECT Id, Name, Email FROM Contact');

        System.assertEquals(3, fields.size());
        System.assertEquals('Id', fields[0]);
        System.assertEquals('Name', fields[1]);
        System.assertEquals('Email', fields[2]);
    }

    @IsTest
    static void extractFieldApiNamesHandlesMultilineQuery() {
        List<String> fields = DataExportService.extractFieldApiNames('SELECT Id, Name\nFROM Contact');

        System.assertEquals(2, fields.size());
        System.assertEquals('Id', fields[0]);
        System.assertEquals('Name', fields[1]);
    }

    @IsTest
    static void extractFieldApiNamesThrowsWhenSelectClauseIsMissing() {
        try {
            DataExportService.extractFieldApiNames('Id, Name FROM Contact');
            System.assert(false, 'Expected exception was not thrown.');
        } catch (Exception e) {
            System.assertEquals('Query must include SELECT and FROM clauses.', e.getMessage());
        }
    }

    @IsTest
    static void extractFieldApiNamesThrowsWhenFromClauseIsMissing() {
        try {
            DataExportService.extractFieldApiNames('SELECT Id, Name');
            System.assert(false, 'Expected exception was not thrown.');
        } catch (Exception e) {
            System.assertEquals('Query must include SELECT and FROM clauses.', e.getMessage());
        }
    }
}
