/*  Customized for Kramden
    Copyright (c) 2016, Salesforce.org
    All rights reserved.
    
    Redistribution and use in source and binary forms, with or without
    modification, are permitted provided that the following conditions are met:
    
    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
    * Neither the name of Salesforce.org nor the names of
      its contributors may be used to endorse or promote products derived
      from this software without specific prior written permission.
 
    THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
    "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT 
    LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS 
    FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE 
    COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, 
    INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, 
    BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; 
    LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER 
    CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT 
    LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN 
    ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE 
    POSSIBILITY OF SUCH DAMAGE.
*/

global virtual with sharing class VOL_CTRL_VolunteersReportHours {
  
    private VOL_SharedCode volSharedCode; 
     
    // constructor
    global VOL_CTRL_VolunteersReportHours() {
        try {
            volSharedCode = new VOL_SharedCode();

            // initial values for potential parameters
            strLanguage = 'en-us'; 
            strDateFormat = 'EEEE M/d/yyyy';
            strTimeFormat = 'h:mm tt';

            // handle optional page parameters (must use string, not ID, to handle null)
            map<string, string> params = ApexPages.currentPage().getParameters();
            string p = params.get('Language');
            if (p != null && p != '') strLanguage = p;
            p = params.get('DateFormat');
            if (p != null && p != '') strDateFormat = p;
            p = params.get('TimeFormat');
            if (p != null && p != '') strTimeFormat = p;
        
        // Kramden Custom Start
        p = params.get('contactId');
        if (p != null && p != '') {
            try {
                contactIdPersonalSite = p;
            } catch (Exception ex) {
                contactIdPersonalSite = null;
            }

            // now get new email parameter for extra validation
            // note that the validation routine only uses it if the setting for this extra validation is set
            if (!VOL_SharedCode.isValidContactIdAndEmail(contactIdPersonalSite, params.get('Email')))
                contactIdPersonalSite = null;

            // cache the contactId for all pages to use.
            Cookie cId = new cookie('contactIdPersonalSite', contactIdPersonalSite, null, -1, false);
            ApexPages.currentPage().setCookies(new Cookie[] {cId});
        } else {
            // check for cached Id
            Cookie cId = ApexPages.currentPage().getCookies().get('contactIdPersonalSite');
            if (cId != null) contactIdPersonalSite = cId.getValue();
        }
        // Kramden Custom End

        // we now get the fields from the fieldset
        listStrFields = VOL_SharedCode.listStrFieldsFromContactFieldSet(Schema.SObjectType.Contact.fieldSets.VolunteersReportHoursFS);

        // output error page messages for any field that doesn't have visibility correctly set.
        VOL_SharedCode.testObjectFieldVisibility('Contact', listStrFields);

        // we can derive whether we are within the Personal Site or not, so no need for parameter.
        fPersonalSite = ApexPages.currentPage().getUrl().contains('PersonalSite');

            checkCreateAccess();
            checkUpdateAccess();

        //Get the setting for allowing volunteers to log their own time or NotFoundException
        boolVolEditHrs = VOL_SharedCode.VolunteersSettings.Personal_Site_Edit_Hours__c;
        boolFilterTodaysJobs = VOL_SharedCode.VolunteersSettings.Personal_Site_Filter_Todays_Jobs__c;
        boolHideClockOut = false;
    }
        catch(Exception e) {
            ApexPages.addMessages(e);
        }
    } 
            
    // holds the contact fields on the page            
    global Contact contact { 
        get {
            if (contact == null) {
                contact = new Contact();

                // when used within the Personal Site, we should use the appropriate Contact
                contactIdPersonalSite = null;
                Cookie cId = ApexPages.currentPage().getCookies().get('contactIdPersonalSite');
                if (cId != null) contactIdPersonalSite = cId.getValue();
                if (contactIdPersonalSite != null && contactIdPersonalSite != '') {
                    VOL_SharedCodeAPI25.LoadAndCopyObject(contactIdPersonalSite, contact, listStrFields);                   
                } else {
                    // if state & country picklists enabled, we want to copy in any defaults from state/country Code to 
                    // the state & country fields, since the picklists cannot be included in the field set.
                    if (VOL_StateCountryPicklists.isStateCountryPicklistsEnabled) {
                        VOL_StateCountryPicklists.copyAddressStdSObj(contact, 'Mailing', contact, 'Mailing');
                        VOL_StateCountryPicklists.copyAddressStdSObj(contact, 'Other', contact, 'Other');
                    }
                }
            }
            return contact;
        }       
        set; 
    }
    
    private string contactIdPersonalSite { get; set; }
    
    // holds the dates and hours fields on the page
    global Volunteer_Hours__c vhours {
        get {
            if (vhours == null) vhours = new Volunteer_Hours__c();
            return vhours;
        }
        set;
    }

    // returns the correct URL for the CSS override file
    global string strURLtoCSSFile { 
        get { 
            if (fPersonalSite) return null; // just use whatever CSS the Site Template includes.

            if (strURLtoCSSFile == null) {
                list<Document> listDocs = [SELECT Name, Id From Document WHERE Name = 'VolunteersReportHoursCSS.css' LIMIT 1 ];
                if (listDocs.size() > 0) {
                    Document doc = listDocs[0];
                    string imageid = doc.id;
                    imageid = imageid.substring(0,15);
                    strURLToCSSFile = '/servlet/servlet.FileDownload?file=' + imageid;
                }
            }
            return strURLtoCSSFile;
        }  
        
        set;
    }
    
    // global properties
    global string strLanguage { get; set; }
    global string strDateFormat { get; set; }
    global string strTimeFormat { get; set; }
    global list<string> listStrFields { get; set; } 
    global boolean fPersonalSite { get; set; }
    global boolean boolVolEditHrs { get; set; }
    global boolean boolFilterTodaysJobs { get; set; }
    global boolean boolHideClockOut { get; set; }

    // status string for reporting the results of saving.
    global String strSaveResult { get; set; }    
    
    // holds the currently select Job in the Job dropdown
    global ID volunteerJobId { get; set; }
    
    // returns true when jobs are available for contact
    // we check the size against 1 (not 0) becasue of the first empty select option
    global Boolean hasVolunteerJobs {
        get { 
            return 1 < listSOVolunteerJobs.size();
        }
        set;
    }
    
    // the list of Volunteer Jobs to put in the dropdown
    global list<SelectOption> listSOVolunteerJobs {
        get {
            if (listSOVolunteerJobs == null) {              
                listSOVolunteerJobs = new list<SelectOption>();
                listSOVolunteerJobs.add(new SelectOption('', ''));
                
                Boolean filterByContact = VOL_SharedCode.VolunteersSettings.Personal_Site_Report_Hours_Filtered__c;
                List<Volunteer_Job__c> volunteerJobs = new List<Volunteer_Job__c>();
                if (filterByContact && contactIdPersonalSite != null && boolFilterTodaysJobs) {
                    volunteerJobs = [select Name, Id,
                                            (select Id, Contact__c from Volunteer_Hours__r
                                            where Contact__c = :contactIdPersonalSite
                                            and Status__c in ('Web Sign Up','Confirmed') LIMIT 1)
                                        from Volunteer_Job__c
                                        where Campaign__r.IsActive = true and Inactive__c = false
                                        and id in (
                                        select Volunteer_Job__c from Volunteer_Hours__c
                                          where Volunteer_Shift__r.Start_Date_Time__c > YESTERDAY
                                          and Volunteer_Shift__r.Start_Date_Time__c < TOMORROW
                                          and Contact__c = :contactIdPersonalSite
                                          and Status__c in ('Web Sign Up','Confirmed'))
                                        order by name limit 999];
                } else if(filterByContact && contactIdPersonalSite != null && boolFilterTodaysJobs == false) {
                  volunteerJobs = [select Name, Id,
                                          (select Id, Contact__c from Volunteer_Hours__r
                                          where Contact__c = :contactIdPersonalSite
                                          and Status__c in ('Web Sign Up','Confirmed') LIMIT 1)
                                      from Volunteer_Job__c
                                      where Campaign__r.IsActive = true and Inactive__c = false
                                      and id in (
                                      select Volunteer_Job__c from Volunteer_Hours__c
                                      where Contact__c = :contactIdPersonalSite
                                        and Status__c in ('Web Sign Up','Confirmed'))
                                      order by name limit 999];
                } else {
                    volunteerJobs = [select Name, Id
                                    from Volunteer_Job__c
                                    where Campaign__r.IsActive = true and Inactive__c = false 
                                    order by name limit 999];
                }
                
                for (Volunteer_Job__c vj : volunteerJobs) {
                    if(filterByContact && contactIdPersonalSite != null) {
                        for (Volunteer_Hours__c volHour : vj.Volunteer_Hours__r) {
                            listSOVolunteerJobs.add(new SelectOption(vj.id, vj.name));
                        }               
                    } else {
                        listSOVolunteerJobs.add(new SelectOption(vj.id, vj.name));
                    }
                }
            }
            return listSOVolunteerJobs;
        }
        
        set;
    }

    // the user has changed the Volunteer Job dropdown
    global virtual PageReference ChangeVolunteerJob() {
        // clear out all state that is specific to the Job
        strSaveResult = null;
        listSOVolunteerShifts = null;
        volunteerShiftId = null;
        ChangeVolunteerShift();
        return null;
    }

    // holds the currently select Job Shift in the Job Shift dropdown
    global ID volunteerShiftId { get; set; }
    
    // the list of Volunteer Shifts to put in the dropdown
    global list<SelectOption> listSOVolunteerShifts {
        get {
            if (listSOVolunteerShifts == null && volunteerJobId != null) {
               if(boolFilterTodaysJobs) {
                 listSOVolunteerShifts = VOL_SharedCode.listSORegisteredVolunteerShiftsOfVolunteerJobIdFormat(volunteerJobId,
                          system.today(), system.today(), false, false, strDateFormat, strTimeFormat);
               } else {
                 listSOVolunteerShifts = VOL_SharedCode.listSOVolunteerShiftsOfVolunteerJobIdFormat(volunteerJobId,
                      system.today().addMonths(-2), system.today().addMonths(1), false, false, strDateFormat, strTimeFormat);
               }
            }
            return listSOVolunteerShifts;
        }
        
        set;
    }

    // specifies whether the currently selected Job has any Shifts.
    global boolean hasShifts { 
        get {
            return listSOVOlunteerShifts != null && listSOVolunteerShifts.size() > 1;
        }
        set; 
    }

    // the user has changed the Volunteer Shift dropdown
    global virtual PageReference ChangeVolunteerShift() {
        // clear out info
        strSaveResult = null;       
        vhours.Start_Date__c = null;
        vhours.End_Date__c = null;
        vhours.Hours_Worked__c = null;
        vhours.Volunteer_Job__c = volunteerJobId;
        vhours.Volunteer_Shift__c = volunteerShiftId;
        
        // set date and hours from shift
        if (volunteerShiftId != null) {
            Volunteer_Shift__c shift = [select Start_Date_Time__c, Duration__c from Volunteer_Shift__c
                where Id = :volunteerShiftId];
            vhours.Start_Date__c = shift.Start_Date_Time__c.Date();
            vhours.End_Date__c = vhours.Start_Date__c;
            vhours.Hours_Worked__c = shift.Duration__c;
        }
        return null;        
    }

    private class MyException extends Exception {}


    // action method for saving the the volunteer's hours.    
    global virtual PageReference Save() {
        Savepoint sp = Database.setSavepoint();
        try {
            // because we need to use actionSupport immediate=false to support the combo's,
            // we couldn't actually use visualforce's required=true property on fields.
            // so we must manually enforce the fields we want required ourselves.
            boolean hasErrors = false;

            // first deal with fields on the contact.
            for (Schema.FieldSetMember f : SObjectType.Contact.FieldSets.VolunteersReportHoursFS.getFields()) {
                if (contact.get(f.getFieldPath()) == null && (f.getDBRequired() || f.getRequired())) {
                    ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.FATAL, 
                        String.Format(system.label.labelVolunteerReportHoursErrorRequiredField, new string[] { f.getLabel() })));   
                    hasErrors = true;   
                }           
            }   

            if (volunteerJobId == null) {
                ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.FATAL, 
                    String.Format(system.label.labelVolunteerReportHoursErrorRequiredField, new string[] { Schema.sObjectType.Volunteer_Hours__c.fields.Volunteer_Job__c.getLabel() })));   
                hasErrors = true;               
            }
            if (vhours.Start_Date__c == null) {
                ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.FATAL, 
                    String.Format(system.label.labelVolunteerReportHoursErrorRequiredField, new string[] { Schema.sObjectType.Volunteer_Hours__c.fields.Start_Date__c.getLabel() })));  
                hasErrors = true;               
            }
            if (vhours.End_Date__c == null) {
                ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.FATAL, 
                    String.Format(system.label.labelVolunteerReportHoursErrorRequiredField, new string[] { Schema.sObjectType.Volunteer_Hours__c.fields.End_Date__c.getLabel() })));    
                hasErrors = true;               
            }
            if (vhours.Hours_Worked__c == null) {
                ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.FATAL, 
                    String.Format(system.label.labelVolunteerReportHoursErrorRequiredField, new string[] { Schema.sObjectType.Volunteer_Hours__c.fields.Hours_Worked__c.getLabel() })));    
                hasErrors = true;               
            }
            
            // check additional fields on the vol hours
            for (Schema.FieldSetMember f : SObjectType.Volunteer_Hours__c.FieldSets.VolunteersReportHoursFS.getFields()) {
                if (vhours.get(f.getFieldPath()) == null && (f.getDBRequired() || f.getRequired())) {
                    ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.FATAL, 
                        String.Format(system.label.labelVolunteerReportHoursErrorRequiredField, new string[] { f.getLabel() })));   
                    hasErrors = true;   
                }           
            }
            

            // now bail out if any required fields are missing.                     
            if (hasErrors) {
                system.debug('It Bailed');
                strSaveResult = null;
                return null;            
            }           
            // listStrFields = new string[]{'FirstName', 'LastName', 'Email'};
            system.debug('Save() ' + listStrFields);
            // save or update the contact               
            ID contactId = VOL_SharedCode.CreateOrUpdateContactFS(contactIdPersonalSite, contact, contact.Volunteer_Organization__c, listStrFields, false);
 
            list<Volunteer_Hours__c> listHours = null;

            if (volunteerShiftId != null) {
                // search for an existing Hours record to update, if they specified a Shift
                listHours = [select Id from Volunteer_Hours__c where 
                    Volunteer_Shift__c = :volunteerShiftId and Contact__c = :contactId];
            } else {
                // search for an existing Hours record to update for this job 
                // match non-committed hours, or committed where the start date is the same.
                listHours = [select Id from Volunteer_Hours__c where 
                    Volunteer_Job__c = :volunteerJobId and Contact__c = :contactId and 
                    (Status__c <> 'Completed' or Start_Date__c = :vhours.Start_Date__c) ];              
            }

            // if we found a matching Hours, just update it
            if (listHours != null && listHours.size() > 0) {
                checkUpdateAccess();

                listHours[0].Status__c = 'Completed';
                listHours[0].Start_Date__c = vhours.Start_Date__c;
                listHours[0].End_Date__c = vhours.End_Date__c;
                listHours[0].Hours_Worked__c = vhours.Hours_Worked__c;
            
                // update the additional fields, if any
                for (Schema.FieldSetMember f : SObjectType.Volunteer_Hours__c.FieldSets.VolunteersReportHoursFS.getFields()) {
                    String fieldName = f.getFieldPath();
                    if (vhours.get(fieldName) != null) {
                        listHours[0].put(fieldName, vhours.get(fieldName));
                    }   
                }   

                update listHours[0];
            } else {        
                checkCreateAccess();

                // create new hours if needed
                vhours.Volunteer_Job__c = volunteerJobId;
                vhours.Volunteer_Shift__c = volunteerShiftId;
                vhours.Status__c = 'Completed';
                vhours.Contact__c = contactId;
                vhours.Number_of_Volunteers__c = 1;
                insert vhours;
            }

            // clear current job & shift info
            volunteerJobId = null;
            ChangeVolunteerJob();
            vhours = null;

            strSaveResult = system.label.labelVolunteerReportHoursThankYou;
        } catch (DMLException ex) {
            Database.rollback(sp);
            //Added check for FIELD_CUSTOM_VALIDATION_EXCEPTION to return user friendly error.
            strSaveResult = ex.getMessage(); 
            if (strSaveResult.contains('FIELD_CUSTOM_VALIDATION_EXCEPTION')) {
                strSaveResult = strSaveResult.substringBetween('FIELD_CUSTOM_VALIDATION_EXCEPTION, ', ': ');
            }
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.FATAL, strSaveResult));
            // strSaveResult = null;
        } catch (exception ex) {
            Database.rollback(sp);
            // strSaveResult = null;
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.FATAL, ex.getMessage()));                     
        }
        return null;
    }

    /*******************************************************************************************************
    * @description check if the current user has a "Create" permission on the listed fields
    * @return void.
    ********************************************************************************************************/
    private void checkCreateAccess() {
        UTIL_Describe.checkCreateAccess(
            UTIL_Describe.StrTokenNSPrefix('Volunteer_Hours__c'),
            new Set<String>{
                UTIL_Describe.StrTokenNSPrefix('Volunteer_Job__c'),
                UTIL_Describe.StrTokenNSPrefix('Volunteer_Shift__c'),
                UTIL_Describe.StrTokenNSPrefix('Status__c'),
                UTIL_Describe.StrTokenNSPrefix('Contact__c'),
                UTIL_Describe.StrTokenNSPrefix('Number_of_Volunteers__c')
            }
        );
    }

    /*******************************************************************************************************
    * @description check if the current user has a "Edit" permission on the listed fields
    * @return void.
    ********************************************************************************************************/
    private void checkUpdateAccess() {
        Set<String> flsCheckFields = new Set<String> {
            UTIL_Describe.StrTokenNSPrefix('End_Date__c'),
            UTIL_Describe.StrTokenNSPrefix('Hours_Worked__c'),
            UTIL_Describe.StrTokenNSPrefix('Start_Date__c'),
            UTIL_Describe.StrTokenNSPrefix('Status__c')
        };

        // Get the additional fields from the FieldSet
        for (Schema.FieldSetMember f : SObjectType.Volunteer_Hours__c.FieldSets.VolunteersReportHoursFS.getFields()) {
            if (vhours.get(f.getFieldPath()) != null) {
                flsCheckFields.add(f.getFieldPath());
            }
        }

        UTIL_Describe.checkUpdateAccess(UTIL_Describe.StrTokenNSPrefix('Volunteer_Hours__c'), flsCheckFields);
    }

    // this was a testmethod which can't be compiled in this class under api 31.  
    // but because it was marked global, it could not be completely removed.
    global static void CodeCoverageTests() {}

    global void ClockIn() {
        DateTime d = datetime.now();
        // listStrFields = new string[]{'FirstName', 'LastName', 'Email'};
        ID contactId = VOL_SharedCode.CreateOrUpdateContactFS(contactIdPersonalSite, contact, contact.Volunteer_Organization__c, listStrFields, false);
        Volunteer_Hours__c regHourId = null;

        regHourId = [select Id, Clock_In_Time__c
                     from Volunteer_Hours__c
                     where
                       Contact__c = :contactId and
                       Volunteer_Job__c = :volunteerJobId and
                       Volunteer_Shift__c = :volunteerShiftId
                       order by Start_Date__c limit 1
                     ];

        regHourId.Clock_In_Time__c = d;
        regHourId.Status__c = 'In Progress';
        regHourId.Start_Date__c = date.today();
        regHourId.System_Note__c = 'Logged In By Volunteer';

        update regHourId;

        volunteerJobId = null;
        ChangeVolunteerJob();
        vhours = null;

        strSaveResult = system.label.labelClockInMessage;
        //Hide the Clock Out button immediately after logging in to prvent confusion
        boolHideClockOut = true;
    }

    global void ClockOut() {
      vhours = GetOpenHours();

      DateTime d = datetime.now();
      Long endTime = d.gettime();
      Long startTime = vhours.Clock_In_Time__c.gettime();

      vhours.Clock_Out_Time__c = d;
      vhours.Hours_Worked__c = decimal.valueof(endTime - startTime) / 1000/60/60; //milliseconds to seconds to minutes to hours
      vhours.End_Date__c = d.date();
      vhours.Status__c = 'Completed';
      vhours.System_Note__c = 'Logged Out By Volunteer';
      update vhours;

      Datetime f = (Datetime)vhours.get('Clock_Out_Time__c');
      strSaveResult = 'You logged in at ' + vhours.Clock_In_Time__c.format('MM/dd/yyyy h:mm:ss a','America/New_York');
    }

    global Volunteer_Hours__c GetOpenHours() {
        // listStrFields = new string[]{'FirstName', 'LastName', 'Email'};
        system.debug('getopenhours ' + listStrFields);
        ID contactId = VOL_SharedCode.CreateOrUpdateContactFS(contactIdPersonalSite, contact, contact.Volunteer_Organization__c, listStrFields, false);
        list<Volunteer_Hours__c> openHourId = null;

        openHourId = [select Id, Clock_In_Time__c from Volunteer_Hours__c where Contact__c = :contactId and
                    (Status__c = 'In Progress') order by Clock_In_Time__c asc limit 1 ];  //change 'In Progress' to label

        if (openHourId.IsEmpty()){
          return null;
        } else {
          return openHourId[0];
        }
    }

    // specifies whether the volunteer is currently logged into the system
    global Boolean IsClockedIn {
        get {
          return GetOpenHours() != null;
        }
        set;
    }
}
