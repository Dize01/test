public with sharing class DataExportBatchable implements Database.Batchable<SObject>, Database.Stateful {
    private final Id recordId;
    private final String query;
    private final String email;
    private final List<String> fieldApiNames;
    private Integer fileNumber;
    private List<String> csvRows;
    private Integer currentBytes;

    private static final Integer FLUSH_THRESHOLD = 8388608; // 8 MB

    public DataExportBatchable(Id recordId, String query, String email) {
        this.recordId = recordId;
        this.query = query;
        this.email = email;
        this.fieldApiNames = DataExportService.extractFieldApiNames(query);
        this.fileNumber = 0;
        this.csvRows = new List<String>();
        this.currentBytes = 0;
    }

    public Database.QueryLocator start(Database.BatchableContext context) {
        return Database.getQueryLocator(query);
    }

    public void execute(Database.BatchableContext context, List<SObject> scope) {
        for (SObject record : scope) {
            String row = DataExportService.buildCsvRow(fieldApiNames, record);
            csvRows.add(row);
            currentBytes += Blob.valueOf(row + '\n').size();
        }

        if (currentBytes >= FLUSH_THRESHOLD) {
            flush();
        }
    }

    public void finish(Database.BatchableContext context) {
        if (!csvRows.isEmpty()) {
            flush();
        }
    }

    private void flush() {
        fileNumber++;
        DataExportService.createCsvFile(recordId, fieldApiNames, csvRows, fileNumber);
        csvRows = new List<String>();
        currentBytes = 0;
    }
}
