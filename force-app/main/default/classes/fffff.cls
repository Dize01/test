public with sharing class CountTransferBatch implements Database.Batchable<SObject>, Database.Stateful {

    private CountEntry__c countEntry;
    private Id electionId;
    private Boolean IsSurplusTransfer;
    private Set<Id> availableCandidatesId;
    private List<CountEntry__c> currentCEs;

    // Decided once in start(), used by every execute() chunk to know which group this run should move
    private Boolean processRank1;

    // Stateful accumulators - separated by Rank1 vs Non-Rank1, persist across all execute() chunks
    private Map<Id, Integer> rank1Tally = new Map<Id, Integer>();      // destCandidateId -> count
    private Map<Id, Integer> nonRank1Tally = new Map<Id, Integer>();   // destCandidateId -> count

    private Integer totalRank1Out = 0;
    private Integer totalNonRank1Out = 0;

    public CountTransferBatch(CountEntry__c countEntry, Id electionId, Boolean IsSurplusTransfer, Set<Id> availableCandidatesId, List<CountEntry__c> currentCEs) {
        this.countEntry = countEntry;
        this.electionId = electionId;
        this.IsSurplusTransfer = IsSurplusTransfer;
        this.availableCandidatesId = availableCandidatesId;
        this.currentCEs = currentCEs;
    }

    public Database.QueryLocator start(Database.BatchableContext context) {

        if (IsSurplusTransfer) {
            processRank1 = true; // irrelevant in surplus mode, both groups process anyway

        } else {
            // Exclusion mode - check ONCE if any untouched Rank-1 votes still exist for this candidate
            List<VotePreference__c> rank1Check = [
                SELECT Id
                FROM VotePreference__c
                WHERE CandidateId__c = :countEntry.Candidate__c
                    AND FinalEntry__c = 1
                    AND Vote__r.CurrentCandidate__c = :countEntry.Candidate__c
                    AND Vote__r.Election__c = :electionId
                    AND Vote__r.VoteType__c = 'Formal'
                LIMIT 1
            ];

            processRank1 = !rank1Check.isEmpty();
        }

        return Database.getQueryLocator(
            [
                SELECT
                    Id,
                    CurrentCandidate__c,
                    Election__c
                FROM Vote__c
                WHERE VoteType__c = 'Formal' AND CurrentCandidate__c = :countEntry.Candidate__c AND Election__c = :electionId
            ]
        );
    }

    public void execute(Database.BatchableContext context, List<SObject> scope) {

        List<Vote__c> votes = (List<Vote__c>) scope;
        Set<Id> votesIds = new Map<Id, Vote__c>(votes).keySet();
        Map<Id, List<VotePreference__c>> vpMap = new Map<Id, List<VotePreference__c>>();
        List<Vote__c> votesToUpdate = new List<Vote__c>();
        List<Vote__c> votesToUpdate2 = new List<Vote__c>();

        List<VotePreference__c> vpList = [
            SELECT
                Id,
                CandidateId__c,
                FinalEntry__c,
                Vote__c
            FROM VotePreference__c
            WHERE Vote__c IN :votesIds ORDER BY FinalEntry__c
        ];

        for (VotePreference__c vp : vpList) {
            if (!vpMap.containsKey(vp.Vote__c)) {
                vpMap.put(vp.Vote__c, new List<VotePreference__c>());
            }
            vpMap.get(vp.Vote__c).add(vp);
        }

        for (Vote__c vote : votes) {

            List<VotePreference__c> vpLoopList = vpMap.get(vote.Id);

            if (vpLoopList == null || vpLoopList.isEmpty()) {
                continue;
            }

            Boolean isRank1Vote = (vote.CurrentCandidate__c == vpLoopList[0].CandidateId__c);

            // Skip votes that don't belong to this run's target group
            if (!IsSurplusTransfer) {
                if (processRank1 && !isRank1Vote) {
                    continue;
                }
                if (!processRank1 && isRank1Vote) {
                    continue;
                }
            }

            Id destCandidateId = null;
            for (VotePreference__c vpLoop : vpLoopList) {
                if (availableCandidatesId.contains(vpLoop.CandidateId__c)) {
                    destCandidateId = vpLoop.CandidateId__c;
                    break;
                }
            }

            if (destCandidateId == null) {
                continue;
            }

            if (isRank1Vote) {

                if (!rank1Tally.containsKey(destCandidateId)) {
                    rank1Tally.put(destCandidateId, 0);
                }
                rank1Tally.put(destCandidateId, rank1Tally.get(destCandidateId) + 1);
                totalRank1Out++;

                votesToUpdate.add(new Vote__c(
                    Id                  = vote.Id,
                    CurrentCandidate__c = destCandidateId
                ));

            } else {

                if (!nonRank1Tally.containsKey(destCandidateId)) {
                    nonRank1Tally.put(destCandidateId, 0);
                }
                nonRank1Tally.put(destCandidateId, nonRank1Tally.get(destCandidateId) + 1);
                totalNonRank1Out++;

                votesToUpdate2.add(new Vote__c(
                    Id                  = vote.Id,
                    CurrentCandidate__c = destCandidateId
                ));

            }

        }

        if (!votesToUpdate.isEmpty()) {
            update votesToUpdate;
        }
        if (!votesToUpdate2.isEmpty()) {
            update votesToUpdate2;
        }
    }

    public void finish(Database.BatchableContext context) {

        List<CountTransfer__c> transfersToInsert = new List<CountTransfer__c>();
        List<CountTransfer__c> transfersToInsert2 = new List<CountTransfer__c>();

        if (totalRank1Out > 0) {
            transfersToInsert.add(new CountTransfer__c(
                Candidate__c = countEntry.Candidate__c,
                Election__c  = electionId,
                Type__c      = 'TransferOut',
                VoteCount__c = totalRank1Out
            ));

            for (Id destCandidateId : rank1Tally.keySet()) {
                transfersToInsert.add(new CountTransfer__c(
                    Candidate__c     = destCandidateId,
                    FromCandidate__c = countEntry.Candidate__c,
                    Election__c      = electionId,
                    Type__c          = 'TransferIn',
                    VoteCount__c     = rank1Tally.get(destCandidateId)
                ));
            }
        }

        if (totalNonRank1Out > 0) {
            transfersToInsert2.add(new CountTransfer__c(
                Candidate__c = countEntry.Candidate__c,
                Election__c  = electionId,
                Type__c      = 'TransferOut',
                VoteCount__c = totalNonRank1Out
            ));

            for (Id destCandidateId : nonRank1Tally.keySet()) {
                transfersToInsert2.add(new CountTransfer__c(
                    Candidate__c     = destCandidateId,
                    FromCandidate__c = countEntry.Candidate__c,
                    Election__c      = electionId,
                    Type__c          = 'TransferIn',
                    VoteCount__c     = nonRank1Tally.get(destCandidateId)
                ));
            }
        }

        if (!transfersToInsert.isEmpty()) {
            insert transfersToInsert;
        }
        if (!transfersToInsert2.isEmpty()) {
            insert transfersToInsert2;
        }
    }
}