public class EmailWithTemplateService {

    public static void sendTemplatedEmail(String toAddress, String templateName, Id whatId, Id targetObjectId) {

        EmailTemplate template = [
            SELECT Id, Subject, Body, HtmlValue
            FROM EmailTemplate
            WHERE DeveloperName = :templateName
            LIMIT 1
        ];

        OrgWideEmailAddress orgWideAddress = [
            SELECT Id FROM OrgWideEmailAddress 
            WHERE Address = 'noreply@lala.com' LIMIT 1
        ];

        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();

        mail.setToAddresses(new List<String>{ toAddress });
        mail.setTemplateId(template.Id);          // Let Salesforce render merge fields
        mail.setWhatId(whatId);                   // Object record for {!Object.Field} merges
        mail.setTargetObjectId(targetObjectId);   // Contact/Lead/User for {!recipient.} merges
        mail.setSaveAsActivity(false);            // Set true if you want an Activity logged
        mail.setOrgWideEmailAddressId(orgWideAddress.Id);

        List<Messaging.SendEmailResult> results = Messaging.sendEmail(
            new List<Messaging.SingleEmailMessage>{ mail }
        );

        handleResults(results);
    }

    private static void handleResults(List<Messaging.SendEmailResult> results) {
        for (Messaging.SendEmailResult result : results) {
            if (!result.isSuccess()) {
                for (Messaging.SendEmailError error : result.getErrors()) {
                    System.debug('Email send failed: ' + error.getMessage());
                }
                //Logger.error('Email Notification Failed');
                //Logger.saveLog();
            } else {
                System.debug('Email sent successfully.');
            }
        }
    }
}