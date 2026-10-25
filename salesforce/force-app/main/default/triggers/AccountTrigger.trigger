trigger AccountTrigger on Account (before insert, before update) {
    AccountDomainService.assignDomains(Trigger.new, Trigger.oldMap);
}
