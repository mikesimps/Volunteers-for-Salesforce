/**
* @author Mike Simpson
* @date 4th January 2020
* @description Based on repository developed by Ben Edwards (beedwards@deloitte.co.nz) https://github.com/benedwards44/apex-batch-delete
*
* CHANGE LOG
**/

@isTest 
public class VOL_BATCH_DeleteUnusedRecords_TEST {
    
    @TestSetup
    static void makeData(){

        Campaign cmp = new Campaign(recordtypeid=VOL_SharedCode.recordtypeIdVolunteersCampaign, name='Test Job Campaign', IsActive=true);
        insert cmp;
        Volunteer_Job__c job = new Volunteer_Job__c(name='SUPER GEEK', campaign__c=cmp.Id, Display_on_Website__c=true);
        insert job;
        Volunteer_Job__c job2 = new Volunteer_Job__c(name='Another Job', campaign__c=cmp.Id, Display_on_Website__c=true);
        insert job2;
        Contact con1 = new Contact();
            con1.FirstName = 'TestFirstName1';
            con1.LastName = 'TestLastName1';
            con1.Email = 'foovolunteer@bar.com';
        insert con1;
        
        // Open VH Record for Super Geek Shift in the future
        Volunteer_Shift__c shift = new Volunteer_Shift__c(Volunteer_Job__c=job.Id, Duration__c=1, Start_Date_Time__c=System.Today()+2);
        insert shift;
        Volunteer_Hours__c hr1 = new Volunteer_Hours__c(
        	Contact__c=con1.id,
            Volunteer_Job__c = job.Id,
            Volunteer_Shift__c = shift.Id,
            Start_Date__c = System.Today()+2,
            End_Date__c = System.Today()+2,
            Status__c = 'Confirmed'
        );
        insert hr1;

        // Completed VH Record for Super Geek Shift yesterday
        shift = new Volunteer_Shift__c(Volunteer_Job__c=job.Id, Duration__c=1, Start_Date_Time__c=System.Today()-1);
        insert shift;
        Volunteer_Hours__c hr2 = new Volunteer_Hours__c(
        	Contact__c=con1.id,
            Volunteer_Job__c = job.Id,
            Volunteer_Shift__c = shift.Id,
            Clock_In_Time__c = system.now()-1-0.5/24/60,
            Clock_Out_Time__c = system.now()-1,
            Start_Date__c = System.Today()-1,
            End_Date__c = System.Today()-1,
            Status__c = 'Completed',
            Hours_Worked__c = 0.5
        );
        insert hr2;

        // Completed VH Record for Super Geek Shift last week
        shift = new Volunteer_Shift__c(Volunteer_Job__c=job.Id, Duration__c=1, Start_Date_Time__c=System.Today()-8);
        insert shift;
        Volunteer_Hours__c hr3 = new Volunteer_Hours__c(
        	Contact__c=con1.id,
            Volunteer_Job__c = job.Id,
            Volunteer_Shift__c = shift.Id,
            Clock_In_Time__c = system.now()-8-0.5/24/60,
            Clock_Out_Time__c = system.now()-8,
            Start_Date__c = System.Today()-8,
            End_Date__c = System.Today()-8,
            Status__c = 'Completed',
            Hours_Worked__c = 0.5
        );
        insert hr3;
        
        // Open VH Record for Super Geek Shift previous week
        shift = new Volunteer_Shift__c(Volunteer_Job__c=job.Id, Duration__c=1, Start_Date_Time__c=System.Today()-8);
        insert shift;
        Volunteer_Hours__c hr4 = new Volunteer_Hours__c(
        	Contact__c=con1.id,
            Volunteer_Job__c = job.Id,
            Volunteer_Shift__c = shift.Id,
            Start_Date__c = System.Today()-8,
            End_Date__c = System.Today()-8,
            Status__c = 'Confirmed'
        );
        insert hr4;

        // Completed VH Record for Different Job Shift previous week
        shift = new Volunteer_Shift__c(Volunteer_Job__c=job2.Id, Duration__c=1, Start_Date_Time__c=System.Today()-10);
        insert shift;
        Volunteer_Hours__c hr5 = new Volunteer_Hours__c(
        	Contact__c=con1.id,
            Volunteer_Job__c = job2.Id,
            Volunteer_Shift__c = shift.Id,
            Clock_In_Time__c = system.now()-10-0.5/24/60,
            Clock_Out_Time__c = system.now()-10,
            Start_Date__c = System.Today()-10,
            End_Date__c = System.Today()-10,
            Status__c = 'Completed',
            Hours_Worked__c = 0.5
        );
        insert hr5;

        // Open VH Record for Different Job Shift previous week
        shift = new Volunteer_Shift__c(Volunteer_Job__c=job2.Id, Duration__c=1, Start_Date_Time__c=System.Today()-10);
        insert shift;
        Volunteer_Hours__c hr6 = new Volunteer_Hours__c(
        	Contact__c=con1.id,
            Volunteer_Job__c = job2.Id,
            Volunteer_Shift__c = shift.Id,
            Start_Date__c = System.Today()-10,
            End_Date__c = System.Today()-10,
            Status__c = 'Confirmed'
        );
        insert hr6;
        
        List<Volunteer_Hours__c> selHrs = [select id,name,
                                           Status__c,
                                           Clock_In_Time__c,
                                           Clock_Out_Time__c,
                                           End_Date__c,
                                           Hours_Worked__c,
                                           System_Note__c from Volunteer_Hours__c];
    }

    @isTest 
    static void testBatch() {

        // Load the batch class and test both constructors
        // Going to force Account here to validate our batch
        VOL_BATCH_DeleteUnusedRecords testBatch = new VOL_BATCH_DeleteUnusedRecords();
        testBatch = new VOL_BATCH_DeleteUnusedRecords('Volunteer_Hours__c');

        system.assertEquals(1, [SELECT count() FROM Volunteer_Hours__c WHERE Status__c = 'Confirmed' and Volunteer_Job__r.Name = 'SUPER GEEK' and Volunteer_Shift__r.Start_Date_Time__c < THIS_WEEK]);
        
        system.assertEquals(6, [SELECT count() FROM Volunteer_Hours__c], 'Should have 6 records prior to run');

        Test.startTest();

        Database.executeBatch(testBatch);

        Test.stopTest();

        system.assertEquals(5, [SELECT count() FROM Volunteer_Hours__c], 'Should have 5 records after batch job is run');
    }

}
