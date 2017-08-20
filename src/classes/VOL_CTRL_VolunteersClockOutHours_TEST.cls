@IsTest
public class VOL_CTRL_VolunteersClockOutHours_TEST {
	
    //==================== TEST METHOD(s) ======================================
    public static testmethod void TestClockout() {
        Campaign cmp = new Campaign(recordtypeid=VOL_SharedCode.recordtypeIdVolunteersCampaign, name='Test Job Campaign', IsActive=true);
        insert cmp;
        Volunteer_Job__c job = new Volunteer_Job__c(name='Job1', campaign__c=cmp.Id, Display_on_Website__c=true);
        insert job;
        Volunteer_Shift__c shift = new Volunteer_Shift__c(Volunteer_Job__c=job.Id, Duration__c=1, Start_Date_Time__c=System.now());
        insert shift;
        Contact con1 = new Contact();
            con1.FirstName = 'TestFirstName1';
            con1.LastName = 'TestLastName1';
            con1.Email = 'foovolunteer@bar.com';
        insert con1;
        Contact con2 = new Contact();
            con2.FirstName = 'TestFirstName2';
            con2.LastName = 'TestLastName2';
            con2.Email = 'foovolunteer2@bar.com';
        insert con2;
        Contact con3 = new Contact();
            con3.FirstName = 'TestFirstName3';
            con3.LastName = 'TestLastName3';
            con3.Email = 'foovolunteer3@bar.com';
        insert con3;
        
        Volunteer_Hours__c hr1 = new Volunteer_Hours__c(
        	Contact__c=con1.id,
            Volunteer_Job__c = job.Id,
            Volunteer_Shift__c = shift.Id,
            Clock_In_Time__c = system.now()-0.5/24/60,
            Start_Date__c = System.Today(),
            End_Date__c = System.Today(),
            Status__c = 'In Progress'
        );
        insert hr1;
        Volunteer_Hours__c hr2 = new Volunteer_Hours__c(
        	Contact__c=con2.id,
            Volunteer_Job__c = job.Id,
            Volunteer_Shift__c = shift.Id,
            Start_Date__c = System.Today(),
            End_Date__c = System.Today(),
            Status__c = 'Confirmed'
        );
        insert hr2;
        Volunteer_Hours__c hr3 = new Volunteer_Hours__c(
        	Contact__c=con3.id,
            Volunteer_Job__c = job.Id,
            Volunteer_Shift__c = shift.Id,
            Clock_In_Time__c = system.now()-0.5/24/60,
            Start_Date__c = System.Today(),
            End_Date__c = System.Today(),
            Status__c = 'In Progress'
        );
        insert hr3;
        
        List<Volunteer_Hours__c> selHrs = [select id,name,
                                           Status__c,
                                           Clock_In_Time__c,
                                           Clock_Out_Time__c,
                                           End_Date__c,
                                           Hours_Worked__c,
                                           System_Note__c from Volunteer_Hours__c where Status__c='In Progress'];
        
        ApexPages.StandardSetController ctrl = new ApexPages.StandardSetController(selHrs);
        VOL_CTRL_VolunteersClockOutHours extension = new VOL_CTRL_VolunteersClockOutHours(ctrl);  
       
        ctrl.setSelected(selHrs);
        system.assert(ctrl.getSelected()!=null);
        extension.clockOut();
        
        List<Volunteer_Hours__c> hrs = [select id,name from Volunteer_Hours__c where Status__c='Completed'];
        system.assertEquals(hrs.size(),2);
        
    }
    
}