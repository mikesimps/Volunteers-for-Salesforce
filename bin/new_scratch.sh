#!/bin/sh

# Create Scratch Org
sfdx force:org:create -s -d 30 -f config/project-scratch-def.json -a v4s

# Push Source
sfdx force:source:push

# Make user a Marketing User
sfdx force:apex:execute -f bin/AssignMarketingUserPermission.apex

# Assign PermissionSet
sfdx force:user:permset:assign -n V4S_Employee_Permissions

# Run Local Tests
sfdx force:apex:test:run -c -y -l RunLocalTests -r human