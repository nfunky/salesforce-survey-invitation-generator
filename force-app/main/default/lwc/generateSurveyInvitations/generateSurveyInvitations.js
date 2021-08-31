import { LightningElement,track,api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent'
import getAvailableSurveys from "@salesforce/apex/SurveyGenerator.getAvailableSurveys";
import loadRecordDetails from "@salesforce/apex/SurveyGenerator.loadRecordDetails";
import queryRecords from "@salesforce/apex/SurveyGenerator.queryRecords";
import getAvailableFieldsForObject from "@salesforce/apex/SurveyGenerator.getAvailableFieldsForObject";
import getCommunities from "@salesforce/apex/SurveyGenerator.getCommunities";
import countMaxRecords from "@salesforce/apex/SurveyGenerator.countMaxRecords";
import createNewJob from "@salesforce/apex/SurveyGenerator.createNewJob";
import createNewJobWithIds from "@salesforce/apex/SurveyGenerator.createNewJobWithIds";


export default class GenerateSurveyInvitations extends LightningElement {
    @api recordIds;
    @track isAvailableSurveysLoaded=false;
    @track isSpinnerVisible=true;
    @track isQuerySpinnerVisible=false;
    @track isError=false;
    @track errorMessage='Unknown error';
    @track availableSurveys=[];
    @track availableSurveyNames=[];    
    @track isRecordDataEmpty=true;
    @track selectedRows=[];
    @track selectedQueryRows=[];
    @track queryResults=[];
    @track columns = [
        { label: 'Name', fieldName: 'name' },
        { label: 'Email', fieldName: 'email', type: 'email'}
    ];
    @track recordSelectionList=[];    
    @track isSelectionEmpty=true;
    @track isSelectionQueryEmpty=true;
    @track buttonLabel='Generate Invitations';
    @track fieldsForSelection=[];
    @track availableCommunities=[];
    @track selectedCommunity;
    @track selectedSurvey;
    @track maxRecordCountForQuery;
    @track numberOfResults;
    @track filterquery;
    @track successMessage;

    leadFields=[];
    accountFields=[];
    contactFields=[];
    offset=0;
    objectOptions=[{'label': 'Account', 'value': 'Account'},
    {'label': 'Contact', 'value': 'Contact'},
    {'label': 'Lead', 'value': 'Lead'},];
    operatorOptions=[{'label': 'equals', 'value': 'equals'},
    {'label': 'not equals', 'value': 'not equals'},
    {'label': 'contains', 'value': 'contains'},];

    connectedCallback() {
        this.loadRecords();
        this.loadAvailableSurveys();    
        this.loadAvailableFieldsOnObjects();
        this.loadCommunities();
    }

    submitFilterQuery() {
        this.offset=0;
        this.numberOfResults=null;
        this.maxRecordCountForQuery=null;
        this.queryResults=[];
        this.isError=false;   
        this.queryRecords();
    }

    queryRecords() {
        let filterfield = this.getElementsByClassName('field')[0].value;
        let filterinput = this.getElementsByClassName('fieldvalue')[0].value;
        let operator = this.getElementsByClassName('operator')[0].value;
        let object = this.getElementsByClassName('object')[0].value;
        if(filterfield&&filterinput&&operator&&object) {
            this.isQuerySpinnerVisible=true;
            if(!this.maxRecordCountForQuery) {
                countMaxRecords({
                    objectName:object,
                    field:filterfield,
                    operator:operator,
                    filtervalue:filterinput
                })
                .then(result=> {
                    this.isSelectionQueryEmpty=false;
                    this.maxRecordCountForQuery=result[0].expr0;
                    this.queryRecords();
                }).catch(error => {
                    this.handleError(error);
                });
            } else {
                queryRecords({
                    objectName:object,
                    field:filterfield,
                    operator:operator,
                    filtervalue:filterinput,
                    offset:this.offset
                })
                .then(result=> {
                    this.isSelectionQueryEmpty=false;
                    this.queryResults=result;
                    this.queryResults=result.map((element) => {
                        let result={};
                        result['Id']=element.Id;
                        result['name']=element.Name;
                        if(element.hasOwnProperty('PersonEmail')) {
                            result['email']=element.PersonEmail;
                        } else if(element.hasOwnProperty('Email')) {
                            result['email']=element.Email;
                        }                   
                        return result;
                    });
                    this.isQuerySpinnerVisible=false;
                    this.numberOfResults=this.queryResults.length;          
                }).catch(error => {
                    this.handleError(error);
                });
            }
        } else {
            this.isSpinnerVisible=false;
            this.isError=true;           
            this.errorMessage='Please enter all mandatory fields.';
        }
    }

    loadMoreRecords() {
        if(this.maxRecordCountForQuery) {
            this.offset = this.offset + 25;
            if(this.offset<this.maxRecordCountForQuery) {
                this.queryRecords();
            }        
        }
    }

    loadAvailableSurveys() {
        getAvailableSurveys()
        .then(result => {
            this.availableSurveyNames=result.map((element) => {
                let result={};
                result['label']=element.Name;
                result['value']=element.Id;
                return result;
            });    
            this.selectedSurvey=this.availableSurveyNames[0].value;    
            this.isSpinnerVisible=false;
            this.isAvailableSurveysLoaded=true;
             
        })
        .catch(error => {
            this.handleError(error);
        });
    }

    loadRecords() {        
        if(this.recordIds) {
            if(this.recordIds.length>2) {
                loadRecordDetails({
                    recordIds: this.recordIds
                })        
                .then(result => {
                    this.recordSelectionList=result.map((element) => {
                        let result={};
                        result['Id']=element.Id;
                        result['name']=element.Name;
                        if(element.hasOwnProperty('PersonEmail')) {
                            result['email']=element.PersonEmail;
                        } else if(element.hasOwnProperty('Email')) {
                            result['email']=element.Email;
                        }                   
                        return result;
                    });                
                    if(result) {
                        this.recordData=result;
                        this.isRecordDataEmpty=false;
                        this.isSelectionEmpty=false;
                    }
                })
                .catch(error => {
                    this.handleError(error);
                });
            }
        }
    }

    loadCommunities() {
        getCommunities()        
        .then(result => {
            if(result) {
                this.availableCommunities=Object.keys(result).map(key=>{ 
                    let element={};
                    element['label']=key;
                    element['value']=result[key];
                    return element 
                });
                this.selectedCommunity=this.availableCommunities[0].value;                
            } 
        })
        .catch(error => {
            this.handleError(error);
        });
    }

    loadAvailableFieldsOnObjects() {
        getAvailableFieldsForObject({
            objectName:'Lead'
        }).then(result => {
            if(result) {
                this.leadFields=Object.keys(result).map(key=>{ 
                    let element={};
                    element['label']=key;
                    element['value']=result[key];
                    return element 
                });
            }
        })
        .catch(error => {
            this.handleError(error);
        });
        getAvailableFieldsForObject({
            objectName:'Contact'
        }).then(result => {
            if(result) {
                this.contactFields=Object.keys(result).map(key=>{ 
                    let element={};
                    element['label']=key;
                    element['value']=result[key];
                    return element 
                });
            }
        })
        .catch(error => {
            this.handleError(error);
        });
        getAvailableFieldsForObject({
            objectName:'Account'
        }).then(result => {
            if(result) {
                this.accountFields=Object.keys(result).map(key=>{ 
                    let element={};
                    element['label']=key;
                    element['value']=result[key];
                    return element 
                });
                this.fieldsForSelection=this.accountFields;                
            }
        })
        .catch(error => {
            this.handleError(error);
        });
    }

    handleQueryObjectChange(event) {
        switch(event.detail.value) {            
            case 'Contact':
                this.fieldsForSelection=this.contactFields;  
                break;
            case 'Lead':
                this.fieldsForSelection=this.leadFields;  
                break;
            default:
                this.fieldsForSelection=this.accountFields;
        }
    }

    addQueryRecordsToSelection() {
        this.recordSelectionList=this.recordSelectionList.concat(this.template.querySelectorAll('lightning-datatable')[1].getSelectedRows());
        let selectedRecordIds=this.recordSelectionList.map(element=>element.Id);
        this.queryResults=this.queryResults.filter(
            record=> {
                if (!selectedRecordIds.includes(record.Id)){
                    return record;
                }
        });
        if(this.recordSelectionList.length>0) {
            this.isSelectionEmpty=false;
        } else {
            this.isSelectionEmpty=true;
        }
        this.template.querySelectorAll('lightning-datatable')[1].selectedRows=[];
    }

    removeSelectedRecordsFromSelection() {
        let checkedRows=this.template.querySelectorAll('lightning-datatable')[0].getSelectedRows();
        this.queryResults=checkedRows.concat(this.queryResults);
        this.selectedQueryRows=checkedRows.map(element=>element.Id);      

        let queryRecordIds=this.queryResults.map(element=>element.Id);
        this.recordSelectionList=this.recordSelectionList.filter(
            record=> {
                return !queryRecordIds.includes(record.Id);
        });
        if(this.recordSelectionList.length>0) {
            this.isSelectionEmpty=false;
        } else {
            this.isSelectionEmpty=true;
        }
        this.template.querySelectorAll('lightning-datatable')[0].selectedRows=[];
    }

    handleActiveSelection() {
        this.buttonLabel='Generate Invitations';
    }

    handleActiveApexJob() {
        this.buttonLabel='Start Apex Job';
    }

    handleClickConfirmButton() {
        this.successMessage=null;
        if(this.buttonLabel==='Start Apex Job') {
            this.startApexJob();
        } else {
            this.generateInvitationsForSelection();
        }
    }

    generateInvitationsForSelection() {        
        if(this.recordSelectionList.length>0) {
            let object = this.getElementsByClassName('object')[0].value;
            let survey = this.selectedSurvey;
            let community = this.selectedCommunity;
            let selectionIds=this.recordSelectionList.map(element=>'\''+element.Id+'\'');
            createNewJobWithIds({
                surveyId:survey,
                communityId:community, 
                sobjectType:object,
                recordIds:selectionIds
            })        
            .then(result => {
                this.isError=false;
                this.successMessage='Apex job successfully started. Job Id is: '+result;
            })
            .catch(error => {
                this.handleError(error);
            });
        }
    }

    startApexJob() {
        let survey = this.selectedSurvey;
        let community = this.selectedCommunity;
        let query = this.getElementsByClassName('selectionquery')[0].value;
        if(survey&&community&&query) {
            createNewJob({
                surveyId:survey,
                communityId:community, 
                query:query
            })        
            .then(result => {
                this.isError=false;
                this.successMessage='Apex job successfully started. Job Id is: '+result;
            })
            .catch(error => {
                this.handleError(error);
            });
        }        
    }

    cancel() {
        window.history.back();
    }

    handleError(error) {
        this.isSpinnerVisible=false;
        this.isError=true;
        if(error.body) {
            this.errorMessage=error.body.message;
        } else {
            this.errorMessage='Unknown Error';
        }        
    }
}