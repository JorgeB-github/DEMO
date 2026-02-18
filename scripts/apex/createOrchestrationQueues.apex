/**
 * @description       : Creacion de orchestration Queues para el envio de ordenes a OM, se debe ejecutar una unica vez por ambiente
 * @author            : Gerardo Filitto
 * @last modified on  : 11-12-2024
 * @last modified by  : Gerardo Filitto
**/
vlocity_cmt__OrchestrationSchedulerImplementation__c impl = new vlocity_cmt__OrchestrationSchedulerImplementation__c();
impl.Name = 'Batch Scheduler';
impl.vlocity_cmt__Implementation__c = 'BatchScheduler';
insert impl;

//Create orchQueues
List<vlocity_cmt__OrchestrationQueue__c> queues = new List<vlocity_cmt__OrchestrationQueue__c>();
for (Integer i = 1; i <= 4; i++){
    vlocity_cmt__OrchestrationQueue__c queue = new vlocity_cmt__OrchestrationQueue__c();
    queue.name = 'Queue ' + i;
    queue.vlocity_cmt__OrchestrationSchedulerImplementationId__c = impl.id;
    queue.vlocity_cmt__State__c = 'Stopped';
    queue.vlocity_cmt__Replicas__c = '0';
    queues.add(queue);
}
insert queues;