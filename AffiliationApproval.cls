global class AffiliationApproval{
    
    public static void createApproval(List<Account_Affiliation__c> aff){
        System.debug('List of affiliation:'+aff);
        Set<ID> ConID = new Set<ID>();
        Set<ID> AccID = new Set<ID>();
        map<string,boolean>delowner=new map<string,boolean>();
        String cname;
        string logrole='';
        List<Account_Affiliation__c> updateAffList = new List<Account_Affiliation__c>();
        Map<String,Account_Affiliation__c> mapAffiliation = new Map<String,Account_Affiliation__c>();
        List<PG_ContactApprovalStatus__c> lap = new List<PG_ContactApprovalStatus__c>();
        User u = [Select id, contactid,PG_Country_Id__c,PG_UserType__c,LanguageLocalekey,Localesidkey,contact.salutation from User where Id=:UserInfo.getUserId()];
        Map<String, Customer_Service_Settings__c> css = Customer_Service_Settings__c.getall();
        Customer_Service_Settings__c concs = css.get(u.LocaleSidKey);    
       
        for(Account_Affiliation__c affiliation : aff){
            ConID.add(affiliation.Contact_ID__c);
            AccID.add(affiliation.Account_ID__c);
            String conacc = String.valueof(affiliation.Account_ID__c)+String.valueof(affiliation.Contact_ID__c);
            System.debug('KeyAcc&Con>>>>'+conacc);
            mapAffiliation.put(conacc,affiliation);
        }
        Map<ID,Account> mpAccount = New Map<ID,Account>([Select Id,OwnerId, Name, PG_JnJCustomerCode__c,Condition_Group3__c,Pg_Account__c from Account where ID IN:AccID]);
        Map<ID,Contact> mpContact = New Map<ID,Contact>([Select ID, Email, AccountID, Name,(Select Contact__c, PG_SubRole__r.role__c,PG_SubRole__r.Approval_CustomerService__c, PG_SubRole__r.ApprovalSalesRep__c,PG_SubRole__r.Visited_Pharmacies__c,PG_SubRole__r.Non_Visited_Pharmacies__c From Users__r) from Contact where Id =:ConID]); 
        list<Affiliation_Function__c>afffunc = [Select id,Account_Affiliation__c,Account_Affiliation__r.Contact_ID__c,Account_Affiliation__r.Account_ID__c,PG_FunctionalityAccessPerSubRole__r.name from Affiliation_Function__c where Account_Affiliation__r.Account_ID__c=: AccID and PG_FunctionalityAccessPerSubRole__r.PG_Functionality__r.name='Delegation'];
        for(Affiliation_Function__c fc:afffunc)
        {
            delowner.put(String.valueof(fc.Account_Affiliation__r.Contact_ID__c)+String.valueof(fc.Account_Affiliation__r.Account_ID__c),true); /*Added this for delegation owner functionality*/
        }
        System.debug('Delegation Owner>>>>'+delowner);
        if(u.PG_UserType__c != 'Internal'){
            System.debug('External#####');
            Contact loggeduser = [Select ID, Email, AccountID, (Select Contact__c, PG_SubRole__r.role__c, PG_SubRole__r.Approval_CustomerService__c, PG_SubRole__r.ApprovalSalesRep__c,PG_SubRole__r.Visited_Pharmacies__c,PG_SubRole__r.Non_Visited_Pharmacies__c  From Users__r) from Contact where Id =: u.contactid];
            System.debug('External#####'+loggeduser.Users__r);
            logrole = loggeduser.Users__r[0].PG_SubRole__r.role__c;
            if(loggeduser!=null){
                System.debug('External#####'+loggeduser.Users__r[0].PG_SubRole__r.role__c);
                if(loggeduser.Users__r[0].PG_SubRole__r.role__c == 'Manager' || loggeduser.Users__r[0].PG_SubRole__r.role__c == 'Owner' || loggeduser.Users__r[0].PG_SubRole__r.role__c == 'Buyer'){
                    System.debug('External#####'+loggeduser.Users__r[0].PG_SubRole__r.role__c);
                    for(Account_Affiliation__c c : aff){
                        PG_ContactApprovalStatus__c cap = new PG_ContactApprovalStatus__c();
                        cap.Account_ID__c = c.Account_ID__c;
                        cap.Contact_ID__c = c.Contact_ID__c;
                        cap.PG_LearningMethod__c = 'PHB';
                        cap.PG_SupportedCountry__c = u.PG_Country_Id__c;
                        Contact con = mpContact.get(c.Contact_ID__c);
                        Account cgroup = mpAccount.get(c.Account_ID__c);
                        if(con.Users__r[0].PG_SubRole__r.role__c == 'Manager' || con.Users__r[0].PG_SubRole__r.role__c == 'Owner' ||  con.Users__r[0].PG_SubRole__r.role__c == 'Buyer'){
                            System.debug('External#####'+con.Users__r[0].PG_SubRole__r.role__c );
                            //Approval flow depends upon Subroles
                            if(con.Users__r[0].PG_SubRole__r.Approval_CustomerService__c == true || con.Users__r[0].PG_SubRole__r.ApprovalSalesRep__c == true){
                                if(con.Users__r[0].PG_SubRole__r.Approval_CustomerService__c == true)
                                    cap.PG_ApprovalStatus__c = 'AwaitingCSApproval';
                                else if(con.Users__r[0].PG_SubRole__r.ApprovalSalesRep__c == true)
                                    {
                                     	cap.PG_ApprovalStatus__c = 'AwaitingSalesRepApproval';
                                    } 
                            }
                            else if(cgroup.Condition_Group3__c!=null){
                                if(con.Users__r[0].PG_SubRole__r.Visited_Pharmacies__c.contains(cgroup.Condition_Group3__c))
                                {
                                    
                                    cap.PG_ApprovalStatus__c = PG_Enums.APPROVAL_STATUS_TYPE.AwaitingSalesRepApproval.Name();
                                     System.debug('External#####'+cap.PG_ApprovalStatus__c);
                                }
                                else if(con.Users__r[0].PG_SubRole__r.Non_Visited_Pharmacies__c.contains(cgroup.Condition_Group3__c))
                                {
                                    cap.PG_ApprovalStatus__c = PG_Enums.APPROVAL_STATUS_TYPE.AwaitingCSApproval.Name();
                                }
                            }else{
                                cap.PG_ApprovalStatus__c = 'AwaitingCSApproval';
                            }
                            
                        }else{
                            /*Updated the aaproval state to accepted.By default if manager adds affilitation to staff approval state will be accepted only .07-03-2017*/
                            cap.PG_ApprovalStatus__c = 'Accepted';
                        }
                        lap.add(cap);
                        System.debug('External#####'+lap);
                    }
                    
                }else if(loggeduser.Users__r[0].PG_SubRole__r.role__c == 'User'){
                    
                    for(Account_Affiliation__c c : aff)
                    {    
                        PG_ContactApprovalStatus__c cap = new PG_ContactApprovalStatus__c();
                        cap.Account_ID__c = c.Account_ID__c;
                        cap.Contact_ID__c = c.Contact_ID__c;
                        cap.PG_LearningMethod__c = 'PHB';
                        cap.PG_SupportedCountry__c = u.PG_Country_Id__c;
                        
                        if(u.Localesidkey!='de_DE')  
                            cap.PG_ApprovalStatus__c = 'AwaitingPharmacyApproval';
                        else
                           { 
	                            if(delowner.size()>0)
	                            {
		                            if(delowner.containsKey(string.valueof(u.contactid)+string.valueof(c.Account_ID__c))) /*Added this for delegation owner functionality*/
		                            { 
		                              System.debug('Delegation Owner>>>>'+delowner);
		                              cap.PG_ApprovalStatus__c = 'Accepted';
		                              if(loggeduser.id==c.Contact_ID__r.id)logrole='De Manager';
		                              else logrole='Manager';
		                            }   
		                            else
		                            {    
		                            	if(mpContact.get(c.Contact_ID__c).Users__r[0].PG_SubRole__r.ApprovalSalesRep__c)   
		                                	cap.PG_ApprovalStatus__c = 'AwaitingSalesRepApproval';
		                                else
		                                {
		                                	if(mpContact.get(c.Contact_ID__c).Users__r[0].PG_SubRole__r.ApprovalPharmacist__c)
		                                		cap.PG_ApprovalStatus__c = 'AwaitingPharmacyApproval';
		                                	else
		                                		cap.PG_ApprovalStatus__c = 'Accepted';
		                                }
		                            }
	                           }
	                           else{        
	                                  if(mpContact.get(c.Contact_ID__c).Users__r[0].PG_SubRole__r.ApprovalSalesRep__c)   
		                                	cap.PG_ApprovalStatus__c = 'AwaitingSalesRepApproval';
		                                else
		                                {
		                                	if(mpContact.get(c.Contact_ID__c).Users__r[0].PG_SubRole__r.ApprovalPharmacist__c)
		                                		cap.PG_ApprovalStatus__c = 'AwaitingPharmacyApproval';
		                                	else
		                                		cap.PG_ApprovalStatus__c = 'Accepted';
		                                }

	                              }     
                         }      
                         lap.add(cap);
                    }
                }
            }
        }else{
            for(Account_Affiliation__c c : aff){    
                PG_ContactApprovalStatus__c cap = new PG_ContactApprovalStatus__c();
                cap.Account_ID__c = c.Account_ID__c;
                cap.Contact_ID__c = c.Contact_ID__c;
                cap.PG_LearningMethod__c = 'PHB';
                cap.PG_SupportedCountry__c = u.PG_Country_Id__c;
                cap.PG_ApprovalStatus__c = 'Accepted';
                lap.add(cap);
            }
        }
        
        if(lap.size()>0) insert lap;
        for(PG_ContactApprovalStatus__c app :lap){
            System.debug('mapAffiliation:'+mapAffiliation);
            System.debug('AppAccount:'+app.Account_ID__c);
            System.debug('AppContact:'+app.Contact_ID__c);
            System.debug('af::::'+mapAffiliation.get(String.valueof(app.Account_ID__c)+String.valueof(app.Contact_ID__c)));
            Account_Affiliation__c af = mapAffiliation.get(String.valueof(app.Account_ID__c)+String.valueof(app.Contact_ID__c));
            af.Affiliation_ApprovalState__c = app.Id;
            Account a = mpAccount.get(app.Account_ID__c);
            Contact cons = mpContact.get(app.Contact_ID__c);
            updateAffList.add(af);
            if(app.PG_ApprovalStatus__c == 'AwaitingSalesRepApproval' || app.PG_ApprovalStatus__c == 'AwaitingCSApproval'){
                setprocessInstance(a.OwnerId,app.Id);
            }else if(app.PG_ApprovalStatus__c == 'AwaitingPharmacyApproval'){
                //Send email notificaion to PH.Manager
                Set<ID> ConIDS = new Set<ID>();
                set<ID>DelId= new set<ID>();
                Contact Manager = null;
                Contact Owner = null;
                list<Account_Affiliation__c>deaff = [select contact_id__c from Account_Affiliation__c where Account_id__c=:app.Account_ID__c and Affiliation_ApprovalState__r.PG_ApprovalStatus__c='Accepted'and id in (select Account_Affiliation__c from Affiliation_Function__c where PG_FunctionalityAccessPerSubRole__r.PG_Functionality__r.name='Delegation')];
                for(Account_Affiliation__c afc:deaff)
                {
                    DelId.add(afc.contact_id__C);
                }
                List<Contact> lstContact = [SELECT ID, AccountID, Email,Name, (Select Contact__c, PG_SubRole__r.role__c From Users__r) from Contact where AccountID = :app.Account_ID__c];
                List<Account_Affiliation__c> lstAccountAff = [Select ID, Account_ID__c, Contact_ID__c from Account_Affiliation__c where Account_ID__c =:app.Account_ID__c];
                System.debug('lstContact:'+lstContact);
                System.debug('lstAccountAff:'+lstAccountAff);
                for(Contact c: lstContact){
                    for(PG_ContactUser__c cu :c.Users__r){
                        System.debug('cu:'+cu);
                        if(cu.PG_SubRole__r.role__c == 'Manager'){ 
                            Manager = c;
                        }
                        if(cu.PG_SubRole__r.role__c == 'Owner'){
                            Owner = c;
                        }
                    }
                }
                if(Manager == null || Owner==null){
                    for(Account_Affiliation__c caff : lstAccountAff){
                        ConIDS.add(caff.Contact_ID__c);
                    }
                }               
                System.debug('ConIDS:'+ConIDS);
                System.debug('Manager:'+Manager);
                if(Manager == null || Owner==null){
                    List<Contact> lstContacts = [SELECT ID, AccountID, Email, (Select Contact__c, PG_SubRole__r.role__c From Users__r) from Contact where ID IN: ConIDS];
                    for(Contact c: lstContacts){
                        for(PG_ContactUser__c cu :c.Users__r){
                            if(cu.PG_SubRole__r.role__c == 'Manager') Manager = c;
                            if(cu.PG_SubRole__r.role__c == 'Owner') Owner = c;
                        }
                    }
                }
                if(u.localesidkey=='en_GB')
                {
                    if(Manager!=null)Owner=null;
                }
                //Send email to manager of the pharmacy
                if (Manager != null) {
                    map<string,string>genmap = new map<string,string>{'Mr.'=>'Attribute1__c','Ms.'=>'Attribute2__c','Mrs.'=>'Attribute2__c','Mr'=>'Attribute3__c','Ms'=>'Attribute4__c','Mrs'=>'Attribute4__c'};
                    User us = [select id, Contact.FirstName, Contact.LastName, Contact.Salutation, PG_LearningMethod__c,Country,Email,LocaleSidKey,Contact.Account.PG_Account__c,Contact.Account.PG_JnJCustomerCode__c,Contact.Account.Name from User where Contactid = :Manager.Id];
                    Map<String, Country_Code_settings__c> mcs = Country_Code_settings__c.getall();
                    Country_Code_settings__c ccs = mcs.get(us.LocaleSidKey);
                    Attributes__c title = Attributes__c.getValues(us.LocaleSidKey);
                    String strTitle = '';
                    System.debug('Saluation####'+us.Contact.Salutation);
                    if(title != null && us.Contact.Salutation!=null){ strTitle = String.valueof(title.get(us.Contact.Salutation.remove('.')+'__c')); } 
                    System.debug('Title###'+strTitle);
                    if(us.Contact.Account.PG_Account__c == true){
                        ET_EmailAdministration.SendEmail(us.Email, ccs.PG_Affiliation_Manager_Approval__c, '',strTitle , us.Contact.LastName, '',us.Contact.firstname, a.Name,a.PG_JnJCustomerCode__c,cons.name,'','',''); // manager email
                        
                    }else{
                        ET_EmailAdministration.SendEmail(us.Email, ccs.PGA_Affiliation_Manager_Approval__c, '', strTitle, us.Contact.LastName, '', us.Contact.firstname, a.Name,a.PG_JnJCustomerCode__c,cons.Name,'','',''); // manager email
                    }
                }
                // Send email to owner of the phamacy 
                if (Owner != null) {
                    User us = [select id, Contact.LastName, Contact.Salutation, PG_LearningMethod__c,Country,Email,LocaleSidKey,Contact.Account.PG_Account__c,Contact.Account.PG_JnJCustomerCode__c,Contact.Account.Name from User where Contactid = :Owner.Id];
                    Map<String, Country_Code_settings__c> mcs = Country_Code_settings__c.getall();
                    Country_Code_settings__c ccs = mcs.get(us.LocaleSidKey);
                    Attributes__c title = Attributes__c.getValues(us.LocaleSidKey);
                    String strTitle = '';
                    System.debug('Saluation####'+us.Contact.Salutation);
                    if(title != null && us.Contact.Salutation!=null){ strTitle = String.valueof(title.get(us.Contact.Salutation.remove('.')+'__c')); } 
                    System.debug('Title###'+strTitle);
                    if(us.Contact.Account.PG_Account__c == true){
                        ET_EmailAdministration.SendEmail(us.Email, ccs.PG_Affiliation_Manager_Approval__c, '',strTitle , us.Contact.LastName, '', '', a.Name,a.PG_JnJCustomerCode__c,cons.name,'','','');
                        
                    }else{
                        ET_EmailAdministration.SendEmail(us.Email, ccs.PGA_Affiliation_Manager_Approval__c, '', strTitle, us.Contact.LastName, '', '', a.Name,a.PG_JnJCustomerCode__c,cons.Name,'','',''); 
                    }
                }
                if(delid.size()>0)
                {
                    list<User>delown=[select id, Contact.LastName, Contact.Salutation, PG_LearningMethod__c,Country,Email,LocaleSidKey,Contact.Account.PG_Account__c,Contact.Account.PG_JnJCustomerCode__c,Contact.Account.Name from User where Contactid = :Delid];
                    for(User delu:delown)
                    {
                        Map<String, Country_Code_settings__c> mcs = Country_Code_settings__c.getall();
                        Country_Code_settings__c ccs = mcs.get(delu.LocaleSidKey);
                        Attributes__c title = Attributes__c.getValues(delu.LocaleSidKey);
                        String strTitle = '';
                        System.debug('Saluation####'+delu.Contact.Salutation);
                        if(title != null && delu.Contact.Salutation!=null){ strTitle = String.valueof(title.get(delu.Contact.Salutation.remove('.')+'__c')); } 
                        System.debug('Title###'+strTitle);
                        
                        if(delu.Contact.Account.PG_Account__c == true)
                        ET_EmailAdministration.SendEmail(delu.Email, ccs.PG_Affiliation_Manager_Approval__c, '',strTitle , delu.Contact.LastName, '', '', a.Name,a.PG_JnJCustomerCode__c,cons.name,'','','');
                        else
                        ET_EmailAdministration.SendEmail(delu.Email, ccs.PGA_Affiliation_Manager_Approval__c, '', strTitle, delu.Contact.LastName, '', '', a.Name,a.PG_JnJCustomerCode__c,cons.Name,'','',''); 
                        
                    }
                }                
            }else if(app.PG_ApprovalStatus__c == 'Accepted'){
                List<User> uu = [Select Id, Email, Localesidkey, Contact.Salutation, Contact.LastName,Contact.firstname, Contact.Account.PG_JnJCustomerCode__c,Contact.Account.Name,Contact.Account.PG_Account__c from User where ContactId=:app.Contact_ID__c];
                Map<String, Country_Code_settings__c> mcs = Country_Code_settings__c.getall();
                Country_Code_settings__c ccs = mcs.get(uu[0].LocaleSidKey);
                
                if(u.pg_Usertype__c!='Internal')
                {
                    if(logrole=='Owner' || logrole=='Manager')
                    {
                        for(User us:uu)
                        {
                            Attributes__c title = Attributes__c.getValues(us.LocaleSidKey);
                            String strTitle = '';
                            if(title != null && us.Contact.Salutation!=null){ strTitle = String.valueof(title.get(us.Contact.Salutation.remove('.')+'__c')); }                      
                            if(us.Contact.Account.PG_Account__c == true){
                                  ET_EmailAdministration.SendEmail(us.Email, ccs.PG_Sec_Pharm_by_Manager__c, '', strTitle, us.Contact.LastName, '', us.Contact.firstname, a.Name,a.PG_JnJCustomerCode__c,'','','',''); 
                            }else{
                                  ET_EmailAdministration.SendEmail(us.Email, ccs.PGA_Sec_Pharm_by_Manager__c, '', strTitle, us.Contact.LastName, '', us.Contact.firstname, a.Name,a.PG_JnJCustomerCode__c,'','','','');
                            }
                        }
                    }
                    else
                    {
                        for(User us:uu)
                        {
                            Attributes__c title = Attributes__c.getValues(us.LocaleSidKey);
                            String strTitle = '';
                            if(title != null && us.Contact.Salutation!=null){ strTitle = String.valueof(title.get(us.Contact.Salutation.remove('.')+'__c')); }                      
                            if(logrole=='User'){
                                  ET_EmailAdministration.SendEmail(us.Email, ccs.PGA_Welcome_Sec_NonManager__c, '', strTitle, us.Contact.LastName, '', us.Contact.firstname, a.Name,a.PG_JnJCustomerCode__c,'','','',''); 
                            }else{
                                  ET_EmailAdministration.SendEmail(us.Email, ccs.PGA_Welcome_Sec_Manager__c, '', strTitle, us.Contact.LastName, '', us.Contact.firstname, a.Name,a.PG_JnJCustomerCode__c,'','','','');
                            }
                        }
                    }   
                }
                else
                {
                    for(User us:uu)
                        {
                            Attributes__c title = Attributes__c.getValues(us.LocaleSidKey);
                            String strTitle = '';
                            if(title != null && us.Contact.Salutation!=null){ strTitle = String.valueof(title.get(us.Contact.Salutation.remove('.')+'__c')); }                      
                            if(us.Contact.Account.PG_Account__c == true){
                                  ET_EmailAdministration.SendEmail(us.Email, ccs.PG_Sec_Pharm_by_Manager__c, '', strTitle, us.Contact.LastName, '', us.Contact.firstname, a.Name,a.PG_JnJCustomerCode__c,'','','',''); 
                            }else{
                                  ET_EmailAdministration.SendEmail(us.Email, ccs.PGA_Sec_Pharm_by_Manager__c, '', strTitle, us.Contact.LastName, '', us.Contact.firstname, a.Name,a.PG_JnJCustomerCode__c,'','','','');
                            }
                        }
                }
                /*for(User us:uu){
                    Attributes__c title = Attributes__c.getValues(us.LocaleSidKey);
                    String strTitle = '';
                    if(title != null && us.Contact.Salutation!=null){ strTitle = String.valueof(title.get(us.Contact.Salutation.remove('.')+'__c')); }                      
                    if(us.Contact.Account.PG_Account__c == true){
                          ET_EmailAdministration.SendEmail(us.Email, ccs.PG_Sec_Pharm_by_Manager__c, '', strTitle, us.Contact.LastName, '', us.Contact.firstname, a.Name,a.PG_JnJCustomerCode__c,'','','',''); 
                    }else{
                          ET_EmailAdministration.SendEmail(us.Email, ccs.PGA_Sec_Pharm_by_Manager__c, '', strTitle, us.Contact.LastName, '', us.Contact.firstname, a.Name,a.PG_JnJCustomerCode__c,'','','','');
                    }
                }*/
            }
        }
        String Affilition = json.serialize(updateAffList);
        updateAffiliation(Affilition);
    }
    
    public static void setprocessInstance(ID OwnerID, ID ApprovalD){
        System.debug('OwnerID :'+OwnerID);
        List<PG_ApprovalUser__c> approvalUser = new List<PG_ApprovalUser__c>();
        List<Contact> lfcon = new List<Contact>();
        Set<ID> ConIDs = new Set<ID>();
        Set<ID> CfIDs = new Set<ID>();
        Id cfid;
        Map<Id,Contact> mps = new Map<Id,Contact>();
        String Mname;
        String cname;
        PG_ContactApprovalStatus__c psc  = [Select Id,Contact_ID__c, Account_ID__c, PG_ApprovalStatus__c from PG_ContactApprovalStatus__c where Id=:ApprovalD];
        //If Pharmacy have a Contact Manager        
        List<Contact> lstContacts = [Select Id, Name, AccountId, (Select Contact__c, PG_SubRole__r.role__c From Users__r) from Contact where AccountID =: psc.Account_ID__c];
        for(Contact cc:lstContacts){
            if(cc.Users__r[0].PG_SubRole__r.role__c == 'Manager'){
                Mname = cc.Name;
                System.debug('ManagerName####'+Mname);
            }
        }
        //////////
        //If Pharmacy have an Affiliation Manager
        List<Account_Affiliation__c> mgrAffi = [Select Id, Account_ID__c, Contact_ID__c from Account_Affiliation__c where Account_ID__c =:psc.Account_ID__c];
        if(mgrAffi.size()>0){
            for(Account_Affiliation__c a :mgrAffi){
                    ConIDs.add(a.Contact_ID__c);
                }
        }
        
        List<Contact> AffContacts = [Select ID, Email, AccountID,Name, (Select Contact__c, PG_SubRole__r.role__c From Users__r where PG_SubRole__r.role__c='Manager') from Contact where ID IN: ConIDs];
        if(AffContacts.size()>0){
           for(Contact cf:AffContacts){
                for(PG_ContactUser__c pg:cf.Users__r){
                    if(pg.PG_SubRole__r.role__c == 'Manager'){
                        Mname = cf.Name;
                        cfid = cf.Id;
                        System.debug('ManagerName####'+Mname);
                    }
                }
            }
        }
        
        /*if(cfid!=null){
            lfcon = [Select Id,Name from Contact where Id=:cfid];
        }
        List<Contact> AffContactsuser = [Select ID, Email, AccountID, (Select Contact__c, PG_SubRole__r.role__c From Users__r) from Contact where ID IN: ConIDs];
        if(AffContacts.size()>0){
           for(Contact cf:AffContactsuser){
                for(PG_ContactUser__c pg:cf.Users__r){
                    if(pg.PG_SubRole__r.role__c == 'User'){
                        Mname = lfcon[0].Name;
                        System.debug('ManagerName####'+Mname);
                    }
                }
            }
        }*/  
            
        User uu = [select id, Name, Username, Email, LanguageLocalekey, Localesidkey, Accountid, Manager.Name, Contact.Account.PG_Account__c,PG_Subrole__c from user where contactid = :psc.Contact_ID__c limit 1];
        //PG_SubRole__c sapp = [select PG_SupportedCountry__c,Role__c,ApprovalSalesRep__c,Approval_CustomerService__c from PG_Subrole__c where id = :uu.PG_Subrole__c];
        Account acc = [Select Id, PG_PharmacyRegistrationNumber__c, Name,Condition_Group3__c, VAT_Number__c, Billingstreet, Billingcity, BillingPostalcode from Account where Id=:psc.Account_ID__c];
        //ID csgid = Default_JnJ_ID__c.getValues('CSG_Id').Value__c;
        Map<String, Customer_Service_Settings__c> css = Customer_Service_Settings__c.getall();
        Customer_Service_Settings__c concs = css.get(uu.LocaleSidKey);
        
        if(concs.value__c != '' && concs.value__c != null){
            ID csgid = concs.Value__c;
            System.debug('Belgium Users###');
            
                if(psc.PG_ApprovalStatus__c == PG_Enums.APPROVAL_STATUS_TYPE.AwaitingSalesRepApproval.Name()){
                    approvalUser = [select Id, Name, user__c, delegate__c,date_to__c,date_from__c from PG_ApprovalUser__c where PG_ProcessType__c in (select ID from PG_ProcessType__c where name = :PG_Enums.PROCESS_TYPE.REGISTER.name()) and user__c = :OwnerID];
                }else{
                    approvalUser = [select Id, Name, user__c, delegate__c,date_to__c,date_from__c from PG_ApprovalUser__c where PG_ProcessType__c in (select ID from PG_ProcessType__c where name = :PG_Enums.PROCESS_TYPE.REGISTER.name()) and user__c = :csgid ];
                }
        }else{
            
             approvalUser = [select Id, Name, user__c, delegate__c,date_to__c,date_from__c from PG_ApprovalUser__c where PG_ProcessType__c in (select ID from PG_ProcessType__c where name = :PG_Enums.PROCESS_TYPE.REGISTER.name()) and user__c = :OwnerID];
            
        }   
        
        if (!approvalUser.isEmpty()) {
            Approval.ProcessSubmitRequest req1 = new Approval.ProcessSubmitRequest();
            req1.setComments('Submit Affiliation Request');
            if (approvalUser[0].date_from__c <= System.today() && approvalUser[0].date_to__c > System.today()){
                req1.setNextApproverIds(new Id[] {approvalUser[0].delegate__c});
            }else {
                req1.setNextApproverIds(new Id[] {approvalUser[0].user__c});
            }
            system.debug('approval user : ' + approvalUser[0].user__c);
            system.debug('PG_ContactApprovalState Id : ' + ApprovalD);  
            req1.setObjectId(ApprovalD);
            Approval.ProcessResult result = Approval.process(req1);  
                // Send email notification to sales rep
            User us = [select id, PG_LearningMethod__c,Country,Email,LocaleSidKey from User where Id = :approvalUser[0].User__c];
            System.debug('Belgium Users###'+us.email);
            Map<String, Country_Code_settings__c> mcs = Country_Code_settings__c.getall();
            Country_Code_settings__c ccs = mcs.get(uu.LocaleSidKey);
             if(!concs.isPGCountry__c){
                if((concs.value__c != '' && concs.value__c != null) && psc.PG_ApprovalStatus__c == PG_Enums.APPROVAL_STATUS_TYPE.AwaitingCSApproval.Name()){
                    System.debug('Belgium Users###'+ccs.PGA_Affiliation_Approval_Request_CSR__c);
                    ET_EmailAdministration.SendEmail(us.Email, ccs.PGA_Affiliation_Approval_Request_CSR__c, '', uu.Name, uu.Email, '',acc.VAT_Number__c ,acc.Name,acc.PG_PharmacyRegistrationNumber__c,Mname,acc.BillingCity,acc.BillingPostalcode,acc.BillingStreet);
                }else{
                    if((concs.value__c != '' && concs.value__c != null) && psc.PG_ApprovalStatus__c == PG_Enums.APPROVAL_STATUS_TYPE.AwaitingSalesRepApproval.Name())
                        ET_EmailAdministration.SendEmail(us.Email, ccs.PGA_Affiliation_Approval_Request_SR__c, '', uu.Name, uu.Email, '', acc.VAT_Number__c, acc.Name,acc.PG_PharmacyRegistrationNumber__c,Mname,acc.BillingCity,acc.BillingPostalcode,acc.BillingStreet);
                    if((concs.value__c == '' && concs.value__c == null) && psc.PG_ApprovalStatus__c == PG_Enums.APPROVAL_STATUS_TYPE.AwaitingSalesRepApproval.Name())
                        ET_EmailAdministration.SendEmail(us.Email, ccs.PGA_Affiliation_Approval_Request_SR__c, '', uu.Name, uu.Email, '', acc.VAT_Number__c, acc.Name,acc.PG_PharmacyRegistrationNumber__c,Mname,acc.BillingCity,acc.BillingPostalcode,acc.BillingStreet);
                }
             }else {
                System.debug('Belgium Users###'+ccs.Salesrep_Notification__c);
                ET_EmailAdministration.SendEmail(us.Email, ccs.Salesrep_Notification__c, '', '', '', '', '', '','','','','','');
             }                   
        }
    }
    
    @future
    public Static void updateAffiliation(String Affiliation){
        System.debug('Affiliation#####>>>>>'+Affiliation);
        List<Account_Affiliation__c> upAffList = (List<Account_Affiliation__c>)json.deserialize(Affiliation, List<Account_Affiliation__c>.class);
        System.debug('Affiliation List#####>>>>>'+Affiliation);
        update upAffList;
    } 
    
  
    public static void ApproveReject(ID logedUserId, ID ApprovalstateId, String Label){
        // First, get the ID of the newly created item
        List<processinstance> pis = [select id from processinstance where targetobjectId = :ApprovalstateId and status = :PG_Enums.APPROVAL_STATUS_TYPE.Pending.name() limit 1];
            if(!pis.isEmpty()){
                List<processinstanceworkitem> iwis = [select id, OriginalActorId from processinstanceworkitem where processinstanceid = :pis[0].id limit 1];
                
                if(!iwis.isEmpty()){
                    // Instantiate the new ProcessWorkitemRequest object and populate it
                    system.debug('OriginalActorId : ' + iwis[0].OriginalActorId);
                    system.debug('UserInfo.getUserId : ' + logedUserId);
                    if (iwis[0].OriginalActorId == logedUserId) {
                        Approval.ProcessWorkitemRequest req2 = new Approval.ProcessWorkitemRequest();
                        
                        if (Label == 'Approve'){
                            req2.setAction('Approve');
                        } else {
                            req2.setAction('Reject');
                        }
                        
                        req2.setNextApproverIds(new Id[] {logedUserId});
                        
                        // Use the ID from the newly created item to specify the item to be worked
                        req2.setWorkitemId(iwis[0].id);
                        
                        // Submit the request for approval
                        Approval.ProcessResult result2 =  Approval.process(req2);
                    } else {
                        User u = [select firstname,Lastname from user where id = :iwis[0].OriginalActorId];
                    }
                }
            }
    } 
    
    //Affiliation Approval Email send
    public static void affiliationApprovalEmail(String accId, String conId, String action){
        
        Set<Id> ConIDs = new Set<Id>();
        Set<Id> cfId = new Set<Id>();
        
        Map<String, Country_Code_settings__c> mcs = Country_Code_settings__c.getall();
        System.debug('Action###'+action);
        if((accId!=null && accId!='') && (conId==null && conId=='')){
            System.debug('Accid###'+accId);
            List<Account_Affiliation__c> mgrAffi = [Select Id, Account_ID__c, Contact_ID__c from Account_Affiliation__c where Account_ID__c =:accId];
            if(mgrAffi.size()>0){
            for(Account_Affiliation__c a :mgrAffi){
                    ConIDs.add(a.Contact_ID__c);
                }
            }
        
            List<Contact> AffContacts = [Select ID, Email, AccountID,Name, (Select Contact__c, PG_SubRole__r.role__c From Users__r where PG_SubRole__r.role__c='Manager') from Contact where ID IN: ConIDs];
            if(AffContacts.size()>0){
                for(Contact cf:AffContacts){
                    for(PG_ContactUser__c pg:cf.Users__r){
                        if(pg.PG_SubRole__r.role__c == 'Manager'){
                            cfid.add(cf.Id);
                        }
                    }
                }
            }
            User u = [Select Id, Username, Email, Localesidkey, LanguageLocalekey, Contact.Account.PG_Account__c from User where ContactId=:cfid];
            Country_Code_settings__c ccs = mcs.get(u.LocaleSidKey);
            if(u.Contact.Account.PG_Account__c == true){
                ET_EmailAdministration.SendEmail(u.Email, ccs.Reg_Manager__c, '', '', '', '', '', '','','','','','');
            }else{
                ET_EmailAdministration.SendEmail(u.Email, ccs.PGA_Manager_Approval_Notification__c, '', '', '', '', '', '','','','','','');
            }
        }
        
        if((conId!=null && conId!='') && (accId!=null && accId!='')){
            User u = [Select Id, Username, Email, Localesidkey,Contact.Salutation, LanguageLocalekey,PG_Subrole__c,Contact.Title, Contact.LastName,Contact.firstname, Contact.Account.PG_Account__c,Contact.Account.PG_JnJCustomerCode__c,Contact.Account.Name from User where ContactId=:conId];
            PG_Subrole__c pg = [Select Id, Role__c, Name from PG_Subrole__c where Id=:u.PG_subrole__c];
            String accName;
            String accNumber;
            List<Account> lacc = [Select Id, Name, PG_JnJCustomerCode__c from Account where Id=:accId];
            for(Account acc:lacc){
                accName = acc.Name;
                accNumber = acc.PG_JnJCustomerCode__c;
            }
            Country_Code_settings__c ccs = mcs.get(u.LocaleSidKey);
            Attributes__c title = Attributes__c.getValues(u.LocaleSidKey);
            String strTitle = '';
            if(title != null && u.Contact.Salutation!=null){ strTitle = String.valueof(title.get(u.Contact.Salutation.remove('.')+'__c')); }
            if(action == 'Accepted'){
                System.debug('Action###'+action);
                if(pg.Role__c == 'Manager' || pg.Role__c == 'Owner'){
                    if(u.Contact.Account.PG_Account__c == true){
                        ET_EmailAdministration.SendEmail(u.Email, ccs.PG_Welcome_Sec_Manager__c, '', strTitle, u.Contact.LastName, '', u.Contact.firstname, accName,accNumber,'','','','');
                    }else{
                        ET_EmailAdministration.SendEmail(u.Email, ccs.PGA_Welcome_Sec_Manager__c, '', strTitle, u.Contact.LastName, '', u.Contact.firstname,accName,accNumber,'','','','');
                    }
                }else{
                    if(u.Contact.Account.PG_Account__c == true){
                        ET_EmailAdministration.SendEmail(u.Email, ccs.PG_Welcome_Sec_NonManager__c, '', strTitle, u.Contact.LastName, '', u.Contact.firstname, accName,accNumber,'','','','');
                    }else{
                        ET_EmailAdministration.SendEmail(u.Email, ccs.PGA_Welcome_Sec_NonManager__c, '', strTitle, u.Contact.LastName, '', u.Contact.firstname, accName,accNumber,'','','','');
                    }
                }
            }else{
                System.debug('Action###'+action);
                if(pg.Role__c == 'Manager' || pg.Role__c == 'Owner'){
                    if(u.Contact.Account.PG_Account__c == true){
                        ET_EmailAdministration.SendEmail(u.Email, ccs.PG_Rejected_Sec_Pharmacy__c, '', strTitle, u.Contact.LastName, '', u.Contact.firstname,accName,accNumber,'','','','');
                    }else{
                        ET_EmailAdministration.SendEmail(u.Email, ccs.PGA_Rejected_Sec_Pharmacy__c, '', strTitle, u.Contact.LastName, '', u.Contact.firstname,accName,accNumber,'','','','');
                    }
                }else{
                    if(u.Contact.Account.PG_Account__c == true){
                        ET_EmailAdministration.SendEmail(u.Email, ccs.PG_Rejected_Sec_Pharmacy_User__c, '', strTitle, u.Contact.LastName, '', u.Contact.firstname,accName,accNumber,'','','','');
                    }else{
                        ET_EmailAdministration.SendEmail(u.Email, ccs.PGA_Rejected_Sec_Pharmacy_User__c, '', strTitle, u.Contact.LastName, '', u.Contact.firstname, accName,accNumber,'','','','');
                    }
                } 
            }
        }
    }
        
    @future
    public static void primarypharmacyUpdate(Id cid, Id accid){
        
        PG_TriggerRunFuture.stopFuture();
        Set<Id> cids = new Set<Id>();
        Set<Id> affid = new Set<Id>();     
        User us = [Select Id, ManagerId, Profile.Name from User where Contactid=:cid];
        List<Contact> lstCons = [Select ID, Email, AccountID, (Select Contact__c, PG_SubRole__r.role__c, PG_Subrole__r.ManagerActive__c From Users__r) from Contact where AccountID=: accid];
                
        for(Contact cc:lstCons){
            if(cc.Users__r[0].PG_SubRole__r.role__c == 'Manager') cids.add(cc.id);
        }
        List<Account_Affiliation__c> lstacc = [Select Contact_ID__c From Account_Affiliation__c where Account_ID__c=:accid];
                
        for(Account_Affiliation__c aff:lstacc){
            affid.add(aff.Contact_ID__c);
            System.debug('ContIdS####'+affid);
        }
        List<Contact> lstcon = [Select ID, Email, AccountID, (Select Contact__c, PG_SubRole__r.role__c, PG_Subrole__r.ManagerActive__c From Users__r) from Contact where Id=:affid];
        for(Contact cc:lstcon){
            if(cc.Users__r[0].PG_SubRole__r.role__c == 'Manager') cids.add(cc.id);
        }
                      
        User uu = [Select Id from User where ContactId=:cids];
        us.ManagerId = uu.Id;
        if(us.Profile.Name == 'External_PharmacyUser') update us;
        PG_TriggerRunFuture.allowFuture();

    }   
    
    webservice static void ApproveandReject(string lst,string act)
     {
       
         system.debug('Json::'+lst);
         system.debug('Jsonaction::'+act);
         list<string> insertAccList =  (list<string>)JSON.deserializeStrict(lst, list<string>.class);
         system.debug('Lst::'+insertAccList);
         List<processinstance> pis = new list<processinstance>([select id from processinstance where targetobjectId IN :insertAccList and status = :PG_Enums.APPROVAL_STATUS_TYPE.Pending.name() ]);
         system.debug('Lst2::'+pis);
         if(pis.size()!=0)
         {
           List<processinstanceworkitem> iwis = new list<processinstanceworkitem>([select id, OriginalActorId from processinstanceworkitem where processinstanceid IN :pis ]);
           list<Approval.ProcessWorkitemRequest> processworkitem=new list<Approval.ProcessWorkitemRequest> ();
           
           for(processinstanceworkitem pw:iwis)
           {
                    Approval.ProcessWorkitemRequest req2 = new Approval.ProcessWorkitemRequest();
                         req2.setAction('Approve'); 
                         
                         // Use the ID from the newly created item to specify the item to be worked
                         req2.setWorkitemId(pw.id); 
                         processworkitem.add(req2);
                          // Submit the request for approval
                          
             
           }
           List<Approval.ProcessResult> result2 = new list<Approval.ProcessResult>();
           if(processworkitem.size()!=0)
             result2= Approval.process(processworkitem);
         }
          
               
     }  
     
      public static void sendRemovalnotification(String accId, String conId){
            User uu = [Select Id, Name, Contact.Salutation,Contact.Title, Contact.LastName,Contact.firstname, Email, Localesidkey, PG_SubRole_Name__c from User where ContactId=:conId];
            Contact cc = [Select ID, AccountId, Account.PG_Account__c,Firstname, Lastname, Account.BillingCity,Account.Name,Account.PG_JnJCustomerCode__c,ownerId from Contact where Id =: conId];
            Account acc = [Select Id, Name, BillingCity, PG_PharmacyRegistrationNumber__c, PG_Account__c,PG_JnJCustomerCode__c from Account where Id=:accId];
            Map<String, Country_Code_settings__c> mcs = Country_Code_settings__c.getall();
            Country_Code_settings__c ccs = mcs.get(uu.LocaleSidKey);
            String lfname = cc.Lastname+' '+cc.Firstname;
            if(uu.Localesidkey == 'fr_FR'){
                User fruser = [Select Id, Email, Name from User where Id=:cc.OwnerId];
                if(acc.PG_Account__c == true){
                    ET_EmailAdministration.SendEmail(uu.Email, ccs.PG_Remove_Confirmation__c, '', '', '', '','', acc.Name,acc.PG_JnJCustomerCode__c,'',acc.Billingcity,'','');
                    ET_EmailAdministration.SendEmail(fruser.Email, ccs.PG_Salesrep_FR_Rem_Notification__c, uu.Email, '', '', '',uu.PG_SubRole_Name__c, acc.Name,acc.PG_JnJCustomerCode__c,lfname,acc.Billingcity,'','');
                }else{
                    ET_EmailAdministration.SendEmail(uu.Email, ccs.PGA_Remove_Confirmation__c,  '', '', '', '','', acc.Name,acc.PG_JnJCustomerCode__c,'',acc.Billingcity,'','');
                    ET_EmailAdministration.SendEmail(fruser.Email, ccs.PGA_Salesrep_FR_Rem_Notification__c,uu.Email, '', '', '',uu.PG_SubRole_Name__c, acc.Name,acc.PG_JnJCustomerCode__c,lfname,acc.Billingcity,'','');
                }
            }else{
                System.debug('Other country emails');
                Attributes__c title = Attributes__c.getValues(uu.LocaleSidKey);
                String strTitle = '';
                if(title != null && uu.Contact.Salutation!=null){ strTitle = String.valueof(title.get(uu.Contact.Salutation.remove('.')+'__c')); }
                if(acc.PG_Account__c == true){
                    ET_EmailAdministration.SendEmail(uu.Email, ccs.PG_Remove_Confirmation__c, '', strTitle, uu.Contact.LastName, '', uu.Contact.firstname, acc.Name,acc.PG_JnJCustomerCode__c,'','','','');
                }else{
                    ET_EmailAdministration.SendEmail(uu.Email, ccs.PGA_Remove_Confirmation__c, '',strTitle, uu.Contact.LastName, '', uu.Contact.firstname, acc.Name,acc.PG_JnJCustomerCode__c,'','','','');
                }
            }
      }
      
    @future
    public static void setProfileAndRoleUserBefore(Id UserId, Id SubRole, Id AccountId){
      
      //Stop subsequent future calls as result from triggers.
      //See class for info.
      PG_TriggerRunFuture.stopFuture();
      
        System.debug('Subrole: ' + SubRole);
        PG_SubRole__c sr = [select Role__c, Profile__c from PG_SubRole__c where Id = :SubRole];
        String Role = '%' + sr.Role__c;
        
        if(sr.Role__c == 'Owner' || sr.Role__c == 'Manager')  Role = '%Manager';
        
        UserRole ur = [select id from UserRole where PortalAccountId = :AccountId and name like :Role];
        list<User> u = [select UserRoleId,email,id,PG_SubRole__c from User where Id = :UserId];
        
        u[0].UserRoleId = ur.id;
        
        //Update profile
        Profile prof = [ select id from profile where name = :sr.Profile__c ];
  
        u[0].ProfileId = prof.Id;
        u[0].PG_SubRole__c = SubRole;
        System.debug('TEstRole#####'+ u[0].PG_SubRole__c);
        update u;
        System.debug('TEstRole#####'+ u);
        PG_User.processPermSetsNew(u);
    //Re-allow future calls.
    //Technically not neccessary because of static behaviour in salesfore.
    //See PG_TriggerRunFuture for mor einfo on static behaviour.
        PG_TriggerRunFuture.allowFuture();
    }
}