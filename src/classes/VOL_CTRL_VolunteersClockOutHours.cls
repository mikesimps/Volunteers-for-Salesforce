public class VOL_CTRL_VolunteersClockOutHours {

    ApexPages.StandardSetController setCon;
    public Volunteer_Hours__c hr {get;set;}
    public String cancelLabel {get;set;}

    public VOL_CTRL_VolunteersClockOutHours(ApexPages.StandardSetController controller) {
        setCon = controller;
        cancelLabel = 'Cancel';
    }

    public pageReference clockOut() {

        for ( Volunteer_Hours__c hr : (Volunteer_Hours__c[])setCon.getSelected()) {
            hr.Status__c = 'Completed';
            hr.Clock_Out_Time__c = system.now();
            hr.End_Date__c = system.today();
            hr.Hours_Worked__c = decimal.valueOf(hr.Clock_Out_Time__c.getTime() - hr.Clock_In_Time__c.getTime())/3600000;
            hr.System_Note__c = 'Logged Out By '+ UserInfo.getName() +' using mass Clock Out';
            update hr;
        }
        cancelLabel = 'Done';
        return null;
    }
}