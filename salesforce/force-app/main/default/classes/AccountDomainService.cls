// Gives every Account the Domain__c key, however it was created, so the Clay upsert
// finds hand-made records instead of creating duplicates.
// Domain__c is already unique in the database; this class adds the friendly error.
public with sharing class AccountDomainService {

    // Same rules as the n8n Normalize step: lowercase, no scheme, no www, no path or port.
    public static String normalize(String raw) {
        if (String.isBlank(raw)) {
            return null;
        }
        String d = raw.trim().toLowerCase();
        d = d.replaceFirst('^[a-z]+://', '');
        d = d.replaceFirst('^www\\.', '');
        d = d.split('[/?#:]')[0];
        return d.contains('.') ? d : null;
    }

    public static void assignDomains(List<Account> records, Map<Id, Account> oldMap) {
        Map<String, Account> byDomain = new Map<String, Account>();
        Set<Id> ownIds = new Set<Id>();

        for (Account acc : records) {
            if (String.isNotBlank(acc.Domain__c)) {
                // Never replace a key that is set, only tidy it.
                String clean = normalize(acc.Domain__c);
                acc.Domain__c = clean != null ? clean : acc.Domain__c.trim().toLowerCase();
            } else {
                acc.Domain__c = normalize(acc.Website);
            }

            Account old = oldMap == null ? null : oldMap.get(acc.Id);
            Boolean changed = old == null || old.Domain__c != acc.Domain__c;
            if (acc.Domain__c == null || !changed) {
                continue;
            }
            if (byDomain.containsKey(acc.Domain__c)) {
                acc.Domain__c.addError('Domain ' + acc.Domain__c + ' appears twice in this save.');
                continue;
            }
            byDomain.put(acc.Domain__c, acc);
            if (acc.Id != null) {
                ownIds.add(acc.Id);
            }
        }

        if (byDomain.isEmpty()) {
            return;
        }
        // One query for the whole batch, to stay inside governor limits.
        for (Account existing : [
            SELECT Id, Name, Domain__c FROM Account
            WHERE Domain__c IN :byDomain.keySet() AND Id NOT IN :ownIds
        ]) {
            Account acc = byDomain.get(existing.Domain__c.toLowerCase());
            if (acc != null) {
                acc.Domain__c.addError('Domain ' + existing.Domain__c + ' already belongs to Account "'
                    + existing.Name + '" (' + existing.Id + '). Open that record instead of creating a new one.');
            }
        }
    }
}
