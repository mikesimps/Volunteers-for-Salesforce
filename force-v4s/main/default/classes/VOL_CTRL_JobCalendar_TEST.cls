/*
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

@isTest
private  class VOL_CTRL_JobCalendar_TEST {

    //==================== TEST METHOD(s) ======================================
    private static testmethod void TestJobCalendar() {
    	
		// create test data
        Campaign cmp = new Campaign(recordtypeid=VOL_SharedCode.recordtypeIdVolunteersCampaign, 
        	name='Job Calendar Test Campaign', IsActive=true);
        insert cmp;
        Volunteer_Job__c job = new Volunteer_Job__c(name='Job1', campaign__c=cmp.Id);
        insert job;
        Volunteer_Shift__c shift = new Volunteer_Shift__c(Volunteer_Job__c=job.Id, Duration__c=1, Start_Date_Time__c=System.now());
        insert shift;
    	
        //point to our VF page
        PageReference p = new PageReference('Page.JobCalendar');
        p.getParameters().put('campaignId', cmp.id); 
        p.getParameters().put('volunteerJobId', job.id);
        p.getParameters().put('volunteerShiftId', shift.id);
        Test.setCurrentPageReference(p);
    	
    	// start testing!
		list<Volunteer_Shift__c> listS = VOL_CTRL_JobCalendar.getListShifts('*', '*', '2010-01-01 1:1:1', '2050-01-01 1:1:1');
		system.assert(listS.size() > 0); 
		listS = VOL_CTRL_JobCalendar.getListShifts(cmp.Id, '*', '2010-01-01 1:1:1', '2050-01-01 1:1:1');
		system.assert(listS.size() == 1); 
		listS = VOL_CTRL_JobCalendar.getListShifts(cmp.Id, job.Id, '2010-01-01 1:1:1', '2050-01-01 1:1:1');
		system.assert(listS.size() == 1); 
		
        //instantiate the controller 
        VOL_CTRL_JobCalendar ctrl = new VOL_CTRL_JobCalendar();
		system.assert(ctrl.strURLtoCSSFile == null || ctrl.strURLtoCSSFile != null);
		system.assertEquals(null, ctrl.strLanguage);
		system.assertEquals(cmp.Id, ctrl.campaignId);
		system.assertEquals(job.Id, ctrl.volunteerJobId);
		system.assert(ctrl.listSOCampaigns.size() >= 2);
		system.assertEquals(shift.Start_Date_Time__c, ctrl.initialDate);
		system.assert(ctrl.listSOVolunteerJobs.size() >= 2);
		ctrl.campaignId = null;		
		ctrl.ChangeVolunteerJob();
		ctrl.ChangeCampaign();		 
		system.assert(ctrl.listSOVolunteerJobs.size() >= 2);

    }
    
    private static testmethod void testCampaignHierarchies() {

		//create our test data
		map<string, Campaign> mapCmp = VOL_SharedCode_TEST.mapCampaignTestHierarchy();
		ID cmpIdGrandparent = mapCmp.get('Grandparent').Id;
		system.assertNotEquals(null, cmpIdGrandparent);
    
    	// start testing!
		list<Volunteer_Shift__c> listS = VOL_CTRL_JobCalendar.getListShiftsWeb2(cmpIdGrandparent, '*', '2010-01-01 1:1:1', '2050-01-01 1:1:1', false, false);
		system.assertEquals(1, listS.size()); 
		listS = VOL_CTRL_JobCalendar.getListShiftsWeb2(cmpIdGrandparent, '*', '2010-01-01 1:1:1', '2050-01-01 1:1:1', false, true);
		system.assertEquals(mapCmp.size(), listS.size()); 
    }

    /*******************************************************************************************************
    * @description test timezone handling for Shifts under LA timezone
    * @return void
    */
    private static testMethod void testTimeZoneHandlingFromLA() {
        testTimeZoneHandling('America/Los_Angeles');
    }

    /*******************************************************************************************************
    * @description test timezone handling for Shifts under Sydney timezone
    * @return void
    */
    private static testMethod void testTimeZoneHandlingFromSydney() {
        testTimeZoneHandling('Australia/Sydney');
    }

    /*******************************************************************************************************
    * @description test timezone handling for Shifts
    * @param timezone what timezone to run under while creating and querying shifts
    * @return void
    */
    private static void testTimeZoneHandling(String timezone) {

        String uniqueUserName = 'admin' + DateTime.now().getTime() + '@testorg.com';
        Profile p = [SELECT Id FROM Profile WHERE Name='System Administrator'];
        User u = new User(Alias = 'admin', Email='admin@testorg.com',
            EmailEncodingKey='UTF-8', LastName='Testing', LanguageLocaleKey='en_US',
            LocaleSidKey='en_US', ProfileId = p.Id,
            TimeZoneSidKey=timezone,
            UserName=uniqueUserName);
        insert u;
        
        PermissionSet v4sPS = [SELECT Id FROM PermissionSet WHERE Name = 'V4S_Employee_Permissions' LIMIT 1];
        if (v4sPS != null) {
          insert new PermissionSetAssignment (AssigneeId = u.Id, PermissionSetId = v4sPS.Id); 
        }
        
        system.runAs(u) {
            VOL_SharedCode_TEST.setupTimeZoneTestData();

            list<Volunteer_Shift__c> listS = VOL_CTRL_JobCalendar.getListShiftsWeb('*', '*',
                datetime.newInstanceGMT(system.Today(), time.newInstance(0,0,0,0)).format('yyyy-MM-dd hh:mm:ss'),
                datetime.newInstanceGMT(system.Today(), time.newInstance(23,59,59,0)).format('yyyy-MM-dd hh:mm:ss'),
                false);
            system.assertEquals(24, listS.size(), 'we should get exactly one days worth of shifts, regardless of timezone');
        }
    }

}
