public with sharing class DataExportBatchable implements Database.Batchable<SObject>, Database.Stateful {
    private final Id recordId;
    private final String query;
    private final String email;
    private final List<String> fieldApiNames;
    private Integer fileNumber;

    public DataExportBatchable(Id recordId, String query, String email) {
        this.recordId = recordId;
        this.query = query;
        this.email = email;
        this.fieldApiNames = DataExportService.extractFieldApiNames(query);
        this.fileNumber = 0;
    }

    public Database.QueryLocator start(Database.BatchableContext context) {
        return Database.getQueryLocator(query);
    }

    public void execute(Database.BatchableContext context, List<SObject> scope) {
        fileNumber++;
        DataExportService.createCsvFile(recordId, fieldApiNames, scope, fileNumber);
    }

    public void finish(Database.BatchableContext context) {
        
    }
}
