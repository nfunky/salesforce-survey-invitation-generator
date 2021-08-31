/*          
 * SurveyGenerator
 * Batch job that generates SurveyInvitation records for the record ids or SOQL query provided. Additionally contains methods for LWC component. 
 *
 * @isTestedBy SurveyGeneratorTest
 */
public with sharing class SurveyGenerator implements Database.Batchable<sObject>, Database.Stateful {

    String selectionQuery;
    Survey survey;
    Id communityId;

    public SurveyGenerator(Id surveyId, Id communityId, String selectionQuery) {
        this.selectionQuery=selectionQuery;
        this.survey=[SELECT Id,Name FROM Survey WHERE Id=:surveyId];
        this.communityId=communityId;
    }

    public SurveyGenerator(Id surveyId, Id communityId, String sobjectType, List<String> recordIds) {
        this.selectionQuery='SELECT Id, Name FROM '+sobjectType+' WHERE Id IN'+recordIds;
        if(sobjectType.equals('Account')) {
            this.selectionQuery='SELECT Id, Name,PersonContactId FROM '+sobjectType+' WHERE Id IN'+recordIds;
        }
        this.survey=[SELECT Id,Name FROM Survey WHERE Id=:surveyId];
        this.communityId=communityId;
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {          
        return Database.getQueryLocator(selectionQuery);
    }

    public void execute(Database.BatchableContext bc, List<SObject> records){    
        List<SurveyInvitation> invites=new List<SurveyInvitation>();
        for(SObject sobj:(List<SObject>)records) {
            invites.add(getSurveyInvitationForContact(sobj,true,this.survey,this.communityId));
        }
        insert invites;
    }    

    public void finish(Database.BatchableContext bc){

    }     

    @AuraEnabled
    public static Id createNewJob(String surveyId,String communityId, String query) {
        String queryLowercase=query.toLowercase();
        if( queryLowercase.contains('account')||
        queryLowercase.contains('contact')||
        queryLowercase.contains('lead')) {
                if(queryLowercase.contains('from account')&&!queryLowercase.contains('personcontactid')) {                    
                    query=queryLowercase.replace('select','select personcontactid,');
                }
                if(!queryLowercase.contains(' id')&&!queryLowercase.contains(',id')) {                    
                    query=queryLowercase.replace('select','select id,');
                }
                return Database.executeBatch(new SurveyGenerator(surveyId,communityId,query));
        } else {
            throw new AuraHandledException('Unsupported SObject. Surveys can only be generated for Accounts, Leads and Contacts.');   
        }
    }

    @AuraEnabled
    public static Id createNewJobWithIds(String surveyId,String communityId, String sobjectType,List<String> recordIds) {        
        return Database.executeBatch(new SurveyGenerator(surveyId,communityId,sobjectType,recordIds));        
    }

    public SurveyInvitation getSurveyInvitationForContact(SObject record,Boolean allowGuestUsers,Survey survey,Id communityId) {        
        SurveyInvitation invite=new SurveyInvitation(
            OptionsAllowGuestUserResponse=allowGuestUsers,
            ParticipantId=record instanceof Account?((Account)record).PersonContactId:record.Id,
            surveyID=survey.Id, 
            Name=survey.Name+'-'+Date.today().format()+'-'+record.Id,
            CommunityId=communityId
        );
        return invite;
    }

    @AuraEnabled
    public static Map<String,String> getCommunities() {
        ConnectApi.CommunityPage communityPage=ConnectApi.Communities.getCommunities(ConnectApi.CommunityStatus.Live);
        List<ConnectApi.Community> communities=communityPage.communities;
        Map<String,String> result=new Map<String,String>();
        for(ConnectApi.Community community:communities) {            
            result.put(community.name, community.id);
        }
        if(communities.size()==0) {
            throw new AuraHandledException('No active Community instance was found. Make sure your environment has at least one active Community instance.'); 
        }
        return result;
    }

    @AuraEnabled
    public static List<Survey> getAvailableSurveys() {
        return [SELECT Id,Name FROM Survey WHERE ActiveVersionId!='' ORDER BY LastModifiedDate DESC LIMIT 1000];
    }

    @AuraEnabled(cacheable=true)
    public static List<SObject> loadRecordDetails(List<String> recordIds) {
        if(recordIds.size()>0) {
            String prefix=recordIds.get(0).substring(0,3);
            switch on prefix {
                when '001'{
                    return [SELECT Id,Name,PersonEmail FROM Account WHERE Id IN:recordIds];
                }
                when '003'{
                    return [SELECT Id,Name,Email FROM Contact WHERE Id IN:recordIds];
                }
                when '00Q'{
                    return [SELECT Id,Name,Email FROM Lead WHERE Id IN:recordIds];
                }
                when else {
                    throw new AuraHandledException('Unsupported SObject. Surveys can only be generated for Accounts, Leads and Contacts.');                    
                }
            }
        }
        return null;
    }

    @AuraEnabled(cacheable=true)
    public static List<SObject> countMaxRecords(String objectName,String field,String operator,String filtervalue) {
        if( objectName.equals('Account')||
            objectName.equals('Contact')||
            objectName.equals('Lead')) {
            Schema.DisplayType fieldType=Schema.getGlobalDescribe().get(objectName).getDescribe().fields.getMap().get(field).getDescribe().getType();
            String query='SELECT count(Id) ';
            
            String soqlOperator='=';
            if(operator.equals('not equals')) {
                soqlOperator='!=';
            } else if(operator.equals('contains')) {
                soqlOperator=' LIKE ';
                filtervalue='\'%'+filtervalue+'%\'';
            }
            if(operator!='contains'&&(
                fieldType==Schema.DisplayType.String||
                fieldType==Schema.DisplayType.EMAIL||
                fieldType==Schema.DisplayType.ID||
                fieldType==Schema.DisplayType.PICKLIST||
                fieldType==Schema.DisplayType.URL||
                fieldType==Schema.DisplayType.TEXTAREA)) {
                filtervalue='\''+filtervalue+'\'';
            }
            
            query+=' FROM '+objectName+' WHERE '+field+soqlOperator+filtervalue;
            return Database.query(query);
        } else {
            throw new AuraHandledException('Unsupported SObject. Surveys can only be generated for Accounts, Leads and Contacts.');
        }        
    }

    @AuraEnabled(cacheable=true)
    public static List<SObject> queryRecords(String objectName,String field,String operator,String filtervalue, Integer offset) {
        if( objectName.equals('Account')||
            objectName.equals('Contact')||
            objectName.equals('Lead')) {        
            if(offset==null) {
                offset=0;
            }
            
            Integer limitSize=50+offset; 

            Schema.DisplayType fieldType=Schema.getGlobalDescribe().get(objectName).getDescribe().fields.getMap().get(field).getDescribe().getType();
            String query='SELECT Id,Name';
            if(objectName.equals('Account')) {
                query+=',PersonEmail ';
            } else {
                query+=',Email ';
            }
            String soqlOperator='=';
            if(operator.equals('not equals')) {
                soqlOperator='!=';
            } else if(operator.equals('contains')) {
                soqlOperator=' LIKE ';
                filtervalue='\'%'+filtervalue+'%\'';
            }
            if(operator!='contains'&&(
                fieldType==Schema.DisplayType.String||
                fieldType==Schema.DisplayType.EMAIL||
                fieldType==Schema.DisplayType.ID||
                fieldType==Schema.DisplayType.PICKLIST||
                fieldType==Schema.DisplayType.URL||
                fieldType==Schema.DisplayType.TEXTAREA)) {
                filtervalue='\''+filtervalue+'\'';
            }            
            query+=' FROM '+objectName+' WHERE '+field+soqlOperator+filtervalue+' LIMIT '+limitSize+' OFFSET '+offset;
            return Database.query(query);
        } else {
            throw new AuraHandledException('Unsupported SObject. Surveys can only be generated for Accounts, Leads and Contacts.');
        }        
    }

    @AuraEnabled(cacheable=true)
    public static Map<String,String> getAvailableFieldsForObject(String objectName) {
        try {
            SObjectType sobjecttype = Schema.getGlobalDescribe().get(objectName);
            Map<String,Schema.SObjectField> fields = sobjecttype.getDescribe().fields.getMap();     
            Map<String,String> result=new Map<String,String>();
            for(String name:fields.keySet()) {
                result.put(fields.get(name).getDescribe().getLabel(),fields.get(name).getDescribe().getName());
            }
            return result;       
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        } 
    }
}