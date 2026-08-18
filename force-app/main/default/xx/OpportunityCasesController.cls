public with sharing class OpportunityCasesController {
  public class StatusCount {
    @AuraEnabled
    public String status;
    @AuraEnabled
    public Integer count;
  }

  @AuraEnabled(cacheable=true)
  public static List<Case> getOpportunityCases(Id opportunityId) {
    return [
      SELECT Id, CaseNumber, Subject, Status, Priority
      FROM Case
      WHERE Opportunity__c = :opportunityId
      ORDER BY CreatedDate DESC
    ];
  }

  @AuraEnabled(cacheable=true)
  public static List<StatusCount> getCaseStatusBreakdown(Id opportunityId) {
    List<StatusCount> results = new List<StatusCount>();
    for (AggregateResult ar : [
      SELECT Status status, COUNT(Id) total
      FROM Case
      WHERE Opportunity__c = :opportunityId
      GROUP BY Status
    ]) {
      StatusCount sc = new StatusCount();
      sc.status = (String) ar.get('status');
      sc.count = (Integer) ar.get('total');
      results.add(sc);
    }
    return results;
  }

  @AuraEnabled
  public static Case createCase(Id opportunityId) {
    try {
      Opportunity opp = [
        SELECT Id, Name
        FROM Opportunity
        WHERE Id = :opportunityId
      ];
      Case newCase = new Case(
        Subject = opp.Name,
        Opportunity__c = opp.Id
      );
      insert newCase;

      EventBus.publish(
        new CountingPlatformEvent__e(countId__c = newCase.Id)
      );

      return [
        SELECT Id, CaseNumber, Subject, Status, Priority
        FROM Case
        WHERE Id = :newCase.Id
      ];
    } catch (Exception e) {
      throw new AuraHandledException(e.getMessage());
    }
  }
}
