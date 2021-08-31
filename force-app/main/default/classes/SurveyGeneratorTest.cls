/*          
 * SurveyGeneratorTest
 * Tests the batch job that generates SurveyInvitation records for the record ids or SOQL query provided. Tests methods for SurveyGenerator LWC component. 
 *
 * @tests SurveyGenerator,SurveyGeneratorVFExtension
 */
@isTest
public with sharing class SurveyGeneratorTest {

    @isTest(SeeAllData=true)
    public static void testAccountSurveyGeneration() {
        Integer expectedSurveyCount=2;
        List<Contact> contacts = new List<Contact>();
        contacts.add(new Contact(LastName='Contact Lead1-Surveygenerator', MailingCity='Test City'));
        contacts.add(new Contact(LastName='Contact Lead2-Surveygenerator'));
        insert contacts;
        List<Lead> leads = new List<Lead>();
        leads.add(new Lead(LastName='Lead1-Surveygenerator',Email='test1@test.com'));
        leads.add(new Lead(LastName='Lead2-Surveygenerator',Email='test@test.com'));
        insert leads;

        Map<String,String> communities=SurveyGenerator.getCommunities();
        String communityId=null;
        for (String key:communities.keySet()) {            
            communityId  = communities.get(key);
            break;
        }
        System.assertNotEquals(null,communityId,'At least one active Community needs to be set up to run this test class.');

        List<Survey> surveys=SurveyGenerator.getAvailableSurveys();
        System.assertNotEquals(0,surveys.size(),'At least one active survey needs to be set up to run this test class.');      
        Test.startTest();


        SurveyGenerator.createNewJob(surveys.get(0).Id,communityId,'SELECT Id FROM Contact WHERE MailingCity=\'Test City\' and LastName=\'Contact Lead1-Surveygenerator\'');        
        

        List<Lead> leadSelection=[SELECT Id FROM Lead WHERE Email='test@test.com' AND LastName='Lead2-Surveygenerator'];
        List<String> leadIdsAsString=new List<String>();
        for(Lead l:leadSelection) {
            leadIdsAsString.add('\''+l.Id+'\'');
        }

        System.assertEquals(1,SurveyGenerator.countMaxRecords('Lead','Email','equals','test@test.com').size(),'One record should be returned for query');
        System.assertEquals(1,SurveyGenerator.countMaxRecords('Lead','Email','contains','test@test.com').size(),'One record should be returned for query');
        System.assertEquals(1,SurveyGenerator.countMaxRecords('Lead','Email','not equals','test@test.com').size(),'One record should be returned for query');

        System.assertEquals(true,SurveyGenerator.getAvailableFieldsForObject('Lead').size()>0,'Fields cannot be empty');   

        SurveyGenerator.createNewJobWithIds(surveys.get(0).Id,communityId,'Lead',leadIdsAsString);        
       
        leadIdsAsString=new List<String>();
        for(Lead l:leadSelection) {
            leadIdsAsString.add(l.Id);
        }
        System.assertEquals(1,SurveyGenerator.loadRecordDetails(leadIdsAsString).size(),'One record should be returned for query');

        List<SObject> records=SurveyGenerator.queryRecords('Contact','MailingCity','equals','Test City', 0);
        System.assertEquals(1,records.size(),'One record should be returned for query');        
        
        boolean isPersonAccountEnabled = Schema.sObjectType.Account.fields.getMap().containsKey('isPersonAccount');
        List<Id> accountIds=new List<Id>();
        if(isPersonAccountEnabled) {
            RecordType personAccountRecordType =  [SELECT Id FROM RecordType WHERE DeveloperName = 'PersonAccount' and SObjectType = 'Account'];
            List<Account> accounts = new List<Account>();
            accounts.add(new Account(LastName='Account1',PersonEmail='test@test.com.surveygenerator',RecordTypeId=personAccountRecordType.Id));
            accounts.add(new Account(LastName='Account2',RecordTypeId=personAccountRecordType.Id));
            insert accounts;
            List<Account> accFullData=[SELECT Id,PersonContactId FROM Account WHERE Id IN:accounts];
            for(Account acc:accFullData) {
                accountIds.add(acc.PersonContactId);
            }    
            SurveyGenerator.createNewJob(surveys.get(0).Id,communityId,'SELECT Id FROM Account WHERE LastName=\'Account1\' AND PersonEmail=\'test@test.com.surveygenerator\'');        
            expectedSurveyCount=3;
        }
        Test.stopTest();        

        List<SurveyInvitation> invitesLead=[SELECT Id,ParticipantId FROM SurveyInvitation WHERE ParticipantId IN:leads];        
        System.assertEquals(1, invitesLead.size(),'Count of SurveyInvitation records does not match with expected value');

        List<SurveyInvitation> invitesLeadsAndContacts=[SELECT Id,ParticipantId FROM SurveyInvitation WHERE ParticipantId IN:contacts];   
        System.assertEquals(1, invitesLeadsAndContacts.size(),'Count of SurveyInvitation records does not match with expected value');

        List<SurveyInvitation> invites=[SELECT Id,ParticipantId FROM SurveyInvitation WHERE ParticipantId IN:accountIds];        
        System.debug(invites);
        System.assertEquals(1, invites.size(),'Count of SurveyInvitation records does not match with expected value');
    } 

    @isTest
    public static void testExceptions() {
        Exception expectedException=null;
        try {
            SurveyGenerator.countMaxRecords('Opportunity','Email','not equals','test@test.com').size();
        } catch(Exception e) {
            expectedException=e;
        }
        expectedException=null;
        try {
            SurveyGenerator.createNewJob('Opportunity','Email','SELECT Id FROM Opportunity');
        } catch(Exception e) {
            expectedException=e;
        }
        System.assertNotEquals(null,expectedException,'An exception should be thrown');
        expectedException=null;
        try {
            SurveyGenerator.loadRecordDetails(new List<String>{'0Kd0E000000CbDaSAK'});
        } catch(Exception e) {
            expectedException=e;
        }
        System.assertNotEquals(null,expectedException,'An exception should be thrown');
        expectedException=null;
        try {
            SurveyGenerator.queryRecords('Opportunity','Email','not equals','test@test.com',0);
        } catch(Exception e) {
            expectedException=e;
        }
        System.assertNotEquals(null,expectedException,'An exception should be thrown');
        expectedException=null;
        try {
            SurveyGenerator.getAvailableFieldsForObject('ObjectDoesNotExist');
        } catch(Exception e) {
            expectedException=e;
        }
        System.assertNotEquals(null,expectedException,'An exception should be thrown');
        expectedException=null;
        try {
            SurveyGenerator.getCommunities();
        } catch(Exception e) {
            expectedException=e;
        }
        System.assertNotEquals(null,expectedException,'An exception should be thrown');
    }

    @isTest
    private static void testSurveyVFPage() {
        RecordType personAccountRecordType =  [SELECT Id FROM RecordType WHERE DeveloperName = 'PersonAccount' and SObjectType = 'Account'];
        List<Account> accounts = new List<Account>();
        accounts.add(new Account(LastName='Account1',PersonEmail='test@test.com.surveygenerator',RecordTypeId=personAccountRecordType.Id));
        accounts.add(new Account(LastName='Account2',RecordTypeId=personAccountRecordType.Id));
        insert accounts;

        Test.setCurrentPage(Page.SurveyInvitationGenerator);
        ApexPages.StandardSetController scontroller = new ApexPages.StandardSetController(accounts);
        scontroller.setSelected(accounts);
        SurveyGeneratorVFExtension testSurveyVFPage = new SurveyGeneratorVFExtension(scontroller);
    }
}