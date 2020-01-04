/**
* @author Mike Simpson
* @date 4th January 2020
* @description Based on repository developed by Ben Edwards (beedwards@deloitte.co.nz) https://github.com/benedwards44/apex-batch-delete
*              Batch class to mass delete all unused records
*              Run:
*              Database.executeBatch(new VOL_BATCH_DeleteUnusedRecords()); 
*
* CHANGE LOG
**/
global class VOL_BATCH_DeleteUnusedRecords implements Database.Batchable<SObject> {

    @InvocableMethod(label='Mass Delete Unused Volunteer Hours' description='Deletes incomplete Super Geek records older than a week')
    global static void CallVOL_BATCH_DeleteUnusedRecords() {
        Database.executeBatch(new VOL_BATCH_DeleteUnusedRecords('Volunteer_Hours__c'));
    }

    // Add objects to this list to chain through objects and clear out all records
    // Ensure to put child objects first, and ones that cause deletes to fail.
    public static final List<String> OBJECT_NAMES = new List<String>{
        'Volunteer_Hours__c'
    };

    // The current object name being run within the batch
    public String currentObjectName;

    // Default Constructor to start on first object in list
    public VOL_BATCH_DeleteUnusedRecords() {
        this.currentObjectName = OBJECT_NAMES[0];
    }

    // Constructor to accept object name to process job for/
    // This is called in the finish method to process the next object
    public VOL_BATCH_DeleteUnusedRecords(String objectName) {
        this.currentObjectName = objectName;
    }

    // Query for all records in the current object
    public Database.QueryLocator start(Database.BatchableContext BC) {
        return Database.getQueryLocator('SELECT Id FROM ' + currentObjectName + ' WHERE Status__c = \'Confirmed\' and Volunteer_Job__r.Name = \'SUPER GEEK\' and Volunteer_Shift__r.Start_Date_Time__c < THIS_WEEK');
    }

    // Delete all records for the given scope
    public void execute(Database.BatchableContext BC, List<SObject> scope) {

        delete scope;
    }

    // Once finished on the current object, determine if there's another object
    // to process, and if so, run the batch again on the next object
    public void finish(Database.BatchableContext BC) {

        // If we have a next object to process
        // Then we run it again!
        if (getNextObject() != null) {

            Database.executeBatch(new VOL_BATCH_DeleteUnusedRecords(getNextObject()));
        }
    }

    // Determine which object to do next
    public String getNextObject() {
        
        // Iterate over the objects in the list
        for (Integer i = 0; i < OBJECT_NAMES.size(); i++) {

            // If this is the current object in the list, get the next
            // item in the list
            if (currentObjectName == OBJECT_NAMES[i]) {

                try {

                    // Return the next object in list
                    return OBJECT_NAMES[i + 1];
                }
                // Will fail silently if object isn't found. Will mean
                // We're at end of list so we can stop
                catch (Exception ex) {}
            }
        }

        return null;
    }
}