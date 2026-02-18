/*
   se eliminan los child items de servicios incluídos residencial

*/
List<vlocity_cmt__ProductChildItem__c> lLstAssignments = [SELECT Id, vlocity_cmt__ParentProductId__c, vlocity_cmt__ChildProductId__c, CreatedDate
FROM vlocity_cmt__ProductChildItem__c
WHERE vlocity_cmt__ChildProductId__c IN (
  '01tDk000003y8fEIAQ',
  '01tDk000003y8gBIAQ',
  '01tDk000003y8fRIAQ',
  '01tDk000003y8fOIAQ',
  '01tDk000003y8fDIAQ',
  '01tDk000003y8fBIAQ',
  '01tDk000003y8fPIAQ'
)
ORDER BY vlocity_cmt__ChildProductId__c, vlocity_cmt__ParentProductId__c, CreatedDate];
if (lLstAssignments.isEmpty()) { return; }
Database.delete(lLstAssignments);

