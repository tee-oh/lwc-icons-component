public with sharing class IconsUtility {
    private static String recordId;
    private static String objectType;
    private static String accountLocation;
    private static String caseLocation;
    private static String contactLocation;
    private static String opportunityLocation;

    private static Map<String, List<String>> allRecordFields = new Map<String, List<String>>();
    
    public class IconWrapper{
        @AuraEnabled public Id id {get;set;}
        @AuraEnabled public String icon {get;set;}
        @AuraEnabled public String title {get;set;}
    }

    @AuraEnabled (cacheable=true)
    public static List<IconWrapper> getRecordIcons(String accountLoc, String caseLoc, String contactLoc, String opportunityLoc, String record, String objType, String parentRec){
        recordId = record;
        objectType = objType;
        accountLocation = accountLoc;
        caseLocation = caseLoc;
        contactLocation = contactLoc;
        opportunityLocation = opportunityLoc;

        Map<Id, Icon__mdt> iconsMap = new Map<Id, Icon__mdt>([SELECT Id, Image__c, Hover_Text__c FROM Icon__mdt]);

        //Get all icon condition groups and their conditions.
        List<Icon_Condition_Group__mdt> iconGroups = new List<Icon_Condition_Group__mdt>([SELECT Id, Icon__c, Icon__r.Hover_Text__c, Icon__r.Image__c, Icon__r.Label,
                                                                                        Icon__r.Object_Types__c, Filter_Type__c, Label,
                                                                                        (SELECT Id, Source_Field_Data_Type__c, Icon_Condition_Group__c, Icon_Condition_Group__r.Filter_Type__c, Interval__c, Operator__c,
                                                                                        Operator_Type__c, Qualifying_Value__c, Source_Map__c, Source_Field__c FROM Icon_Conditions__r)
                                                                                        FROM Icon_Condition_Group__mdt
                                                                                        ]);
        System.debug('--total icon groups: '+ iconGroups.size());

        //Remove any icon groups referencing icons that are unavailable to this object type.
        for (Integer i = iconGroups.size()-1; i >= 0 ; i--) { // NOTE: Loop backwards to account for changing index number when a value is identified and removed.
            Boolean matchingObjectType = false;
            List<String> splitObjectType = iconGroups[i].Icon__r.Object_Types__c.split(',');
            if (splitObjectType.contains(objectType)) {
                matchingObjectType = true;
            }
            if (!matchingObjectType) {
                iconGroups.remove(i);
            }
        }
        System.debug('--total icon groups available to object: '+ iconGroups.size());

        //From the remaining icon groups and their conditions, determine what objects, and fields on those objects, need to be evaluated.
        for (Icon_Condition_Group__mdt iconGroup : iconGroups) {
            for (Icon_Condition__mdt condition : iconGroup.Icon_Conditions__r) {
                if (allRecordFields.containsKey(condition.Source_Map__c)) {
                    if(!allRecordFields.get(condition.Source_Map__c).contains(condition.Source_Field__c)){
                        allRecordFields.get(condition.Source_Map__c).add(condition.Source_Field__c);
                    }
                } else {
                    allRecordFields.put(condition.Source_Map__c, new List<String>{'Id'});
                    allRecordFields.get(condition.Source_Map__c).add(condition.Source_Field__c);
                }
            }
        }
        System.debug('--allRecordFieldsMap: ' + allRecordFields);

        //From the remaining icon groups, split the groups into AND and OR maps based on their filter type.
        Map <Icon_Condition_Group__mdt, List<Icon_Condition__mdt>> andConditionsMap = new Map <Icon_Condition_Group__mdt, List<Icon_Condition__mdt>>();
        Map <Icon_Condition_Group__mdt, List<Icon_Condition__mdt>> orConditionsMap = new Map <Icon_Condition_Group__mdt, List<Icon_Condition__mdt>>();
        for (Icon_Condition_Group__mdt iconGroup : iconGroups) {
            for (Icon_Condition__mdt condition : iconGroup.Icon_Conditions__r) {
                if(condition.Icon_Condition_Group__r.Filter_Type__c == 'AND'){
                    List<Icon_Condition__mdt> groupConditions = andConditionsMap.get(iconGroup);
                    if(groupConditions == null){
                        andConditionsMap.put(iconGroup, new List<Icon_Condition__mdt>{condition});
                    } else {
                        groupConditions.add(condition);
                    }
                }
                if(condition.Icon_Condition_Group__r.Filter_Type__c == 'OR'){
                    List<Icon_Condition__mdt> groupConditions = orConditionsMap.get(iconGroup);
                    if(groupConditions == null){
                        orConditionsMap.put(iconGroup, new List<Icon_Condition__mdt>{condition});
                    } else {
                        groupConditions.add(condition);
                    }
                }
            }
        }
        System.debug('--total AND icon groups: ' + andConditionsMap.size());
        System.debug('--total OR icon groups: ' + orConditionsMap.size());

        //Process all AND icon groups and their conditions.
        List<Icon_Condition_Group__mdt> andGroups = new List<Icon_Condition_Group__mdt>(andConditionsMap.keySet());

        for (Integer i = andGroups.size()-1; i >= 0 ; i--) { 
            if (andConditionsMap.get(andGroups[i]) != null){           
                Boolean matchesAllConditions = true;
                for (Icon_Condition__mdt condition : andConditionsMap.get(andGroups[i])){
                    System.debug('--condition: '+ condition);   
                    //Pass each AND group condition Source Map and Source Field into the methods to get the actual record value, convert qualifying values to strings, and evaluate condition for a match.
                    String actualValue = convertActualValueToString(condition.Source_Field_Data_Type__c, condition.Source_Map__c, condition.Source_Field__c);
                    String conditionValue = convertConditionValueToString(condition.Source_Field_Data_Type__c, condition.Operator_Type__c, condition.Qualifying_Value__c, condition.Interval__c);
                    matchesAllConditions = compareActualandConditionValues(condition.Source_Field_Data_Type__c, condition.Operator__c, actualValue, conditionValue);
                    System.debug('--matches all conditions? ' + matchesAllConditions);
                    if (matchesAllConditions == false){
                        break;
                    }
                }
                //If any AND group has a condition that doesn't match, remove the icon group from the list.
                if (!matchesAllConditions) {
                    andGroups.remove(i);
                }
            }
        }
        System.debug('--remaining AND Groups: ' + andGroups.size());

        //Process all OR icon groups and their conditions.
        List<Icon_Condition_Group__mdt> orGroups = new List<Icon_Condition_Group__mdt>(orConditionsMap.keySet());

        for (Integer i = orGroups.size()-1; i >= 0 ; i--) {
            if (orConditionsMap.get(orGroups[i]) != null){           
                Boolean matchesOneCondition = false;
                for (Icon_Condition__mdt condition : orConditionsMap.get(orGroups[i])){
                    System.debug('--condition: '+ condition);   
                    //Pass each OR group condition Source Map and Source Field into the methods to get the actual record value, convert qualifying values to strings, and evaluate condition for a match.
                    String actualValue = convertActualValueToString(condition.Source_Field_Data_Type__c, condition.Source_Map__c, condition.Source_Field__c);
                    String conditionValue = convertConditionValueToString(condition.Source_Field_Data_Type__c, condition.Operator_Type__c, condition.Qualifying_Value__c, condition.Interval__c);
                    matchesOneCondition = compareActualandConditionValues(condition.Source_Field_Data_Type__c, condition.Operator__c, actualValue, conditionValue);
                    System.debug('--matches a condition? ' + matchesOneCondition);
                    if (matchesOneCondition == true){
                        break;
                    }
                }
                //If any OR group has conditions were none of them match, remove the icon group from the list.
                if (!matchesOneCondition) {
                    orGroups.remove(i);
                }
            }
        }
        System.debug('--remaining OR Groups: ' + orGroups.size());

        //Combine remaining AND and OR groups together.
        List<Icon_Condition_Group__mdt> iconGroupsToShow = new List<Icon_Condition_Group__mdt>();
        iconGroupsToShow.addAll(andGroups);
        iconGroupsToShow.addAll(orGroups);
        System.debug('--remaining AND and OR groups: ' + iconGroupsToShow.size());

        //For each group, pass its icon id to the icon map to extract set of icon records.
        Set<Icon__mdt> iconsToShow = new Set<Icon__mdt>();
        for (Icon_Condition_Group__mdt iconGroup : iconGroupsToShow){
            iconsToShow.add(iconsMap.get(iconGroup.Icon__c));
        }
        System.debug('--total icons for display: ' + iconsToShow.size());

        //Pass the icon record values to a wrapper to display in the component.
        List<IconWrapper> icons = new List<IconWrapper>();     
        for (Icon__mdt icon : iconsToShow){
            IconWrapper iconWrap = new IconWrapper();
                iconWrap.id = icon.Id;
                iconWrap.icon = icon.Image__c;
                iconWrap.title = icon.Hover_Text__c;
                System.debug('--display icon: '+ iconWrap.icon);
            icons.add(iconWrap);
        }          
        return icons;
    }

    private static String convertActualValueToString(String conditionDataType, String conditionSourceMap, String conditionSourceField){
        String actualValue = '';
        if (mapRelatedFieldValues?.get(conditionSourceMap)?.get(conditionSourceField) != null){ //Null check (?) included in all references of map to not fail out on conditions that don't pertain to the record we are on.
            if (conditionDataType == 'Date') { //Convert actual date values to milliseconds from 1/1/1970 and format as a string.
                Datetime d = (Datetime) mapRelatedFieldValues?.get(conditionSourceMap)?.get(conditionSourceField);
                actualValue = d.getTime().format();
            } else if (conditionDataType == 'Boolean') { //Format booleans as a string.
                Boolean b = (Boolean) mapRelatedFieldValues?.get(conditionSourceMap)?.get(conditionSourceField);
                actualValue = String.valueOf(b);
            } else if (conditionDataType == 'Number') { //Format decimals as a string.
                Decimal d = (Decimal) mapRelatedFieldValues?.get(conditionSourceMap)?.get(conditionSourceField);
                actualValue = d.format().replaceAll(',','');
            } else { //Format all other actual values as strings.
                actualValue = (String) mapRelatedFieldValues?.get(conditionSourceMap)?.get(conditionSourceField);
            }
        }
        System.debug('--actualValue: ' + actualValue);
        return actualValue;
    }

    private static String convertConditionValueToString(String conditionDataType, String conditionOperatorType, String conditionQualifyingValue, String conditionInterval){
        String conditionValue = '';
        switch on conditionOperatorType {
            when 'Literal' {
                if (conditionDataType == 'Date') { //Convert qualifying date values to milliseconds from 1/1/1970 and format as a string.
                    Datetime d_qual = date.valueOf(conditionQualifyingValue);
                    conditionValue = d_qual.getTime().format();
                } else if (conditionDataType == 'Number') {
                    conditionValue = conditionQualifyingValue.replaceAll(',','');
                } else { //Format all other qualifying values as strings.
                    conditionValue = conditionQualifyingValue;
                }
                if (conditionValue == null) {
                    conditionValue = '';
                }
            }
            when 'System Variable' { //Determine exact qualifying date from relative date, then convert to milliseconds from 1/1/1970 and format as a string.
                switch on conditionInterval {
                    when 'Days' {
                        Datetime now = System.Now();
                        conditionValue = now.addDays(Integer.valueOf(conditionQualifyingValue)).getTime().format();
                    }
                    when 'Months' {
                        Datetime now = System.Now();
                        conditionValue = now.addMonths(Integer.valueOf(conditionQualifyingValue)).getTime().format();
                    }
                    when 'Years' {
                        Datetime now = System.Now();
                        conditionValue = now.addYears(Integer.valueOf(conditionQualifyingValue)).getTime().format();
                    }
                    when 'Today' {
                        Datetime today = (Datetime) System.Today();
                        conditionValue = today.getTime().format();
                    }
                    when 'Now' {
                        Datetime now = System.Now();
                        conditionValue = now.getTime().format();
                    }
                }
            }
        }
        System.debug('--conditionValue: ' + conditionValue);
        return conditionValue;
    }

    private static Boolean compareActualandConditionValues(String conditionDataType, String conditionOperator, String actualValue, String conditionValue){
        //System.debug(actualValue);
        //System.debug(conditionValue);
        Boolean matchesThisCondition = true;
        switch on conditionOperator{
            when 'Equal To' {
                if (!(actualValue == conditionValue)) {
                    matchesThisCondition = false;
                }
            }
            when 'Greater Than' {
                if (conditionDataType == 'Number' && !String.isBlank(actualValue) && !String.isBlank(conditionValue)) { //If the Source Field Data Type is Number...
                    Decimal actualValueAsNumber = Decimal.valueOf(actualValue); //...convert actual string back to decimal for greater/less than comparisons.
                    Decimal conditionValueAsNumber = Decimal.valueOf(conditionValue); //...convert condition string back to decimal for greater/less than comparisons.
                    if (!(actualValueAsNumber > conditionValueAsNumber)) {
                        matchesThisCondition = false;
                    }
                } else {
                    if (!(actualValue > conditionValue)) {
                        matchesThisCondition = false;
                    }
                }

            }
            when 'Greater Than Or Equal To' {
                if (conditionDataType == 'Number' && !String.isBlank(actualValue) && !String.isBlank(conditionValue)) {
                    Decimal actualValueAsNumber = Decimal.valueOf(actualValue);
                    Decimal conditionValueAsNumber = Decimal.valueOf(conditionValue);
                    if (!(actualValueAsNumber >= conditionValueAsNumber)) {
                        matchesThisCondition = false;
                    }
                } else {
                    if (!(actualValue >= conditionValue)) {
                        matchesThisCondition = false;
                    }
                }
            }
            when 'Less Than' {
                if (conditionDataType == 'Number' && !String.isBlank(actualValue) && !String.isBlank(conditionValue)) {
                    Decimal actualValueAsNumber = Decimal.valueOf(actualValue);
                    Decimal conditionValueAsNumber = Decimal.valueOf(conditionValue);
                    if (!(actualValueAsNumber < conditionValueAsNumber)) {              
                        matchesThisCondition = false;
                    }
                } else {
                    if (!(actualValue < conditionValue)) {
                        matchesThisCondition = false;
                    }
                }
            }
            when 'Less Than Or Equal To' {
                if (conditionDataType == 'Number' && !String.isBlank(actualValue) && !String.isBlank(conditionValue)) {
                    Decimal actualValueAsNumber = Decimal.valueOf(actualValue);
                    Decimal conditionValueAsNumber = Decimal.valueOf(conditionValue);
                    if (!(actualValueAsNumber <= conditionValueAsNumber)) {
                        matchesThisCondition = false;
                    }
                } else {
                    if (!(actualValue <= conditionValue)) {
                        matchesThisCondition = false;
                    }
                }
            }
            when 'Not Equal To' {
                if (!(actualValue != conditionValue)) {
                    matchesThisCondition = false;
                }
            }
        }
        return matchesThisCondition;
    }
    
    public static Map<String, Map<String, Object>> mapRelatedFieldValues { get {
        if (mapRelatedFieldValues == null) {
            mapRelatedFieldValues = new Map <String, Map<String, Object>>();
            String accountId;
            String caseId;
            String contactId;
            String opportunityId;

            //Get record fields from the allRecordFields map created earlier.
            List<String> parentRecordFields = new List<String>(allRecordFields.get(objectType));

            //Add in any component property locations that have been set to support inheriting icons.
            if (!String.isBlank(accountLocation) && accountLocation != 'Id') parentRecordFields.add(accountLocation);
            if (!String.isBlank(caseLocation) && caseLocation != 'Id') parentRecordFields.add(caseLocation);
            if (!String.isBlank(contactLocation) && contactLocation != 'Id') parentRecordFields.add(contactLocation);
            if (!String.isBlank(opportunityLocation) && opportunityLocation != 'Id') parentRecordFields.add(opportunityLocation);

            //Query the initial record.
            String recordQueryString = 'SELECT ' + String.join(parentRecordFields,',') + ' FROM ' + objectType + ' WHERE Id = \'' +  recordId + '\'  LIMIT 1';
            System.debug(recordQueryString);

            sObject record;
            
            try {
                record = Database.query(recordQueryString);
                Map<String, Object> parentFieldsToValue = record.getPopulatedFieldsAsMap();
                if (!String.isBlank(accountLocation) && accountLocation != 'Id') {
                    if (accountLocation.contains('.')) {
                        sObject parent = (sObject) parentFieldsToValue.get(String.valueOf(accountLocation.split('\\.')[0])); // i.e. Case__r
                        accountId = (String) parent.get(String.valueOf(accountLocation.split('\\.')[1])); // i.e. Account Id, Account__c, etc.
                    } else {
                        accountId = (String) record.get(accountLocation);
                    }
                }
                if (!String.isBlank(caseLocation) && caseLocation != 'Id') {
                    if (caseLocation.contains('.')) {
                        sObject parent = (sObject) record.get(String.valueOf(caseLocation.split('\\.')[0])); // i.e. Custom_Child_Object__r
                        caseId = (String) parent.get(String.valueOf(caseLocation.split('\\.')[1])); // i.e. Case, Case__c, etc.
                    } else {
                        caseId = (String) record.get(caseLocation);
                    }
                }
                if (!String.isBlank(contactLocation) && contactLocation != 'Id') {
                    if (contactLocation.contains('.')) {
                        sObject parent = (sObject) record.get(String.valueOf(contactLocation.split('\\.')[0])); // i.e. Custom_Child_Object__r
                        contactId = (String) parent.get(String.valueOf(contactLocation.split('\\.')[1])); // i.e. ContactId, Contact__c, etc.
                    } else {
                        contactId = (String) record.get(contactLocation);
                    }
                }
                if (!String.isBlank(opportunityLocation) && opportunityLocation != 'Id') {
                    if (opportunityLocation.contains('.')) {
                        sObject parent = (sObject) record.get(String.valueOf(opportunityLocation.split('\\.')[0])); // i.e. Custom_Child_Object__r
                        opportunityId = (String) parent.get(String.valueOf(opportunityLocation.split('\\.')[1])); // i.e. OpportunityId, Opportunity__c, etc.
                    } else {
                        opportunityId = (String) record.get(opportunityLocation);
                    }
                }
                mapRelatedFieldValues.put(objectType, parentFieldsToValue);
            } catch (Exception ex) {
                System.debug('ERROR: Issue with querying parent record or setting/adding related id fields.');
            }

            //Query any related objects indicated by the component property locations and add these values to the map.
            try {
                if (accountId != null) {
                    List<String> accountFields = allRecordFields.get('Account');
                    String accountQueryString = 'SELECT ' + String.join(accountFields,',') + ' FROM Account WHERE Id = \'' +  accountId + '\'  LIMIT 1';
                    sObject accountRecord = Database.query(accountQueryString);
                    Map<String, Object> accountFieldsToValue = accountRecord.getPopulatedFieldsAsMap();
                    //System.debug(accountQueryString);
                    //System.debug(accountFieldsToValue);
                    mapRelatedFieldValues.put('Account', accountFieldsToValue);
                }
                if (caseId != null) {
                    List<String> caseFields = allRecordFields.get('Case');
                    String caseQueryString = 'SELECT ' + String.join(caseFields,',') + ' FROM Case WHERE Id = \'' +  caseId + '\'  LIMIT 1';
                    sObject caseRecord = Database.query(caseQueryString);
                    Map<String, Object> caseFieldsToValue = caseRecord.getPopulatedFieldsAsMap();
                    //System.debug(caseQueryString);
                    //System.debug(caseFieldsToValue);
                    mapRelatedFieldValues.put('Case', caseFieldsToValue);
                }
                if (contactId != null) {
                    List<String> contactFields = allRecordFields.get('Contact');
                    String contactQueryString = 'SELECT ' + String.join(contactFields,',') + ' FROM Contact WHERE Id = \'' +  contactId + '\'  LIMIT 1';
                    sObject contactRecord = Database.query(contactQueryString);
                    Map<String, Object> contactFieldsToValue = contactRecord.getPopulatedFieldsAsMap();
                    //System.debug(contactQueryString);
                    //System.debug(contactFieldsToValue);
                    mapRelatedFieldValues.put('Contact', contactFieldsToValue);
                }
                if (opportunityId != null) {
                    List<String> opportunityFields = allRecordFields.get('Opportunity');
                    String opportunityQueryString = 'SELECT ' + String.join(opportunityFields,',') + ' FROM Opportunity WHERE Id = \'' +  opportunityId + '\'  LIMIT 1';
                    sObject opportunityRecord = Database.query(opportunityQueryString);
                    Map<String, Object> opportunityFieldsToValue = opportunityRecord.getPopulatedFieldsAsMap();
                    //System.debug(contactQueryString);
                    //System.debug(contactFieldsToValue);
                    mapRelatedFieldValues.put('Opportunity', opportunityFieldsToValue);
                }
            } catch (Exception ex) {
                System.debug('ERROR: Issue with the queries to build the related fields map.');
            }
            System.debug(mapRelatedFieldValues);
        }
        return mapRelatedFieldValues;
    } set; }
}