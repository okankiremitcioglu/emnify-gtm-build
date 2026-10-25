@IsTest
private class AccountDomainServiceTest {

    @IsTest
    static void normalizesLikeN8n() {
        System.assertEquals('netradyne.com', AccountDomainService.normalize('https://www.Netradyne.com/en/about?x=1'));
        System.assertEquals('evgo.com', AccountDomainService.normalize('evgo.com'));
        System.assertEquals('lytx.com', AccountDomainService.normalize('http://lytx.com:8080'));
        System.assertEquals(null, AccountDomainService.normalize('not a website'));
        System.assertEquals(null, AccountDomainService.normalize(null));
    }

    @IsTest
    static void insertFillsDomainFromWebsite() {
        Account acc = new Account(Name = 'Netradyne', Website = 'https://www.netradyne.com/');
        insert acc;
        System.assertEquals('netradyne.com', [SELECT Domain__c FROM Account WHERE Id = :acc.Id].Domain__c);
    }

    @IsTest
    static void bulkInsertUsesOneQuery() {
        List<Account> accs = new List<Account>();
        for (Integer i = 0; i < 200; i++) {
            accs.add(new Account(Name = 'Bulk ' + i, Website = 'https://www.bulk' + i + '.example/home'));
        }
        Test.startTest();
        insert accs;
        Integer queries = Limits.getQueries();
        Test.stopTest();

        System.assertEquals(1, queries, 'the trigger should query once per batch, not once per record');
        System.assertEquals(200, [SELECT COUNT() FROM Account WHERE Domain__c LIKE 'bulk%.example']);
    }

    @IsTest
    static void blocksDomainThatAlreadyExists() {
        insert new Account(Name = 'Netradyne', Domain__c = 'netradyne.com');

        Database.SaveResult result = Database.insert(
            new Account(Name = 'Netradyne Inc (manual)', Website = 'http://Netradyne.com/contact'), false);

        System.assert(!result.isSuccess());
        System.assert(result.getErrors()[0].getMessage().contains('already belongs to Account "Netradyne"'),
            result.getErrors()[0].getMessage());
    }

    @IsTest
    static void blocksDuplicatesInTheSameSave() {
        List<Database.SaveResult> results = Database.insert(new List<Account>{
            new Account(Name = 'EVgo', Website = 'evgo.com'),
            new Account(Name = 'EVgo Services', Website = 'https://www.evgo.com')
        }, false);

        System.assert(results[0].isSuccess());
        System.assert(!results[1].isSuccess());
        System.assert(results[1].getErrors()[0].getMessage().contains('appears twice'));
    }

    @IsTest
    static void keepsAnExistingDomain() {
        Account acc = new Account(Name = 'Vodafone Automotive', Domain__c = 'vodafone.com',
            Website = 'https://www.vodafone-automotive.com');
        insert acc;

        acc.Website = 'https://automotive.vodafone.com';
        update acc;

        System.assertEquals('vodafone.com', [SELECT Domain__c FROM Account WHERE Id = :acc.Id].Domain__c);
    }

    @IsTest
    static void updateFillsMissingDomain() {
        Account acc = new Account(Name = 'Kempower');
        insert acc;
        System.assertEquals(null, [SELECT Domain__c FROM Account WHERE Id = :acc.Id].Domain__c);

        acc.Website = 'www.kempower.com';
        update acc;
        System.assertEquals('kempower.com', [SELECT Domain__c FROM Account WHERE Id = :acc.Id].Domain__c);
    }

    @IsTest
    static void upsertOnDomainStillUpdates() {
        // The n8n path: PATCH on Domain__c must update the record, not trip the duplicate check.
        insert new Account(Name = 'LocoNav', Domain__c = 'loconav.com');

        Account fromClay = new Account(Name = 'LocoNav', Domain__c = 'loconav.com', ICP_Score__c = 60);
        Database.UpsertResult result = Database.upsert(fromClay, Account.Domain__c, false);

        System.assert(result.isSuccess(), String.valueOf(result.getErrors()));
        System.assert(!result.isCreated());
        System.assertEquals(1, [SELECT COUNT() FROM Account WHERE Domain__c = 'loconav.com']);
    }
}
