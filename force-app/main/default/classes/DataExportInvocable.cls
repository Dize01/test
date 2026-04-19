public with sharing class DataExportInvocable {
    public class Request {
        @InvocableVariable(required=true label='Record ID' description='Account record ID to process.')
        public Id recordId;
    }

    public class Response {
        @InvocableVariable(label='Success')
        public Boolean success;

        @InvocableVariable(label='Message')
        public String message;
    }

    @InvocableMethod(label='Generate Data Export' description='Generates a data export for the supplied Account record.')
    public static List<Response> generate(List<Request> requests) {
        List<Response> responses = new List<Response>();

        if (requests == null) {
            return responses;
        }

        for (Request request : requests) {
            Response response = new Response();
            response.success = false;

            if (request == null || request.recordId == null) {
                response.message = 'Record ID is required.';
                responses.add(response);
                continue;
            }

            List<Account> accounts = [
                SELECT Id, Name, Email__c
                FROM Account
                WHERE Id = :request.recordId
                LIMIT 1
            ];

            if (accounts.isEmpty()) {
                response.message = 'No Account found for the supplied Record ID.';
            } else {
                String query = 'SELECT Id, Name, MailingStreet, MailingCity, MailingState, MailingPostalCode, MailingCountry, Description FROM Contact WHERE AccountId = \''
                    + String.escapeSingleQuotes(String.valueOf(request.recordId))
                    + '\'';
                Object emailValue = accounts[0].get('Email__c');
                String email = emailValue == null ? null : String.valueOf(emailValue);

                Database.executeBatch(new DataExportBatchable(request.recordId, query, email), 1);
                response.success = true;
                response.message = 'Data export batch started for Account: ' + accounts[0].Name;
            }

            responses.add(response);
        }

        return responses;
    }
}
