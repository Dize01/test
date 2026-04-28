@IsTest
public class TestDataFactory {
    public static void setupData() {
        Account account = new Account(Name = 'Test Account');
        insert account;

        insert new List<Contact>{
            new Contact(LastName = 'First', AccountId = account.Id, MailingCity = 'Sydney', Description = 'First description'),
            new Contact(LastName = 'Second', AccountId = account.Id, MailingCity = 'Melbourne', Description = 'Second description')
        };
    }

    public static Account createAccount(String name) {
        Account account = new Account(Name = name);
        insert account;
        return account;
    }

    public static Contact createContact(Id accountId, String lastName, String mailingCity, String description) {
        Contact contact = new Contact(
            LastName = lastName,
            AccountId = accountId,
            MailingCity = mailingCity,
            Description = description
        );
        insert contact;
        return contact;
    }

    public static List<Contact> createContacts(List<Contact> contacts) {
        insert contacts;
        return contacts;
    }
}
