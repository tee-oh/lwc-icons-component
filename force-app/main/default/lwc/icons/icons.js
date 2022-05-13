import { LightningElement, api, wire, track } from 'lwc';
import { getRecord } from 'lightning/uiRecordApi';
import iconResource from '@salesforce/resourceUrl/Icons';
import getRecordIcons from '@salesforce/apex/IconsUtility.getRecordIcons';
import SystemModstamp from '@salesforce/schema/Account.SystemModstamp';
export default class Icons extends LightningElement {

    @api accountIdFieldApiName = null;
    @api caseIdFieldApiName = null;
    @api contactIdFieldApiName = null;
    @api opportunityIdFieldApiName = null;

    @api objectApiName;
    @api recordId;
    parentRecord;

    icons;
    iconTitle;
    iconUrl;
    iconResourceUrl = iconResource + '/';
    objectLabel;
    showIcons = false;

    renderedCallback() {        
        if(this.objectApiName == 'Account') {
            this.objectLabel = 'Account';
        } else if (this.objectApiName == 'Case') {
            this.objectLabel = 'Case';
        } else if (this.objectApiName == 'Contact') {
            this.objectLabel = 'Contact';
        } else if (this.objectApiName == 'Opportunity') {
            this.objectLabel = 'Opportunity';
        }
    }

    @wire(getRecord, { recordId: '$recordId' , layoutTypes: ['Full'], modes: ['View'] }) //Standard GetRecord is only used so the component reacts to any updates a user makes to fields they see on the screen.
    getParentRecord(result) {
        if (result.data) {
            this.parentRecord = JSON.stringify(result.data);
        } else if (result.error) {
            this.errorMsg = results.error;
            console.log('GET PARENT RECORD ERROR: ', this.errorMsg);
        } else {
            console.log('There is a problem getting the record');
        }
    }

    @wire(getRecordIcons, {accountLoc: '$accountIdFieldApiName', caseLoc: '$caseIdFieldApiName', contactLoc: '$contactIdFieldApiName', opportunityLoc: '$opportunityIdFieldApiName', record: '$recordId', objType: '$objectApiName', parentRec: '$parentRecord'})
    wiredIconList(results){
        if (results.data) {
            this.icons = results.data;
            let iconList = JSON.parse(JSON.stringify(this.icons));
            for(let i in iconList) {
                iconList[i].iconUrl = this.iconResourceUrl + iconList[i].icon;
                iconList[i].iconTitle = iconList[i].title;
                console.log('iconUrl: ' + iconList[i].iconUrl);
            }
            this.icons = iconList;
            if(this.icons.length != 0){
                this.showIcons = true;
            }
        } else if (results.error){
            this.errorMsg = results.error;
            console.log('GET WIRED ICON LIST ERROR: ', this.errorMsg);
        } else {
            console.log('There is a problem retrieving the icon data.');
        }
    }
}
