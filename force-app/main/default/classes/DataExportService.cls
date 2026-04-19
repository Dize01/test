public with sharing class DataExportService {
    public static void createCsvFile(Id parentRecordId, List<String> fieldApiNames, List<SObject> records) {
        createCsvFile(parentRecordId, fieldApiNames, records, null);
    }

    public static void createCsvFile(Id parentRecordId, List<String> fieldApiNames, List<SObject> records, Integer fileNumber) {
        List<String> csvRows = new List<String>{ toCsvLine(fieldApiNames) };

        for (SObject record : records) {
            List<String> values = new List<String>();

            for (String fieldApiName : fieldApiNames) {
                values.add(formatValue(record.get(fieldApiName)));
            }

            csvRows.add(toCsvLine(values));
        }

        ContentVersion csvFile = new ContentVersion();
        csvFile.Title = getTitle(fileNumber);
        csvFile.PathOnClient = getPathOnClient(fileNumber);
        csvFile.FirstPublishLocationId = parentRecordId;
        csvFile.VersionData = Blob.valueOf(String.join(csvRows, '\n'));

        insert csvFile;
    }

    private static String getTitle(Integer fileNumber) {
        return 'Data Export' + getFileSuffix(fileNumber);
    }

    private static String getPathOnClient(Integer fileNumber) {
        return 'DataExport' + getFileSuffix(fileNumber) + '.csv';
    }

    private static String getFileSuffix(Integer fileNumber) {
        return fileNumber == null ? '' : '_' + String.valueOf(fileNumber);
    }

    public static List<String> extractFieldApiNames(String query) {
        String normalizedQuery = query.replace('\n', ' ').replace('\r', ' ');
        Integer selectIndex = normalizedQuery.toLowerCase().indexOf('select ');
        Integer fromIndex = normalizedQuery.toLowerCase().indexOf(' from ');

        if (selectIndex < 0 || fromIndex < 0 || fromIndex <= selectIndex) {
            throw new DataExportException('Query must include SELECT and FROM clauses.');
        }

        String selectedFields = normalizedQuery.substring(selectIndex + 7, fromIndex);
        List<String> fieldApiNames = new List<String>();

        for (String fieldApiName : selectedFields.split(',')) {
            if (!String.isBlank(fieldApiName)) {
                fieldApiNames.add(fieldApiName.trim());
            }
        }

        return fieldApiNames;
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

    private class DataExportException extends Exception {
    }
}
