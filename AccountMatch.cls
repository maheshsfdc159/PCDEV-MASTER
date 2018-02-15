public class AccountMatch{
    public Account getAccount(OneKeyProfileService.AccDetails acc){
		system.debug('hi');
        List<Account> a = new List<Account>();
        if(acc.cip!=null && acc.cip!=''){
        
            a = [select Id,Name, PG_PharmacyRegistrationNumber__c,VAT_Number__c, billingStreet, billingCity, billingCountry, billingPostalcode,PG_JnJCustomerCode__c from Account where PG_PharmacyRegistrationNumber__c =: acc.CIP]; 
         }
        if(a.size()>0 ){
            return a[0];
        }else{
            return insertAccount(acc);
        }
        
    }
    public Account insertAccount(OneKeyProfileService.AccDetails acc){
    
        Account a = new Account();
        a.Name = acc.Name;
        a.PG_JnJCustomerCode__c = acc.CIP;
        a.PG_LearningMethod__c = 'PHB';
        a.PG_PharmacyRegistrationNumber__c = acc.CIP;
        //a.PG_AccountType__c = 
        //a.PG_ShipTo__c
        //a.PG_SoldTo__c
        a.PG_Account__c = false;
        a.PG_AccountGuid__c = acc.CIP; 
        a.OwnerId = Onekeyconfig__c.getvalues('AccountOwnerID').value__C;
        a.billingStreet = acc.Street;
        a.billingCity = acc.City;
        a.billingCountry = acc.Country;
        a.billingPostalcode = acc.Postal;
        a.VAT_Number__c = acc.CIP;
        insert a;
        return a;
    }
}