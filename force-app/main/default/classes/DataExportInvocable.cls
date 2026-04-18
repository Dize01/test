public with sharing class DataExportInvocable {
    private static final Integer DEFAULT_MAX_ROWS = 5000;

    public class Request {
        @InvocableVariable(required=true label='Object API Name' description='API name of the object to export, such as Account or Contact.')
        public String objectApiName;

        @InvocableVariable(required=true label='Field API Names' description='Comma-separated field API names to include in the CSV.')
        public String fieldApiNames;

        @InvocableVariable(required=true label='Record IDs' description='Comma-separated Salesforce record IDs to export.')
        public String recordIds;

        @InvocableVariable(label='File Name' description='Optional CSV file name. The .csv extension is added automatically when omitted.')
        public String fileName;

        @InvocableVariable(label='Maximum Rows' description='Optional maximum number of rows to export. Defaults to 5000.')
        public Integer maxRows;
    }

    public class Response {
        @InvocableVariable(label='Success')
        public Boolean success;

        @InvocableVariable(label='Message')
        public String message;

        @InvocableVariable(label='Rows Exported')
        public Integer rowsExported;

        @InvocableVariable(label='Content Version ID')
        public Id contentVersionId;

        @InvocableVariable(label='Content Document ID')
        public Id contentDocumentId;
    }

    @InvocableMethod(label='Export Records to CSV' description='Exports selected records to a CSV file that is saved in Salesforce Files.')
    public static List<Response> exportRecords(List<Request> requests) {
        List<Response> responses = new List<Response>();

        for (Request request : requests) {
            Response response = new Response();
            response.success = false;
            response.rowsExported = 0;

            try {
                ExportInput input = validateRequest(request);
                List<SObject> records = queryRecords(input);
                ContentVersion csvFile = createCsvFile(input, records);

                insert csvFile;

                ContentVersion insertedFile = [
                    SELECT Id, ContentDocumentId
                    FROM ContentVersion
                    WHERE Id = :csvFile.Id
                    LIMIT 1
                ];

                response.success = true;
                response.message = 'Export completed.';
                response.rowsExported = records.size();
                response.contentVersionId = insertedFile.Id;
                response.contentDocumentId = insertedFile.ContentDocumentId;
            } catch (Exception ex) {
                response.message = ex.getMessage();
            }

            responses.add(response);
        }

        return responses;
    }

    private static ExportInput validateRequest(Request request) {
        if (request == null) {
            throw new DataExportException('Request is required.');
        }

        String objectApiName = normalizeRequiredText(request.objectApiName, 'Object API Name');
        Map<String, Schema.SObjectType> globalDescribe = Schema.getGlobalDescribe();

        if (!globalDescribe.containsKey(objectApiName)) {
            throw new DataExportException('Object API Name is not valid: ' + objectApiName);
        }

        Schema.DescribeSObjectResult objectDescribe = globalDescribe.get(objectApiName).getDescribe();
        if (!objectDescribe.isAccessible()) {
            throw new DataExportException('You do not have access to object: ' + objectApiName);
        }

        Map<String, Schema.SObjectField> fieldsByName = objectDescribe.fields.getMap();
        List<String> fieldApiNames = parseCsvValues(request.fieldApiNames);

        if (fieldApiNames.isEmpty()) {
            throw new DataExportException('At least one field API name is required.');
        }

        for (String fieldApiName : fieldApiNames) {
            if (!fieldsByName.containsKey(fieldApiName)) {
                throw new DataExportException('Field API Name is not valid for ' + objectApiName + ': ' + fieldApiName);
            }

            if (!fieldsByName.get(fieldApiName).getDescribe().isAccessible()) {
                throw new DataExportException('You do not have access to field: ' + fieldApiName);
            }
        }

        Set<Id> recordIds = parseRecordIds(request.recordIds);
        if (recordIds.isEmpty()) {
            throw new DataExportException('At least one Record ID is required.');
        }

        Integer maxRows = request.maxRows == null || request.maxRows <= 0 ? DEFAULT_MAX_ROWS : request.maxRows;

        ExportInput input = new ExportInput();
        input.objectApiName = objectApiName;
        input.fieldApiNames = fieldApiNames;
        input.recordIds = recordIds;
        input.maxRows = maxRows;
        input.fileName = buildFileName(request.fileName, objectApiName);
        return input;
    }

    private static List<SObject> queryRecords(ExportInput input) {
        String soql = 'SELECT ' + String.join(input.fieldApiNames, ', ')
            + ' FROM ' + input.objectApiName
            + ' WHERE Id IN :recordIds'
            + ' ORDER BY Id'
            + ' LIMIT :maxRows';

        Set<Id> recordIds = input.recordIds;
        Integer maxRows = input.maxRows;
        return Database.query(soql);
    }

    private static ContentVersion createCsvFile(ExportInput input, List<SObject> records) {
        List<String> lines = new List<String>();
        lines.add(toCsvLine(input.fieldApiNames));

        for (SObject record : records) {
            List<String> values = new List<String>();
            for (String fieldApiName : input.fieldApiNames) {
                values.add(formatValue(record.get(fieldApiName)));
            }
            lines.add(toCsvLine(values));
        }

        ContentVersion csvFile = new ContentVersion();
        csvFile.Title = removeCsvExtension(input.fileName);
        csvFile.PathOnClient = input.fileName;
        csvFile.VersionData = Blob.valueOf(String.join(lines, '\n'));
        return csvFile;
    }

    private static String normalizeRequiredText(String value, String label) {
        if (String.isBlank(value)) {
            throw new DataExportException(label + ' is required.');
        }
        return value.trim();
    }

    private static List<String> parseCsvValues(String value) {
        List<String> results = new List<String>();
        if (String.isBlank(value)) {
            return results;
        }

        for (String item : value.split(',')) {
            if (!String.isBlank(item)) {
                results.add(item.trim());
            }
        }

        return results;
    }

    private static Set<Id> parseRecordIds(String value) {
        Set<Id> results = new Set<Id>();

        for (String item : parseCsvValues(value)) {
            try {
                results.add((Id) item);
            } catch (Exception ex) {
                throw new DataExportException('Record ID is not valid: ' + item);
            }
        }

        return results;
    }

    private static String buildFileName(String requestedFileName, String objectApiName) {
        String name = String.isBlank(requestedFileName)
            ? objectApiName + '_Export_' + Datetime.now().formatGmt('yyyyMMdd_HHmmss')
            : requestedFileName.trim();

        return name.toLowerCase().endsWith('.csv') ? name : name + '.csv';
    }

    private static String removeCsvExtension(String fileName) {
        return fileName.toLowerCase().endsWith('.csv') ? fileName.left(fileName.length() - 4) : fileName;
    }

    private static String formatValue(Object value) {
        return value == null ? '' : String.valueOf(value);
    }

    private static String toCsvLine(List<String> values) {
        List<String> escapedValues = new List<String>();
        for (String value : values) {
            escapedValues.add(escapeCsvValue(value));
        }
        return String.join(escapedValues, ',');
    }

    private static String escapeCsvValue(String value) {
        if (value == null) {
            return '';
        }

        Boolean requiresQuotes = value.contains(',') || value.contains('"') || value.contains('\n') || value.contains('\r');
        String escapedValue = value.replace('"', '""');
        return requiresQuotes ? '"' + escapedValue + '"' : escapedValue;
    }

    private class ExportInput {
        String objectApiName;
        List<String> fieldApiNames;
        Set<Id> recordIds;
        Integer maxRows;
        String fileName;
    }

    private class DataExportException extends Exception {
    }
}
