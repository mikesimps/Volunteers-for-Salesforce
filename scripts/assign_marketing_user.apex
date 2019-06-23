//  Set marketing user as true on user record
User u = [SELECT Id, UserPermissionsMarketingUser FROM User WHERE Id = :UserInfo.getUserId()];
u.UserPermissionsMarketingUser = true;
update u;