Id uid = UserInfo.getUserId();
User u = [SELECT Id, UserPermissionsMarketingUser FROM User WHERE Id = :uid];
u.UserPermissionsMarketingUser = true;
update u;