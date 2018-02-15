@RestResource(urlMapping='/Pharmacycom/v1/PeopleService/*')
global with sharing class BusinessPeople{
    global static final String  GENERIC_ERROR = 'GEN0001'; 
    global static final String  GENERIC_ERROR_TYPE = 'Generic';        
    global static final String  PEOPLE_ERROR = 'PC0019';
    global static final String  PEOPLE_ERROR_TYPE = 'People Service';
    global static final String  PEOPLE_SUBMITTED = 'PC0032';
    global static final String  INVALID_USER = 'PC0037';
     
    @HttpGet
    global static String doGet(){
        RestRequest req  = RestContext.request;
        RestResponse res = RestContext.response;
        try{
            String UserId = req.requestURI.substring(req.requestURI.lastIndexOf('/')+1);
            System.debug('UserId:'+UserId);
            if(UserId =='' || UserId ==null) UserId = userinfo.getUserId();
            return getPeople(UserId);    
        }catch(Exception e){
            System.debug('Message1:'+e.getMessage());
            throw new CustomException(PG_Utils.getException(GENERIC_ERROR,GENERIC_ERROR_TYPE, CustomException__c.getValues('GEN0001').Error_Description__c));
        }
    }
    
        global static String getPeople(String UserId){
        try{
            List<Peoples> lstPeople = new List<Peoples>();
            List<User> users = [Select Id, ContactId from User where Id =: UserId];

            /**Query the affiliated accounts for the logged in manager**/
            List<Account_Affiliation__c> TotAffiliationlst= new List<Account_Affiliation__c>();
            List<Account_Affiliation__c> ConAffiliationlst= new List<Account_Affiliation__c>();
            map<ID,Map<id,Account_Affiliation__c>> conids=new map<ID,Map<id,Account_Affiliation__c>>();
            map<string,list<Affiliation_Function__c>> confunctions = new map<string,list<Affiliation_Function__c>>();
            Map <ID,ID> mapaffiliations = new Map<ID,ID> ();
            TotAffiliationlst=[Select id,Account_ID__c,Account_ID__r.Name, Account_ID__r.HQ_Account__c,Account_ID__r.Parent.id ,Account_ID__r.E_Commerce_Eligibility__c,Account_ID__r.Partner_Numbers__c,Contact_ID__c,Affiliation_ApprovalState__r.PG_ApprovalStatus__c,(select id, PG_FunctionalityAccessPerSubRole__c,PG_FunctionalityAccessPerSubRole__r.PG_Functionality__r.Name from Affiliation_Functions__r) from Account_Affiliation__c where Contact_ID__c IN (Select contactid from USer where id =:UserId) and Affiliation_ApprovalState__r.PG_ApprovalStatus__c = 'Accepted'];
            system.debug('LOFAffiliations::'+TotAffiliationlst);
            for(Account_Affiliation__c taff:TotAffiliationlst)
            {
                mapaffiliations.put(taff.Account_ID__c,taff.Account_ID__c);
            }
            system.debug('MapAffiliations::'+mapaffiliations);
            /**Query contacts affiliated with all pharmacy of the logged in user**/
            ConAffiliationlst=[Select id,Account_ID__c,Contact_ID__c,IsPrimary__c,Approvalstate__c,Affiliation_ApprovalState__r.PG_ApprovalStatus__c,(select id, PG_FunctionalityAccessPerSubRole__c,PG_FunctionalityAccessPerSubRole__r.PG_Functionality__r.Name from Affiliation_Functions__r) from Account_Affiliation__c where Account_ID__c IN :mapaffiliations.keyset()];
            for(Account_Affiliation__c conaff :ConAffiliationlst)
            {
                if(conids.containsKEY(conaff.Contact_Id__c))
                {
                    conids.get(conaff.Contact_Id__c).put(conaff.Account_ID__c,conaff);
                }
                else
                {  
                    Map<id,Account_Affiliation__c> conmapaffiliations= new Map<id,Account_Affiliation__c> ();
                    conmapaffiliations.put(conaff.Account_ID__c,conaff);
                    conids.put(conaff.Contact_Id__c,conmapaffiliations);
                }
                if(conaff.Affiliation_Functions__r.size()!=0)
                  confunctions.put(string.valueOF(conaff.Contact_Id__c)+string.valueOF(conaff.Account_ID__c),conaff.Affiliation_Functions__r);
            }
            List<Contact> contacts = [Select Id, FirstName, LastName, Email, AccountId, Account.Name,Account.E_Commerce_Eligibility__c,Account.Partner_Numbers__c, PG_ContactApprovalState__r.PG_ApprovalStatus__c, View_Training__c,Role_Description__c, (Select PG_SubRole__r.Name,PG_SubRole__r.role__c,User__c, User__r.Id From Users__r) from Contact where (ID IN :conids.keyset() AND (PG_ContactApprovalState__r.PG_ApprovalStatus__c!='Rejected' AND PG_ContactApprovalState__r.PG_ApprovalStatus__c!='Deactivated' AND PG_ContactApprovalState__r.PG_ApprovalStatus__c!='Deleted'))];
            for(Contact con : contacts){
                
                Map<id,Account_Affiliation__c> indconaff =new Map<id,Account_Affiliation__c>();
                indconaff=conids.get(con.id);
                List<Affiliation> caff= new List<Affiliation>();
                System.debug('Contact with status :'+con);
                Peoples people = new Peoples();
                people.FirstName = con.FirstName;
                people.LastName = con.LastName;
                people.EmailAddress = con.Email;
                people.PrimaryPharmacyId = con.AccountId;
                people.PrimaryPharmacyName = con.Account.Name;
                people.ContactId = con.Id;
                people.UserID = Con.Users__r[0].User__c;
                people.ViewMyTrainingRecords = con.View_Training__c;
                System.debug('Subrole user size::'+Con.Users__r.size());
                System.debug('Contact::'+Con.Users__r[0]);
                people.JobRole = Con.Users__r[0].PG_SubRole__r.Name;
                people.RoleDescription = con.Role_Description__c;
                people.Status = con.PG_ContactApprovalState__r.PG_ApprovalStatus__c;
                for(Account_Affiliation__c accaff:TotAffiliationlst)
                {
                        if(indconaff.containsKey(accaff.Account_ID__c))
                        {
                            list<Function> afunc= new list<Function>();
                            Affiliation aftrue=new Affiliation();
                            aftrue.Name = accaff.Account_ID__r.Name;
                            aftrue.id = accaff.Account_ID__c;
                            aftrue.EComm_Eligible=accaff.Account_ID__r.E_Commerce_Eligibility__c;
                            aftrue.BillToNumbers = accaff.Account_ID__r.Partner_Numbers__c;
                            aftrue.IsHeadOfChain = accaff.Account_ID__r.HQ_Account__c;
                            aftrue.ChainHeadID   = accaff.Account_ID__r.Parent.id;
                            aftrue.AffiliationID = indconaff.get(accaff.Account_ID__c).Id;
                            aftrue.Approvalstate = indconaff.get(accaff.Account_ID__c).Affiliation_ApprovalState__r.PG_ApprovalStatus__c;
                            aftrue.IsPrimary = indconaff.get(accaff.Account_ID__c).isPrimary__c;
                            aftrue.Association = true;
                            system.debug('Afunctions::'+accaff.Affiliation_Functions__r.size());
                            if(confunctions.containsKey(string.ValueOF(con.id)+String.valueOF(accaff.Account_ID__c))&&confunctions.get(string.ValueOF(con.id)+String.valueOF(accaff.Account_ID__c)).size()!=0)
                            {
                                for(Affiliation_Function__c aff:confunctions.get(string.ValueOF(con.id)+String.valueOF(accaff.Account_ID__c)))
                                {
                                    Function f= new Function();
                                    f.Name=aff.PG_FunctionalityAccessPerSubRole__r.PG_Functionality__r.Name;
                                    f.ID=aff.id;
                                    afunc.add(f);
                                }
                            }
                            aftrue.Functions=afunc;
                            caff.add(aftrue);
                            System.debug('IndAFF###'+caff.size());
                            System.debug('IndAFF###'+caff);
                        }
                        else
                        {
                            Affiliation affalse=new Affiliation();
                            affalse.Name = accaff.Account_ID__r.Name;
                            affalse.Id = accaff.Account_ID__c;
                            affalse.EComm_Eligible=accaff.Account_ID__r.E_Commerce_Eligibility__c;
                            affalse.BillToNumbers = accaff.Account_ID__r.Partner_Numbers__c;
                            affalse.IsHeadOfChain = accaff.Account_ID__r.HQ_Account__c;
                            affalse.ChainHeadID   = accaff.Account_ID__r.Parent.id;
                            affalse.Approvalstate='';
                            affalse.Isprimary=false;
                            affalse.Association=false;
                            affalse.Functions=new list<Function>();
                            caff.add(affalse);
                            System.debug('OutAFF###'+caff.size());
                            System.debug('OutAFF###'+caff);
                        }
                }
                people.Pharmacy=caff;
                 /*&& Con.Users__r[0].PG_SubRole__r.role__c!='Owner' code is added not show owner when manager requests people service .Added Date 15-03-2017 by Mahesh*/
                if(UserId != Con.Users__r[0].User__c && Con.Users__r[0].PG_SubRole__r.role__c!='Owner') lstPeople.add(people);
            }
            System.debug('lstPeople:'+lstPeople);
            return json.serialize(lstPeople);
        }catch(Exception e){
            return e.getmessage();
        }
        return null;
    }
    
    global class Peoples{
        public String FirstName {get;set;}
        public String LastName  {get;set;}
        public String JobRole {get;set;}
        public string RoleDescription{get;set;}
        public String PrimaryPharmacyId {get;set;}
        public String PrimaryPharmacyName {get;set;}
        public String Status {get;set;}
        public String EmailAddress {get;set;}
        public String ContactId  {get;set;}
        public String UserID {get;set;}
        public list<Affiliation> Pharmacy{get;set;}
        public boolean ViewMyTrainingRecords {get;set;}
    } 
    
    global class Affiliation{
        public String Name {get;set;}
        public String ID {get;set;} 
        public String AffiliationID {get;set;}   
        public Boolean Association {get;set;}
        public Boolean IsPrimary{get;set;}
        public string Approvalstate{get;set;}
        public string EComm_Eligible{get;set;}
        public string BillToNumbers{get;set;}
        public boolean IsHeadOfChain{get;set;}
        public string  ChainHeadID{get;set;}
        public List<Function> Functions {get;set;}
    }
    
    public class Function{
        public String Name {get;set;}
        public String ID {get;set;}
    }
    
    @HttpPost
    global static String doPost(){
        RestRequest req  = RestContext.request;
        RestResponse res = RestContext.response;
        try{
            Blob body = req.requestBody;
            System.debug('bodyString:'+body.toString());
            
            Map<String, Object> m = (Map<String, Object>) JSON.deserializeUntyped(body.toString());
            System.debug('peopel::'+m.get('People'));
            
            System.debug('#######'+JSON.serialize(m.get('People')));
            List<People> people = (List<People>)JSON.deserialize(JSON.serialize(m.get('People')),List<People>.class);
            System.debug('#######'+m.get('userId'));
            
            Person person = new person();
            person.userId = String.valueof(m.get('userId'));
            if(person.userId == '' && person.userId == null) person.userId = userinfo.getUserID();
            person.action = String.valueof(m.get('action'));
            person.people = people;
            
            return addPeople(person);                
        }catch(Exception e){
            System.debug('Message1:'+e.getMessage());
            throw new CustomException(PG_Utils.getException(PEOPLE_ERROR,GENERIC_ERROR_TYPE, CustomException__c.getValues('GEN0001').Error_Description__c));
        }
        return null;
    }
        
    global static String addPeople(Person person){
        try{
            System.debug('Person:'+person);
            
            List<String> LastName = new List<String>();
            List<String> Email = new List<String>();
            Map<Id,Contact> lstCon = new Map<Id,Contact>(); 
            Map<Id,Contact> mpCon = new Map<Id,Contact>(); 
            Set<ID> AccIds = new Set<ID>();
            Set<ID> userIds = new Set<ID>();
            List<Errors> errors = new List<Errors>();   
            List<People> newPeople = new List<People>();
            User u = [Select id, contactid,PG_Country_Id__c from User where Id=:UserInfo.getUserId()];
            if(person.action == 'add'){
                List<People> lstpeople = person.people;
                List<ResultPerPeople> actionPerPeopleList = new List<ResultPerPeople>();
                if(lstpeople.size()>0 && !lstpeople.isEmpty())
                    for(People p : lstpeople){
                        if(!PG_Utils.IsValidEmailFormat(p.EmailAddress) && p.EmailAddress != '' && p.EmailAddress != null && p.LastName != '' && p.LastName != null && p.PharmacyId != null && p.PharmacyId != ''){
                            p.PharmacyId = (Id)p.PharmacyId;
                            LastName.add(p.LastName);
                            Email.add(p.EmailAddress);
                            System.debug('::::'+p.PharmacyId);
                            AccIds.add(p.PharmacyId);
                            newPeople.add(p);
                        }else{
                            Errors e = new Errors();
                            e.EmailAddress = P.EmailAddress;
                            e.ErrorMessage = 'Last name, email and Pharmacy cannot be empty or invalid email address';
                            e.ErrorCode = 'PC0036';
                            errors.add(e);     
                            actionPerPeopleList.add(new ResultPerPeople(P.EmailAddress, null, ActionDonePerPeople.NotAdded_Error));
                        }
                    }
                System.debug('Email:'+Email.size());
                List<Contact> lstContact = new  List<Contact>();
                Map<ID, Account> lstAccounts = new  Map<ID,Account>([Select ID, ownerId,billingcountry From Account where ID IN: AccIds]);
                if(Email.size() >0) lstContact = [Select Id, LastName, Email, AccountID, Account.OwnerID, PG_ContactApprovalState__r.PG_ApprovalStatus__c,(Select PG_SubRole__r.Name,PG_SubRole__r.role__c,User__c, User__r.Id,PG_Subrole__r.ApprovalSalesRep__c,PG_Subrole__r.Approval_CustomerService__c From Users__r), (Select Id, Account_ID__c, Contact_ID__c, Affiliation_ApprovalState__c,Affiliation_ApprovalState__r.PG_ApprovalStatus__c From Account_Affiliations__r) from Contact where LastName IN:LastName OR Email IN: Email];

                System.debug('lstContact:'+lstContact.size());
                System.debug('newPeople:'+newPeople);
                if(lstContact.size() == 0 ){
                    for(People p : lstpeople){
                        Errors e = new Errors();
                        e.EmailAddress = p.EmailAddress;
                        e.ErrorMessage = CustomException__c.getValues('PC0019').Error_Description__c;
                        e.ErrorCode = 'PC0019';
                        errors.add(e);
                    }
                    Error er =  new Error();
                    er.errors = errors;
                    er.Status = 'failure';
                    return json.serialize(er);              
                }
                
                Map<String,Contact> mpContact =  new Map<String, Contact>();
                Map<String,Account_Affiliation__c> mpAffiliation =  new Map<String, Account_Affiliation__c>();
                List<PG_ContactApprovalStatus__c> lstConApprovals = new List<PG_ContactApprovalStatus__c>();
                Map<Contact,PG_ContactApprovalStatus__c>  mapConApp = New Map<Contact,PG_ContactApprovalStatus__c>();
                for(Contact c : lstContact){
                    mpContact.put(c.LastName+c.Email,c);
                    mpCon.put(c.Id,c);
                    for(Account_Affiliation__c af : c.Account_Affiliations__r){
                      mpAffiliation.put(String.valueof(af.Account_ID__c)+String.valueof(af.Contact_ID__c),af);
                    }
                }
                if(lstContact.size() >0 ) {
                    //looking for existing affiliations for those people who "will be added" to the pharmacy
                    string soql = 'SELECT Contact_ID__c, Account_ID__c FROM Account_Affiliation__c WHERE ';
                    boolean firstClause = true;
                    
                    for(People p : newPeople) {
                        Contact c = mpContact.get(p.LastName+P.EmailAddress);
                        if (c != null) {
                            if (firstClause) {
                                firstClause = false;
                            }else {
                                soql = soql + ' OR';
                            }

                            soql = soql + ' (Contact_ID__c = \'' + c.Id + '\' AND Account_ID__c = \'' + p.PharmacyId + '\')';
                        }
                    }
                    system.debug('affiList>>:::::' +soql);
                    List<Account_Affiliation__c> affiList = (List<Account_Affiliation__c>)Database.query(soql);
                    system.debug('affiList>>:::::' +affiList);
                    Map<String, Account_Affiliation__c> affByPharmacyContact = new Map<String, Account_Affiliation__c>();
                    for(Account_Affiliation__c aff: affiList) {
                        affByPharmacyContact.put(string.valueOf(aff.Account_ID__c) + string.valueOf(aff.Contact_ID__c), aff);
                    }
                    
                    for(People p : newPeople){
                        if(mpContact.containsKey(p.LastName+P.EmailAddress)){
                                Contact c = mpContact.get(p.LastName+P.EmailAddress);
                            	Account addacc = lstAccounts.get(p.PharmacyId);
                                System.debug('PharmacyId::'+p.PharmacyId +':'+p.EmailAddress);
                                c.AccountId = p.PharmacyId;
                                if (affByPharmacyContact.keySet().contains(p.PharmacyId + string.valueOf(c.Id))) {    
                                    actionPerPeopleList.add(new ResultPerPeople(p.EmailAddress, c.id, ActionDonePerPeople.NotAdded_AlreadyBelongsToPharmacy));
                                } else  {
                                    actionPerPeopleList.add(new ResultPerPeople(p.EmailAddress, c.id, ActionDonePerPeople.Added));
                                }                               
                                if(mpAffiliation.containsKey(p.PharmacyId+String.valueof(c.Id))) {
                                  c.PG_ContactApprovalState__c = mpAffiliation.get(p.PharmacyId+String.valueof(c.Id)).Affiliation_ApprovalState__c;
                                }else{
                                  // No affiliation found, create new affiliaion and submit approval
                                  PG_ContactApprovalStatus__c cap = new PG_ContactApprovalStatus__c();
                                  cap.Account_ID__c = p.PharmacyId;
                                  cap.Contact_ID__c = c.Id;
                                  cap.PG_LearningMethod__c = 'PHB';
                                  cap.PG_SupportedCountry__c = u.PG_Country_Id__c;
                                  if(addacc.billingcountry=='CH')
                                  {
                                  	if(c.Users__r[0].PG_Subrole__r.ApprovalSalesRep__c)
                                  		cap.PG_ApprovalStatus__c = 'AwaitingSalesRepApproval';
                                  	else                                  	
                                  		cap.PG_ApprovalStatus__c = 'Accepted';
                                  }
                                  else
                                  cap.PG_ApprovalStatus__c = 'Accepted';
                                  lstConApprovals.add(cap);
                                  mapConApp.put(c,cap);
                                }
                                lstCon.put(c.id,c);
                                
                        }else{
                            Errors e = new Errors();
                            e.EmailAddress = P.EmailAddress;
                            e.ErrorMessage = CustomException__c.getValues('PC0019').Error_Description__c;
                            e.ErrorCode = 'PC0019';
                            errors.add(e);
                            
                            actionPerPeopleList.add(new ResultPerPeople(p.EmailAddress, null, ActionDonePerPeople.NotAdded_ContactNotFound));
                        }
                    }
                    insert mapConApp.values();
                    List<Account_Affiliation__c> Afflist = new List<Account_Affiliation__c>();
                    for(PG_ContactApprovalStatus__c app : mapConApp.values()){
                      Account_Affiliation__c fa = new Account_Affiliation__c();
                      fa.Account_ID__c = app.Account_ID__c;
                      fa.Contact_ID__c = app.Contact_ID__c;
                      fa.Affiliation_ApprovalState__c = app.Id;
                      Account cons = lstAccounts.get(app.Account_ID__c);
                      System.debug('Contact aproavelladlfad:'+cons);
                      //AffiliationApproval.setprocessInstance(cons.OwnerID,app.Id);
                      //System.debug('Contact aproavelladlfad:'+cons);
                      Afflist.add(fa);
                    }
                    insert Afflist; 
                    update lstCon.values();
                    if(lstCon.values().size() >0){
                        Error e = new Error();
                        if(errors.size() == 0){
                            e.Status = 'Success';
                        }
                        else {
                            e.Status = 'failure';
                        }
                        e.errors = errors;
                        e.peopleResult = actionPerPeopleList;
                        //PGA Add Pharmacy Email flow changes
                        if(errors.size() == 0){
                            for(Contact cd:lstCon.values()){
                                userIds.add(cd.Id);
                            }
                            List<User> lu = [Select Id, Name, Email, Localesidkey, Contact.Title,Contact.Salutation, Contact.LastName,contact.firstname, Contact.Account.PG_Account__c,Contact.Account.Name,Contact.Account.PG_JnJCustomerCode__c from User where Contactid IN:userIds];
                            Map<String, Country_Code_settings__c> mcs = Country_Code_settings__c.getall();
                            for(User uu:lu){
                                Country_Code_settings__c ccs = mcs.get(uu.LocaleSidKey);
                                Attributes__c title = Attributes__c.getValues(uu.LocaleSidKey);
                                String strTitle = '';
                                if(title != null && uu.Contact.Salutation!=null){ strTitle = String.valueof(title.get(uu.Contact.Salutation.remove('.')+'__c')); }
                                if(uu.Contact.Account.PG_Account__c == true){
                                    ET_EmailAdministration.SendEmail(uu.Email, ccs.PG_Confirmation_Frozen__c, '', strTitle, uu.Contact.LastName, '', uu.Contact.firstname, uu.Contact.Account.Name,uu.Contact.Account.PG_JnJCustomerCode__c,'','','','');
                                }else{
                                    ET_EmailAdministration.SendEmail(uu.Email, ccs.PGA_Confirmation_Frozen__c, '', strTitle, uu.Contact.LastName, '', uu.Contact.firstname, uu.Contact.Account.Name,uu.Contact.Account.PG_JnJCustomerCode__c,'','','','');
                                }
                            }
                        }
                        return json.serialize(e);
                    }else{
                        Error e = new Error();
                        e.Status = 'failure';
                        e.errors = errors;
                        e.peopleResult = actionPerPeopleList;
                        return json.serialize(e);                       
                    }
                }
                
            }else if(person.action == 'invite'){
                
            }
            
        }catch(Exception e){
            System.debug('Exception::'+e.getMessage());
            return PG_Utils.getException(PEOPLE_ERROR,PEOPLE_ERROR_TYPE, CustomException__c.getValues('GEN0001').Error_Description__c);
        }
        return null;
    } 
    
    global class Person{
        public String userId {get;set;}
        public String action {get;set;}
        public List<People> people {get;set;}
    } 
    global class People{
        public String FirstName {get;set;}
        public String LastName  {get;set;}
        public String JobRole {get;set;}
        public String PharmacyId {get;set;} 
        public String EmailAddress {get;set;}
    }
    global class Error{
        public String Status {get;set;}
        public List<Errors> errors {get;set;}
        public List<ResultPerPeople> peopleResult {get;set;}
        
        public Error() {
            peopleResult = new List<ResultPerPeople>();
        }       
    }
    global class ResultPerPeople {
        public string email {get;set;}
        public Id contactId {get;set;}
        public ActionDonePerPeople actionDone {get;set;}

        public ResultPerPeople(string email, Id contactId, ActionDonePerPeople actionDone) {
            this.email = email;
            this.contactId = contactId;
            this.actionDone = actionDone;
        }
    }
    global enum ActionDonePerPeople {
        Added,
        NotAdded_AlreadyBelongsToPharmacy,
        NotAdded_ContactNotFound,
        NotAdded_Error
    }
    
    global class Errors{
        public String EmailAddress{get;set;}
        public String ErrorMessage{get;set;}
        public String ErrorCode{get;set;}
    }
    
    @HttpPut
    global static String doPut(){
        RestRequest req  = RestContext.request;
        RestResponse res = RestContext.response;
        try{
            Blob body = req.requestBody;
            System.debug('bodyString:'+body.toString());  
            Map<String, Object> m = (Map<String, Object>) JSON.deserializeUntyped(body.toString());
            ID ConID; ID Accid;
            String action;
            try{
                String Con = String.valueof(m.get('ContactId'));
                String acc = String.valueof(m.get('PharmacyId'));
                action = String.valueof(m.get('action'));
                if(Con == '' || Con == null) throw new CustomException(PG_Utils.getException(PEOPLE_ERROR,PEOPLE_ERROR_TYPE, CustomException__c.getValues('PC0024').Error_Description__c));
                if(acc == '' || acc == null) throw new CustomException(PG_Utils.getException(PEOPLE_ERROR,PEOPLE_ERROR_TYPE, CustomException__c.getValues('PC0023').Error_Description__c));
                if(action == '' || action == null) throw new CustomException(PG_Utils.getException(PEOPLE_ERROR,PEOPLE_ERROR_TYPE, CustomException__c.getValues('PC0022').Error_Description__c));
                ConID =  String.valueof(m.get('ContactId'));
                Accid =  String.valueof(m.get('PharmacyId'));
            }catch(Exception e){
                if(e.getMessage().contains('Invalid id:')) throw new CustomException(PG_Utils.getException(PEOPLE_ERROR,PEOPLE_ERROR_TYPE, 'Invalid ID, please provide correct id value'));
                else return e.getMessage();
            }
            
            String userId = String.valueof(m.get('userId'));
            
            
            if(userId == '' || userId == null) userId = userinfo.getUserId(); // code chanaged on 27/8/15 due to the wrong conditions
            if(action == 'approve'){
                system.debug('userId: ' + userId);
                User u = [SELECT Id, Profile.UserLicense.Name FROM User WHERE Id = :userId];

                if (u.Profile.UserLicense.Name == 'Customer Portal Manager Standard') {
                    List<Contact> contact = [Select Id, AccountId, PG_ContactApprovalState__c, PG_ContactApprovalState__r.PG_ApprovalStatus__c,(Select Contact__c, PG_SubRole__r.ApprovalSalesRep__c, PG_SubRole__r.Approval_CustomerService__c From Users__r) from Contact where id =:ConID and AccountId =:Accid];
                    
                    if(contact.size() >0){
                      User us = [Select ID, ManagerId from user where ContactId =:contact[0].Id];
                        PG_ContactApprovalStatus__c app = new PG_ContactApprovalStatus__c();
                        app.id = contact[0].PG_ContactApprovalState__c;
                        if(contact[0].Users__r[0].PG_SubRole__r.ApprovalSalesRep__c == true){
                            app.PG_ApprovalStatus__c = 'AwaitingSalesRepApproval';
                        }else{
                            //Code Update on 10MAR17
                            if(contact[0].Users__r[0].PG_SubRole__r.Approval_CustomerService__c == true){
                                app.PG_ApprovalStatus__c = 'AwaitingCSApproval';
                            }else{
                                app.PG_ApprovalStatus__c = 'Accepted';
                            }
                        }
                        update app;
                        
                        // update manager ID for Fracne users because in frence user can able to register without manager
                        if (us.ManagerId == null){ 
                           us.ManagerId = u.Id;
                           update us;
                        }
                        
                    }else{
                        throw new CustomException(PG_Utils.getException(PEOPLE_ERROR,PEOPLE_ERROR_TYPE, CustomException__c.getValues(PEOPLE_ERROR).Error_Description__c));
                    }
                } else {
                    Contact contact = [Select PG_ContactApprovalState__c from Contact where id =:ConID and AccountId =:Accid AND (PG_ContactApprovalState__r.PG_ApprovalStatus__c = :PG_Enums.APPROVAL_STATUS_TYPE.AwaitingSalesRepApproval.Name() OR 
                                                                                            PG_ContactApprovalState__r.PG_ApprovalStatus__c = :PG_Enums.APPROVAL_STATUS_TYPE.AwaitingCSApproval.Name()) LIMIT 1];
                    if (contact != null) {
                        PG_ContactApprovalStatus__c app = new PG_ContactApprovalStatus__c();
                        app.id = contact.PG_ContactApprovalState__c;
                        app.PG_ApprovalStatus__c = PG_Enums.APPROVAL_STATUS_TYPE.Accepted.name();
                        update app;
                         AffiliationApproval.ApproveReject(u.Id,app.Id,'Approve');
                    }
                }
            }else if(action == 'reject'){
                User u = [SELECT Id, Profile.UserLicense.Name, PG_UserType__c FROM User WHERE Id = :userId];
                List<Contact> contact = [Select Id, AccountId, PG_ContactApprovalState__c, PG_ContactApprovalState__r.PG_ApprovalStatus__c from Contact where id =:ConID and AccountId =:Accid];
                if(contact.size() >0){
                    PG_ContactApprovalStatus__c app = new PG_ContactApprovalStatus__c();
                    app.id = contact[0].PG_ContactApprovalState__c;
                    app.PG_ApprovalStatus__c = 'Rejected';
                    update app;
                    if(userinfo.getUserType()=='Standard')
                    AffiliationApproval.ApproveReject(u.Id,app.Id,'Reject');
                    
                }else{
                    throw new CustomException(PG_Utils.getException(PEOPLE_ERROR,PEOPLE_ERROR_TYPE, CustomException__c.getValues(PEOPLE_ERROR).Error_Description__c));
                }               
            }else{
                throw new CustomException(PG_Utils.getException(PEOPLE_ERROR,PEOPLE_ERROR_TYPE, CustomException__c.getValues('PC0022').Error_Description__c));
            }
            JSONGenerator gen = JSON.createGenerator(true);
               gen.writeStartObject();
               gen.writeObjectField('Status','Success');
               gen.writeEndObject();
               String pretty = gen.getAsString();
            return pretty; 
                    
        }catch(Exception e){
            if(e.getmessage().contains('ALREADY_IN_PROCESS'))
                return PG_Utils.getException(PEOPLE_SUBMITTED,PEOPLE_ERROR_TYPE, CustomException__c.getValues('PC0032').Error_Description__c);
            else
                return e.getMessage();
        }
        return null;
    }
    
    @HttpDelete
    global static String doDelete(){
        RestRequest req  = RestContext.request;
        RestResponse res = RestContext.response;
        try{
            Blob body = req.requestBody;
            System.debug('bodyString:'+body.toString());  
            Map<String, Object> m = (Map<String, Object>) JSON.deserializeUntyped(body.toString());
            Set<ID> accIDs = New Set<ID>();
            List<Account_Affiliation__c> Affiliations = New List<Account_Affiliation__c>();
            List<Account_Affiliation__c> delAffiliations = New List<Account_Affiliation__c>();
            List<Account_Affiliation__c> updateAffiliations = New List<Account_Affiliation__c>();
            String ConID =  String.valueof(m.get('ContactId'));
            String Accid =  String.valueof(m.get('PharmacyId'));
            String userId = String.valueof(m.get('userId'));
            if(userId == '' || userId == null) userId = userinfo.getUserId();
                User mgrusr=[Select id,Accountid,ContactID,PG_UserType__c,Localesidkey,Email from user where id =:userId];
                Map<String, Country_Code_settings__c> mcs = Country_Code_settings__c.getall();
                Country_Code_settings__c ccs = mcs.get(mgrusr.LocaleSidKey);
                
                if(mgrusr.PG_UserType__c == 'External'){
                    List<Account_Affiliation__c> mgrAffliation = [Select ID, isPrimary__c, Account_ID__c, Contact_ID__c from Account_Affiliation__c where Contact_ID__c =:mgrusr.ContactId];
                    Contact cc = [Select Id, Account.PG_Account__c, Account.BillingCity,Account.Name,Account.PG_PharmacyRegistrationNumber__c from Contact where Id=:ConID ];
                    System.debug('mgrAffliation:'+mgrAffliation);
                    for(Account_Affiliation__c af : mgrAffliation){
                        accIDs.add(af.Account_ID__c);
                    }
                    if(accIDs.size() >0){
                        Affiliations = [select ID,Contact_ID__c, Account_ID__c from Account_Affiliation__c where Account_ID__c IN:accIDs];
                        System.debug('Affiliations:'+Affiliations);
                        if(Affiliations.size() > 0){
                            for(Account_Affiliation__c a : Affiliations){
                                if(ConID == a.Contact_ID__c){
                                    a.OwnerId = mgrusr.Id;
                                    updateAffiliations.add(a);
                                    delAffiliations.add(a);
                                }
                            }
                            update updateAffiliations;
                            delete delAffiliations;
                          
                            List<Account_Affiliation__c> contactAffilitions = [Select id, Account_ID__c, Contact_ID__c, Affiliation_ApprovalState__r.PG_ApprovalStatus__c from Account_Affiliation__c where Contact_ID__c =:ConID and Affiliation_ApprovalState__r.PG_ApprovalStatus__c = 'Accepted' ORDER BY CreatedDate desc ];
                            System.debug('contactAffilitions:'+contactAffilitions);
                            if(contactAffilitions.size()>0){
                                Contact c = [Select ID, AccountId from Contact where Id =: ConID];
                                c.AccountId = contactAffilitions[0].Account_ID__c;
                                update c;
                            }else{
                                Contact c = [Select ID, AccountId, Account.PG_Account__c, Account.BillingCity,Account.Name,Account.PG_PharmacyRegistrationNumber__c,ownerId from Contact where Id =: ConID];
                                c.AccountId = Default_JnJ_ID__c.getValues('ID').Value__c;
                                //update c;
                            }
                        }else{
                            throw new CustomException(PG_Utils.getException(PEOPLE_ERROR,PEOPLE_ERROR_TYPE, CustomException__c.getValues(PEOPLE_ERROR).Error_Description__c));
                        }
                    }
                }/*else if(mgrusr.PG_UserType__c == 'Internal'){
                     sales rep deletes Manager from Pharmacy
                    Account_Affiliation__c af = [select ID,Contact_ID__c, Account_ID__c from Account_Affiliation__c where Account_ID__c =:Accid and Contact_ID__c =:ConId];
                    Delete af;
                    List<Account_Affiliation__c> contactAffilitions = [Select id, Account_ID__c, Contact_ID__c, Affiliation_ApprovalState__r.PG_ApprovalStatus__c from Account_Affiliation__c where Contact_ID__c =:ConID and Affiliation_ApprovalState__r.PG_ApprovalStatus__c = 'Accepted' ORDER BY CreatedDate desc ];
                    System.debug('contactAffilitions:'+contactAffilitions);
                    if(contactAffilitions.size()>0){
                        Contact c = [Select ID, AccountId from Contact where Id =: ConID];
                        c.AccountId = contactAffilitions[0].Account_ID__c;
                        update c;
                    } 
                }*/
                
            JSONGenerator gen = JSON.createGenerator(true);
               gen.writeStartObject();
               gen.writeObjectField('Status','Success');
               gen.writeEndObject();
               String pretty = gen.getAsString();
            return pretty; 
                    
        }catch(Exception e){
            return e.getmessage();
        }
        return null;
    }    
}