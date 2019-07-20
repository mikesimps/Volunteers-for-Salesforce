# Converting Volunteers-For-Salesforce to SFDX

## What we will focus on

- Example of an approach to convert legacy code to sfdx format
- Highlight several common issues when dealing with scratch orgs
- Additional tips on how to efficiently create missing metadata

## What we will not focus on

- Version control best practices
- Code structure or organization

## Setup

### optional: setup shell aliases (this is for zsh)

These are optional aliases. You can choose not to use them and just run the commands below when needed.

```shell
echo 'alias dxpushr="find .sfdx/orgs -type f -name 'sourcePathInfos.json' -delete; sfdx force:source:push"' >> ~/.zshrc

echo alias 'dxpush="sfdx force:source:push"' >> ~/.zshrc

source ~/.zshrc
```

### optional: install sfdx-collate plugin

In later steps, we will need to easily extract some metadata that is not part of our current repo. There are other ways to get this information, this is just one option.

```shell
sfdx plugins:install sfdx-collate
```

### update cli

```shell
sfdx update
```

### clone source and reate new branch for conversion

```shell
git clone git@github.com:SalesforceFoundation/Volunteers-for-Salesforce.git v4s
cd v4s
# For consistency we will branch from specific commit.
# To do from latest commit just remove the SHA at the end of the command
git checkout -b v4sdx 87ef8f6555a9a7fde29431c3e8fc7e1b4353e1da
```

### Create a new sfdx project to exsisting folder

```shell
sfdx force:project:create -p force-app -n ../v4s
```

### Remove empty directories

```shell
find . -type d -print | xargs rmdir 2>/dev/null
```

### Restore .gitignore to previous value and remove the README

```shell
git checkout HEAD .gitignore; rm README.md
```

### Review existing orgs and then create a new scratch org

```shell
sfdx force:org:list
sfdx force:org:create -d 1 -a v4sfdx -f config/project-scratch-def.json -s
```

### Convert mdapi source to sfdx source format

```shell
sfdx force:mdapi:convert -d force-app -r src > convert.log
```

### Ignore previous src directory

```shell
echo "\n""**src/""" >> .forceignore
```

### Update project-scratch-def.json --> Orgname and edition to Enterprise

```json
{
  "orgName": "V4S",
  "edition": "Enterprise",
  "features": [],
  "settings": {
    "orgPreferenceSettings": {
      "s1DesktopEnabled": true
    }
  }
}
```

### Commit all new files (just for demo purposes, use your own best judgement irl)

```shell
git add force-app .forceignore config/ .prettierignore .prettierrc sfdx-project.json; git commit -m "new dx files"
```

### Add all objects to .forceignore comment out as you push

```shell
ls -d force-app/main/default/* >> .forceignore
```

For this demo we will specifically arrange them like this and replace what we just generated.

```shell
# Metadata with no dependencies
force-app/main/default/labels/
force-app/main/default/staticresources/
force-app/main/default/documents/
force-app/main/default/email/
force-app/main/default/letterhead/

# Metadata for Objects
force-app/main/default/objects/

# Metadata with simple dependencies
**fieldSets/
force-app/main/default/layouts/
force-app/main/default/applications/
force-app/main/default/tabs/

# Metadata with complex dev dependencies
force-app/main/default/pages/
force-app/main/default/classes/
force-app/main/default/triggers/
force-app/main/default/components/
force-app/main/default/workflows/
force-app/main/default/lwc

# Metadata with feature dependency
force-app/main/default/translations/
force-app/main/default/objectTranslations/

# Metadata dependant on almost everything
force-app/main/default/reportTypes/
force-app/main/default/dashboards/
force-app/main/default/reports/

# Metadata for packages
force-app/main/default/featureParameters/
```

## Strategy

To help minimize errors, you will want to start with items that don't have many dependencies objects, labels, documents, etc and slowly add more until all your metadata is included.

Currently there is a bug where changing your .forceignore file is not always detected. Because of this you must be able to delete the sourcePathInfos.json file which will force sfdx to repush all source to the scratch org. An command alias that includes the backup of the file before running a push will accomplish our goal, but on larger code bases it can take much longer to deploy.

```shell
$ cat ~/.zshrc | grep dxpush
alias dxpushr="find .sfdx/orgs -type f -name 'sourcePathInfos.json' -delete; sfdx force:source:push"
alias dxpush="sfdx force:source:push"
```

### Uncomment *Metadata with no dependencies* and dxpush - No Errors

### Uncomment *Metadata for Objects* and dxpush - 2 Errors

NAME|PROBLEM
|---|---
Campaign.Volunteers_Campaign     |Picklist value: Conference in picklist: Type not found
Volunteer_Recurrence_Schedule__c |NewAndEditVRS does not exist or is not a valid override for action Edit.

- Campaign record type is missing [StandardValueSet](https://developer.salesforce.com/docs/atlas.en-us.api_meta.meta/api_meta/standardvalueset_names.htm) for CampaignType
- The 2nd error is related to missing VF page which we will solve by including additional source

Pull metadata using sfdx collate and sfdx source:retreive

```shell
sfdx collate:fetch:packagexml --apiversion 46.0 -q StandardValueSet > package.xml
```

Remove the standard value sets you don't need from package.xml (all but CampaignType) and retrieve the source

```shell
sfdx force:source:retrieve -x package.xml
```

The error message clearly states that the picklist value "Conference" is not found. Upon inspection, we find that the StandardValueSet we just pulled does not have it either. We will need to add it to CampaignType.standardValueSet-meta.xml along with other missing items. After another push, we are only left with the 2nd error and can move forward to enabling more metadata.

```xml
    <standardValue>
        <fullName>Conference</fullName>
        <default>false</default>
        <label>Conference</label>
    </standardValue>
    <standardValue>
        <fullName>Direct Mail</fullName>
        <default>false</default>
        <label>Direct Mail</label>
    </standardValue>
    <standardValue>
        <fullName>Trade Show</fullName>
        <default>false</default>
        <label>Trade Show</label>
    </standardValue>
    <standardValue>
        <fullName>Webinar</fullName>
        <default>false</default>
        <label>Webinar</label>
    </standardValue>
```

### Uncomment Metadata with simple dependencies and dxpush - 3 Key Errors

NAME|PROBLEM
|---|---
About_Volunteers|Property 'mobileReady' not valid in version 46.0
Campaign.VolunteersWizardFS|availableFields in FieldSet is not editable for your organization.
Groundwire_Volunteers|Property 'tab' not valid in version 46.0

- 1st error requires removal of the \<mobileReady> tags
  - Find and replace the below string with nothing [regex on] - 16 items

```text
    <mobileReady>(.|\n)*?</mobileReady>\n
```

- 2nd error requires removal of \<availableFields> from all FieldSets
  - Find and replace the below string with nothing [regex on] - 814 items

```text
<availableFields>(.|\n)*?</availableFields>\n
```

- 3rd error requires changing of "tab" to "tabs" in Groundwire_Volunteers.app-meta.xml
  - Find 'tab>' and replace with 'tabs>' [case sensitive on]

Other errors are directly related to missing dependencies.

- About_Volunteers no ApexPage named VolunteersAbout found error is because we have not pushed visualforce pages yet
- defaultLandingTab - no CustomTab named About_Volunteers is because the About_Volunteers tab failed to be pushed (per above)
- NewAndEditVRS continues to require Apex classes to be included

:bangbang:**LESSON: keep an eye out for dependency keywords like "cannot find", "does not exist", etc. It may indicate you need to continue to add metadata to resolve the issue.**

### Uncomment *Metadata with complex dev dependencies* and dxpush - No errors

### Uncomment *Metadata with feature dependency* and dxpushr - 2 Key Errors

NAME|PROBLEM
|---|---
Campaign-de|EntityObject can not be initialized with null EntityInfo
de|Not available for deploy for this organization

The first error is not very helpful, but the second makes it a bit more clear. The problem here is that [Translation Workbench](https://help.salesforce.com/articleView?id=customize_wbench.htm&type=5) is not enabled for this org.

To avoid having to re-create a scratch org, you can just manually enable the feature in the org, but make sure you add "Translations" to project-scratch-def.json features so you don't have to do it every time you spin up an org.

```json
{
  "orgName": "V4S",
  "edition": "Enterprise",
  "features": [],
  "settings": {
    "orgPreferenceSettings": {
      "s1DesktopEnabled": true,
      "translation": true
    }
  }
}
```

After enabling Translation Workbench, we still get an error when we push. This is because we have not pushed reportType metadata yet. We can ignore this error for now and move to the next step.

NAME|PROBLEM
|---|---
de|In field: name - no ReportType named Accounts found

### Uncomment *Metadata dependant on almost everything* and dxpush - 1 Error

NAME|PROBLEM
|---|---
Volunteer_Reports/New_Sign_Ups_Leads |filters-criteriaItems-Value: Picklist value does not exist

When we inspect the New_Sign_Ups_Leads report, we see two fields with filter criteria. One is a custom field and one is a standard field. We will need to add the **LeadStatus** StandardValueSet similar to how we added **CampaignType**.

```html
    <filter>
        <criteriaItems>
            <column>Lead.Volunteer_Status__c</column>
            <isUnlocked>false</isUnlocked>
            <operator>equals</operator>
            <value>New Sign Up</value>
        </criteriaItems>
        <criteriaItems>
            <column>STATUS</column>
            <isUnlocked>false</isUnlocked>
            <operator>equals</operator>
            <value>Open - Not Contacted,Working - Contacted</value>
        </criteriaItems>
        <language>en_US</language>
    </filter>
```

For this we can leverage the package.xml that we did not delete and just update CampaignType to LeadStatus and run the retreive command again:

```shell
sfdx force:source:retrieve -x package.xml
```

Add these items to LeadStatus.standardValueSet-meta.xml and push

```xml
    <standardValue>
        <fullName>Open - Not Contacted</fullName>
        <default>false</default>
        <label>Open - Not Contacted</label>
        <converted>false</converted>
    </standardValue>
    <standardValue>
        <fullName>Working - Contacted</fullName>
        <default>false</default>
        <label>Working - Contacted</label>
        <converted>false</converted>
    </standardValue>
```

:bangbang:**LESSON: go through your code first thing and generate/set all your StandardValueSets before starting**

### Uncomment *Metadata for packages* and dxpushr - No Errors

### Run tests to make sure you got everything

``` shell
sfdx force:apex:test:run -c -r human -l RunLocalTests -w 10 --verbose
```

There are a lot of failures test failures here, but they can be attributed to 3 things:

- Missing Permissions 
  - create a permissionset to cover the permissions needed
  - create anonymous apex script to set user as a [Marketing User](https://help.salesforce.com/articleView?id=faq_campaigns_who_has_access.htm&type=5)
- Missing Feature - V4S relies on Salesforce Sites, add that to the project-scratch-def.json
- Tests executing in the wrong order - need to disable parallel test execution in project-scratch-def.json

TEST|MISSING FEATURE|[FEATURE TO ENABLE](https://developer.salesforce.com/docs/atlas.en-us.sfdx_dev.meta/sfdx_dev/sfdx_dev_scratch_orgs_def_file_config_values.htm)
|---|---|---
VOL_CTRL_VolunteersSignupFS_TEST|[Salesforce Sites](https://developer.salesforce.com/docs/atlas.en-us.salesforce_platform_portal_implementation_guide.meta/salesforce_platform_portal_implementation_guide/sites_setup_overview.htm)|Sites

### Update Settings and Features

You must [manually disable parallel testing](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_testing_best_practices.htm) and [enable sites](https://help.salesforce.com/articleView?id=sites_setup_overview.htm&type=5). At this point you may be better off just modifying your project-scratch-def.json to match below, create a new scratch org, and push the modified code.

```json
{
  "orgName": "V4S",
  "edition": "Enterprise",
  "features": ["Sites"],
  "settings": {
    "orgPreferenceSettings": {
      "s1DesktopEnabled": true,
      "translation": true,
      "disableParallelApexTesting": true
    }
  }
}
```

### Push correct permissions before running tests

The V4S package, like some legacy code bases, assume that you have a sandbox and a profile with all the permissions you need. With SFDX we can make that more dynamic, but it does take a bit more effort. The V4S_Employee_Permissions and assign_marketing_user.apex was created for this demo. You can find them both in [this gist](https://gist.github.com/mikesimps/04cef5c575554772513e6429d52ceaee) or in this current branch (tosfdx). Create the permission set and anon apex files in the location respectively:

```text
force-app/main/default/permissionsets/V4S_Employee_Permissions.permissionset-meta.xml
scripts/assign_marketing_user.apex
```

Run these commands:

```shell
# Set permission set to admin user
sfdx force:user:permset:assign -n V4S_Employee_Permissions

# Small anon apex to make the user a marketing user
sfdx force:apex:execute -f scripts/assign_marketing_user.apex
```

In addition to making sure we have the proper permission setup, there is also a requirement to slightly modify the code to assign these permissionsets when executing on a user created in the test context. Adding this code to the two test methods below ensures that the test users have the permissions they need to execute.

- force-app/main/default/classes/VOL_CTRL_PersonalSiteContactInfo_TEST.cls
- force-app/main/default/classes/VOL_CTRL_JobCalendar_TEST.cls

```java
        insert u;

        PermissionSet v4sPS = [SELECT Id FROM PermissionSet WHERE Name = 'V4S_Employee_Permissions' LIMIT 1];
        if (v4sPS != null) {
          insert new PermissionSetAssignment (AssigneeId = u.Id, PermissionSetId = v4sPS.Id);
        }
```
