@RestResource(URLmapping='/Pharmacycom/v1/AffiliationService/*')
global class BusinessAffiliation 
{
    global static final String  REQUIRED = 'PC0033';
    global static final String  ACTION_PARAMETER = 'PC0034';
    global static final String  GENERIC_ERROR = 'GEN0001';  
    global static final String  ERROR_TYPE ='Affiliation' ;
    global static final String  LAST_AFFILIATION = 'PC0035';
    global static final String  MANAGER_NOT_EXIST = 'PC0011';
    global static final String  MANAGER_EXIST = 'PC0046';
    global static final String  OWNER_EXIST = 'PC0054';
    global static final string  BUYER_EXIST = 'PC0057';
    
    @HTTPGET
    global static string  getaffiliations()
    {
        RestRequest req  = RestContext.request;
        RestResponse res = RestContext.response;
        List<Account_Affiliation__c> accaffiliationlst = new List<Account_Affiliation__c>();
        List<accaffiliation> Affiliations= new list<accaffiliation>();
        string userid= req.requestURI.substring(req.requestURI.lastIndexOf('/')+1);
        system.debug('Userid::'+userid);
        if(userid==null || userid=='')
        {
            system.debug('USERID::'+userinfo.getUserId());
            userid=userinfo.getUserId();
        }
        User u=[Select id,Contactid,Accountid from user where id=:userid ];
        accaffiliationlst=[Select id,Account_ID__c,Contact_ID__c,Approvalstate__C,Account_ID__r.Name,Account_ID__r.PG_PharmacyRegistrationNumber__c,Account_ID__r.Partner_Numbers__c, Account_ID__r.PG_JnJCustomerCode__c, Account_ID__r.VAT_Number__c, Account_ID__r.PG_Account__c, Account_ID__r.BillingStreet,
                                    Account_ID__r.BillingCity, Account_ID__r.PG_SoldTo__c,Account_ID__r.BillingPostalCode,Account_ID__r.ShippingStreet,Account_ID__r.ShippingCity,Account_ID__r.ShippingPostalCode,Account_ID__r.Fax,Account_ID__r.Phone,Account_ID__r.E_Commerce_Eligibility__c,Affiliation_ApprovalState__r.PG_ApprovalStatus__c,
                            (select id, PG_FunctionalityAccessPerSubRole__c,PG_FunctionalityAccessPerSubRole__r.PG_Functionality__r.Name 
                                from Affiliation_Functions__r),isPrimary__c,Account_ID__r.HQ_Account__c,Account_ID__r.Parent.id 
                             from Account_Affiliation__c 
                             where Contact_ID__c =:u.ContactId ];
        for(Account_Affiliation__c af:accaffiliationlst)
        {
            List<AccAffilitionFunction> AffiliationFunctionslst =new List<AccAffilitionFunction>();
            system.debug('AAA@@:'+af.Affiliation_Functions__r);
            if(af.Affiliation_Functions__r.size()!=0)
            {
                for(Affiliation_Function__c aff:af.Affiliation_Functions__r)
                {
                    
                    AccAffilitionFunction afunction =new AccAffilitionFunction(aff.PG_FunctionalityAccessPerSubRole__r.PG_Functionality__r.Name ,aff.id); 
                    AffiliationFunctionslst.add(afunction);
                }
            } 
            system.debug('lstuser:'+AffiliationFunctionslst);
            AccAffiliation Affiliation = new AccAffiliation(); 
            Affiliation.AffiliationId = af.id;
            Affiliation.PharmacyName = af.Account_ID__r.Name;
            Affiliation.Pharmacyid = af.Account_ID__c;
            Affiliation.ContactID = af.Contact_ID__c;
            Affiliation.IsPrimary = af.isPrimary__c;
            Affiliation.Approvalstatus = af.Affiliation_ApprovalState__r.PG_ApprovalStatus__c;
            Affiliation.VATNumber = af.Account_ID__r.VAT_Number__c;
            Affiliation.BillTONumbers = af.Account_ID__r.Partner_Numbers__c;
            Affiliation.APB = af.Account_ID__r.PG_PharmacyRegistrationNumber__c;
            Affiliation.StreetAddress = af.Account_ID__r.BillingStreet;
            Affiliation.City = af.Account_ID__r.Billingcity;
            Affiliation.PostalCode = af.Account_ID__r.BillingPostalcode;
            Affiliation.ShippingStreetAddress = af.Account_ID__r.ShippingStreet;
            Affiliation.ShippingCity = af.Account_ID__r.ShippingCity;
            Affiliation.ShippingPostalCode = af.Account_ID__r.ShippingPostalCode;
            Affiliation.Phone = af.Account_ID__r.Phone;
            Affiliation.Fax = af.Account_ID__r.Fax;
            Affiliation.Functions = AffiliationFunctionslst;
            Affiliation.SoldTo = af.Account_ID__r.PG_SoldTo__c;
            Affiliation.IsPGAccount = af.Account_ID__r.PG_Account__c;
            Affiliation.EComm_Eligible = af.Account_ID__r.E_Commerce_Eligibility__c;
            Affiliation.IsHeadOfChain = af.Account_ID__r.HQ_Account__c;
            Affiliation.ChainHeadID=af.Account_ID__r.Parent.id;
            Affiliations.add(Affiliation);
            
        }
        return json.serialize(Affiliations);
        
    }
    @HTTPPOST
    global static string updateAffiliations()
    {
        RestRequest req  = RestContext.request;
        RestResponse res = RestContext.response;
        Savepoint sp = Database.setSavepoint();
        try
        {
            Blob body =req.requestbody;
            updateAffiliations lstAffiliation = (updateAffiliations)JSON.deserialize(body.tostring(),updateAffiliations.class);
            System.debug('lstAffiliation'+ lstAffiliation);
            
            List<Account_Affiliation__c> insertAffiliation = new List<Account_Affiliation__c>();
            List<Account_Affiliation__c> deleteAffiliation = new List<Account_Affiliation__c>();
            
            Map<String,Account_Affiliation__c> verifyAffiliation = new Map<String,Account_Affiliation__c>();
            Map<String,List<Affiliation_Function__c>> verifyAffiliationFunction = new Map<String,List<Affiliation_Function__c>>();
            Map<String,PG_FunctionalityAccessPerSubRole__c> mapFunAccessPerRole =  New Map<String,PG_FunctionalityAccessPerSubRole__c>();
            List<ManageAffiliation> affiliationslst = lstAffiliation.Affiliations;
            //System.debug('affiliationslst'+ affiliationslst);
            
            /*** Get the contacts and its affiliation ***/
            Set<ID> contactIds = new Set<ID>();
            Set<ID> AccID = new Set<ID>();
            //Set<ID> ConIDs = new Set<ID>();
            Set<ID> subroleIDs = new Set<ID>();
            Map<ID,ID> mapContactrole = new Map<ID,ID>();
            Map<ID,boolean> isManagerAcc = new Map<ID,Boolean>();
            Map<ID,boolean> isBuyerAcc = new Map<ID,Boolean>();
            Map<ID,boolean> isManagerCon = new Map<ID,Boolean>();
            Map<ID,boolean> isOwnerAcc = new Map<ID,Boolean>();
            Map<ID,String> isManagerorOwner = new Map<ID,String>();
            for(ManageAffiliation mf: affiliationslst){
                if(mf.ContactId != null) contactIds.add(mf.ContactId);
                if(mf.PharmacyId != null) AccID.add(mf.PharmacyId);
            }
            map<id,Account>afaccount =new map<id,Account>([select id,name,pg_Account__c,billingcountry from Account where id IN : AccID]); 
            List<Contact> lstCons = [Select ID, Email, AccountID, (Select Contact__c, PG_SubRole__r.role__c, PG_Subrole__r.ManagerActive__c From Users__r) from Contact where ID IN: contactIds];
            for(Contact co : lstCons) {
                isManagerorOwner.put(co.Id,co.Users__r[0].PG_SubRole__r.role__c);
                
                if(co.Users__r[0].PG_SubRole__r.role__c == 'Manager' || co.Users__r[0].PG_SubRole__r.role__c == 'Owner' || co.Users__r[0].PG_SubRole__r.role__c=='Buyer') {
                    isManagerCon.put(co.Id,true);
                }
            }
             Account acc = [Select Id,Name from Account where Id='0015E00000B9BNYQA3'];
             
            List<Contact> lstContacts = [Select ID, Email, AccountID, (Select Contact__c, PG_SubRole__r.role__c From Users__r), (select Account_ID__c from Account_Affiliations__r where Account_ID__c IN :AccID) from Contact where Id in (select Contact_ID__c from Account_Affiliation__c where Account_ID__c IN :AccID)];
            for(Contact c: lstContacts){
                if (c.Users__r[0].PG_SubRole__r.role__c == 'Manager') {
                    for(Account_Affiliation__c aff: c.Account_Affiliations__r) {
                        isManagerAcc.put(aff.Account_ID__c, true);
                    }
                }else if(c.Users__r[0].PG_SubRole__r.role__c == 'Owner')
                    {
                        for(Account_Affiliation__c aff: c.Account_Affiliations__r) 
                        {
                            isOwnerAcc.put(aff.Account_ID__c, true);
                        }                   
                    }
                    else
                    {
                        if(c.Users__r[0].PG_SubRole__r.role__c == 'Buyer')
                        {
                            for(Account_Affiliation__c aff: c.Account_Affiliations__r) 
                            {
                                isBuyerAcc.put(aff.Account_ID__c, true);
                            } 
                        }
                    }
            }

            
            List<User> lstUser = [select Id, ContactID, PG_SubRole__c, LocaleSidKey from user where ContactID in: contactIds];
            Set<String> localSidKeySet = new Set<String>();
            
            for(User u :lstUser){
                subroleIDs.add(u.PG_SubRole__c);
                mapContactrole.put(u.ContactID,u.PG_SubRole__c);
                localSidKeySet.add(u.LocaleSidKey);
            }
            
            // Query Functions that are access to users
            List<PG_FunctionalityAccessPerSubRole__c> funAccess = [select id,PG_SubRole__c, 
                                                                            PG_Functionality__c, 
                                                                            PG_Functionality__r.Name, 
                                                                            hasAccess__c,
                                                                            PG_CountryLanguage__r.Name 
                                                                    from PG_FunctionalityAccessPerSubRole__c 
                                                                    where PG_SubRole__c in:subroleIDs and hasAccess__c = true and PG_CountryLanguage__r.Name IN :localSidKeySet];
            Map<ID,Map<ID,List<String>>> mapFunctions = new Map<ID,Map<ID,List<String>>>();
            Map<ID,List<String>> subroleFunc = new Map<Id,List<String>>();
            
            for(PG_FunctionalityAccessPerSubRole__c roleaccess : funAccess){
                List<String> StrFunction = New List<String>();
                mapFunAccessPerRole.put(String.valueOf(roleaccess.PG_SubRole__c)+roleaccess.PG_Functionality__r.Name,roleaccess);
                for(PG_FunctionalityAccessPerSubRole__c ff : funAccess){
                    if(roleaccess.PG_SubRole__c == ff.PG_SubRole__c){
                        StrFunction.add(ff.PG_Functionality__r.Name);
                    }
                }
                subroleFunc.put(roleaccess.PG_SubRole__c,StrFunction);
            }
            
            // Query affiliaions to verify affiliaion with the different pharmacies AND FUNCTIONS
            Map<String,Boolean>  mapFunctionsAccess = new Map<String,boolean>();
            List<Account_Affiliation__c> lstAff = [Select id,
                                                     Account_ID__c,
                                                     Contact_ID__c, 
                                                     isPrimary__c,
                                                    (select id, Account_Affiliation__c,
                                                                PG_FunctionalityAccessPerSubRole__c,
                                                                PG_FunctionalityAccessPerSubRole__r.PG_Functionality__r.Name,
                                                                PG_FunctionalityAccessPerSubRole__r.hasAccess__c
                                                     from Affiliation_Functions__r) 
                                                  from Account_Affiliation__c 
                                                  where Contact_ID__c IN :contactIds];
            if(lstAff.size()>0){
                for(Account_Affiliation__c af: lstAff){
                    system.debug('Account: ' + af.Account_ID__c + '; Contact: ' + af.Contact_ID__c + '; af:' + af);
                    verifyAffiliation.put(String.valueof(af.Account_ID__c)+String.valueof(af.Contact_ID__c),af);
                    if(af.Affiliation_Functions__r.size()>0){
                        List<Affiliation_Function__c> lstAFFn = new List<Affiliation_Function__c>();
                        for(Affiliation_Function__c aff : af.Affiliation_Functions__r){
                            lstAFFn.add(aff);
                        }
                        verifyAffiliationFunction.put(String.valueof(af.Account_ID__c)+String.valueof(af.Contact_ID__c),lstAFFn);
                    }
                }
            }
            
            /*** validate and insert/remove affiliaion based on action ***/
            Map<String,List<String>> insertAffiliationFunction = new Map<String,List<String>>();
            Map<String,List<String>> insertextAffiliationFunction = new Map<String,List<String>>();
            Map<String,List<String>> deleteAffiliationFunction = new Map<String,List<String>>();
            System.debug('#####OUTPUT>>> affiliationslst >>> :'+affiliationslst);
            System.debug('#####OUTPUT>>> verifyAffiliation >>> :'+verifyAffiliation);
            
            for(ManageAffiliation mf: affiliationslst){
                if(mf.Pharmacyid==null || mf.ContactID==null)
                {
                    throw new customexception(PG_Utils.getException(REQUIRED,ERROR_TYPE,CustomException__c.getValues(REQUIRED).Error_Description__c));
                }
                if(mf.action=='' || mf.action==null )
                {
                    throw new customexception(PG_Utils.getException(ACTION_PARAMETER,ERROR_TYPE,CustomException__c.getValues(ACTION_PARAMETER).Error_Description__c));
                }
                if(mf.action == 'add'){
                    system.debug('mf.PharmacyId: ' + mf.PharmacyId + '; mf.ContactId: ' + mf.ContactId + '; action: add');
                    // check affiliation is exist, if not insert new affiliion else insert only funtions needed.
                    if(!verifyAffiliation.containsKey(String.valueOf(mf.PharmacyId)+String.valueOf(mf.ContactId))) {
                        /* Create Affiliation approval*/
                        Boolean Mactive;
                        System.debug('contact manager?'+isManagerCon.containsKey(mf.ContactId));
                        // Check the subrole manageractive for the given contactids
                        for(Contact cs:lstCons){
                            for(PG_ContactUser__c pg:cs.Users__r){
                                if(pg.PG_SubRole__r.ManagerActive__c == true){
                                     Mactive = true;
                                }else{
                                    Mactive = false;
                                }
                            }
                        }
                                                
                        Account_Affiliation__c af = new Account_Affiliation__c();
                        if(isManagerCon.containsKey(mf.ContactId))
                        {
                            String rolename = isManagerorOwner.get(mf.ContactId);
                            if(rolename == 'Manager'){
                                System.debug('contact manager?'+isManagerAcc);
                                System.debug('mf.PharmacyId?'+mf.PharmacyId);
                                if(isManagerAcc.containsKey(mf.PharmacyId)){
                                    throw new customexception(PG_Utils.getException(MANAGER_EXIST,ERROR_TYPE,CustomException__c.getValues('PC0046').Error_Description__c));
                                }else{
                                    af.Account_ID__c = mf.PharmacyId;
                                    af.Contact_ID__c = mf.ContactId;
                                    insertAffiliation.add(af);
                                }                               
                            }
                            else if(rolename == 'Owner')
                                {
                                    if(isOwnerAcc.containsKey(mf.PharmacyId)){
                                        throw new customexception(PG_Utils.getException(OWNER_EXIST,ERROR_TYPE,CustomException__c.getValues('PC0054').Error_Description__c));
                                    }else{
                                        af.Account_ID__c = mf.PharmacyId;
                                        af.Contact_ID__c = mf.ContactId;
                                        insertAffiliation.add(af);
                                    }                               
                                }
                                else
                                {
                                    if(rolename=='Buyer')
                                    {
                                        if(isBuyerAcc.containsKey(mf.PharmacyId)){
                                            throw new customexception(PG_Utils.getException(BUYER_EXIST,ERROR_TYPE,CustomException__c.getValues('PC0057').Error_Description__c));
                                        }else{
                                             af.Account_ID__c = mf.PharmacyId;
                                            af.Contact_ID__c = mf.ContactId;
                                            insertAffiliation.add(af);
                                        }
                                    }
                                }
                            
                        }else{
                            System.debug('ManagerAcc###'+isManagerAcc);
                            System.debug('MActive@@@'+Mactive);
                             if(((isManagerAcc.containsKey(mf.PharmacyId) || isOwnerAcc.containsKey(mf.PharmacyId)) && Mactive == true) || ((isManagerAcc.containsKey(mf.PharmacyId) || isOwnerAcc.containsKey(mf.PharmacyId)) && Mactive == false)){
                                af.Account_ID__c = mf.PharmacyId;
                                af.Contact_ID__c = mf.ContactId;
                                insertAffiliation.add(af);
                            }else if(!(isManagerAcc.containsKey(mf.PharmacyId) || isOwnerAcc.containsKey(mf.PharmacyId)) && Mactive == false){
                                af.Account_ID__c = mf.PharmacyId;
                                af.Contact_ID__c = mf.ContactId;
                                insertAffiliation.add(af);
                            }
                            else
                                throw new customexception(PG_Utils.getException(REQUIRED,ERROR_TYPE,CustomException__c.getValues(MANAGER_NOT_EXIST).Error_Description__c));
                        }
                        System.debug('#####OUTPUT>>> mf.Functions >>> :'+mf.Functions);
                        if(mf.Functions != null){
                            List<String> lstString = new List<String>();
                            for(Function f : mf.Functions){
                                if(f.Action == 'add') lstString.add(f.Name);
                            }
                            insertAffiliationFunction.put(String.valueOf(mf.PharmacyId)+String.valueOf(mf.ContactId),lstString);
                        }
                    }else if(verifyAffiliation.containsKey(String.valueOf(mf.PharmacyId)+String.valueOf(mf.ContactId))){
                        if(mf.Functions != null){
                            List<String> addFunctions = new List<String>();
                            List<String> removeFunctions = new List<String>();
                            for(Function f : mf.Functions){
                                if(f.Action == 'add') addFunctions.add(f.Name);
                                if(f.Action == 'remove') removeFunctions.add(f.Name);
                            }
                            if(addFunctions.size() > 0) insertextAffiliationFunction.put(String.valueOf(mf.PharmacyId)+String.valueOf(mf.ContactId),addFunctions);
                            if(removeFunctions.size() > 0) deleteAffiliationFunction.put(String.valueOf(mf.PharmacyId)+String.valueOf(mf.ContactId),removeFunctions);
                        }                       
                    }
                }else if(mf.action == 'remove'){
                    system.debug('mf.PharmacyId: ' + mf.PharmacyId + '; mf.ContactId: ' + mf.ContactId + '; action: remove');
                    if(verifyAffiliation.containsKey(String.valueOf(mf.PharmacyId)+String.valueOf(mf.ContactId))) {
                        Account_Affiliation__c af = verifyAffiliation.get(String.valueOf(mf.PharmacyId)+String.valueOf(mf.ContactId));
                        if(!af.isPrimary__c) {
                            deleteAffiliation.add(verifyAffiliation.get(String.valueOf(mf.PharmacyId)+String.valueOf(mf.ContactId)));
                        }
                        else{
                            throw new customexception(PG_Utils.getException(LAST_AFFILIATION,ERROR_TYPE,CustomException__c.getValues(LAST_AFFILIATION).Error_Description__c));
                        } 
                    }else{
                        // throw error, no affiliation found
                    }                   
                }
            }
            /*** insert funcion for new created affiliation***/ 
            List<Affiliation_Function__c> insertFunction = new List<Affiliation_Function__c>();
            if(insertAffiliation.size()>0){
                 insert insertAffiliation;
                 System.debug('#####OUTPUT>>> insertAffiliation >>> :'+insertAffiliation);
                 //insert affiliation functions for newly created affiliations
                 System.debug('#####OUTPUT>>> insertAffiliationFunction >>> :'+insertAffiliationFunction);
                
                 for(Account_Affiliation__c a : insertAffiliation){
                    System.debug('#####OUTPUT>>> Key >>> :'+a.Account_ID__c+':='+a.Contact_ID__c);
                    List<String> func = insertAffiliationFunction.get(String.valueof(a.Account_ID__c)+String.valueof(a.Contact_ID__c));
                    System.debug('#####OUTPUT>>> func >>> :'+func);
                    if(func != null){
                        for(String s :func){
                            if(mapContactrole.ContainsKey(a.Contact_ID__c))
                            {
                                ID subroleID = mapContactrole.get(a.Contact_ID__c);
                                System.debug('#####OUTPUT>>> subroleID >>> :'+subroleID);
                                System.debug('#####OUTPUT>>> subroleFunc >>> :'+subroleFunc);
                                List<String> funNames = subroleFunc.get(subroleID);
                                System.debug('#####OUTPUT>>> funNames >>> :'+funNames); 
                                for(String ss :funNames){
                                    System.debug('#####OUTPUT>>> s >>> :'+s);
                                    if(s == ss){
                                        System.debug('#####OUTPUT>>> ss >>> :'+ss);
                                        Affiliation_Function__c funs = new Affiliation_Function__c();
                                        funs.Account_Affiliation__c = a.id;
                                        PG_FunctionalityAccessPerSubRole__c p = mapFunAccessPerRole.get(subroleID+ss);
                                        funs.PG_FunctionalityAccessPerSubRole__c = p.Id;
                                        insertFunction.add(funs);
                                    }
                                }
                            }
                        }
                    }
                 }
            }
            /*** insert functions for existing affiliaion ***/
            System.debug('#####OUTPUT>>> insertextAffiliationFunction >>> :'+insertextAffiliationFunction); 
            if(insertextAffiliationFunction.size() >0){
                for(String s :insertextAffiliationFunction.keyset()){
                    system.debug('s: ' + s);
                    List<String> NewFunction = insertextAffiliationFunction.get(s);
                    List<Affiliation_Function__c> afflst = verifyAffiliationFunction.get(s);
                    if(NewFunction != null){
                        System.debug('#####OUTPUT>>> NewFunction >>> :'+NewFunction); 
                        for(String newfun : NewFunction){
                            if(afflst != null){
                                System.debug('#####OUTPUT>>> afflst >>> :'+afflst); 
                                Map<String,String> strmap = new Map<String,String>();
                                for(Affiliation_Function__c af :afflst){
                                    strmap.put(af.PG_FunctionalityAccessPerSubRole__r.PG_Functionality__r.Name,af.PG_FunctionalityAccessPerSubRole__r.PG_Functionality__r.Name);
                                }
                                System.debug('#####OUTPUT>>> strmap >>> :'+strmap); 
                                System.debug('#####OUTPUT>>> newfun >>> :'+newfun);
                                if(!strmap.containsKey(newfun)){
                                    Affiliation_Function__c funs = new Affiliation_Function__c();
                                    Account_Affiliation__c vaf = verifyAffiliation.get(s);
                                    funs.Account_Affiliation__c = vaf.Id;
                                    String subroleID = String.valueof(mapContactrole.get(vaf.Contact_ID__c));
                                    PG_FunctionalityAccessPerSubRole__c p = mapFunAccessPerRole.get(subroleID+newfun);
                                    System.debug('#####OUTPUT>>> p >>> :'+p); 
                                    if(p != null){
                                        funs.PG_FunctionalityAccessPerSubRole__c = p.Id;
                                        insertFunction.add(funs);
                                    }
                                    System.debug('#####OUTPUT>>> insertFunction >>> :'+insertFunction); 
                                }
                            }else{
                                Affiliation_Function__c funs = new Affiliation_Function__c();
                                Account_Affiliation__c vaf = verifyAffiliation.get(s);
                                funs.Account_Affiliation__c = vaf.Id;
                                String subroleID = String.valueof(mapContactrole.get(vaf.Contact_ID__c));
                                PG_FunctionalityAccessPerSubRole__c p = mapFunAccessPerRole.get(subroleID+newfun);
                                system.debug('newfun: ' + newfun);
                                system.debug('subroleID: ' + subroleID);
                                system.debug('mapFunAccessPerRole: ' + mapFunAccessPerRole);
                                system.debug('');
                                funs.PG_FunctionalityAccessPerSubRole__c = p.Id;
                                insertFunction.add(funs);
                            }
                        }
                    }
                }
            }
            /*** Delete functios for the user ***/
            List<Affiliation_Function__c> AffiliationFunctiontoDelete = new List<Affiliation_Function__c> ();
            if(deleteAffiliationFunction.size() >0){
                for(String s :deleteAffiliationFunction.KeySet()){
                    List<String> delFunction = deleteAffiliationFunction.get(s);
                    List<Affiliation_Function__c> lstaffiliations = verifyAffiliationFunction.get(s);
                    System.debug('#####OUTPUT>>> delFunction >>> :'+delFunction); 
                    System.debug('#####OUTPUT>>> lstaffiliations >>> :'+lstaffiliations); 
                    for(String sdf :delfunction){
                        Map<String,Affiliation_Function__c> strFunc = new Map<String,Affiliation_Function__c>();
                        for(Affiliation_Function__c daf : lstaffiliations){
                            if(sdf == daf.PG_FunctionalityAccessPerSubRole__r.PG_Functionality__r.Name)
                                AffiliationFunctiontoDelete.add(daf);
                        }
                    }
                    
                    System.debug('#####OUTPUT>>> AffiliationFunctiontoDelete >>> :'+AffiliationFunctiontoDelete); 
                }
            }
            System.debug('#####OUTPUT>>> insertFunction >>> :'+insertFunction); 
            System.debug('#####OUTPUT>>> AffiliationFunctiontoDelete >>> :'+AffiliationFunctiontoDelete);
            System.debug('#####OUTPUT>>> deleteAffiliation >>> :'+deleteAffiliation);
            if(insertFunction.size()>0) insert insertFunction;
            if(AffiliationFunctiontoDelete.size() >0) delete AffiliationFunctiontoDelete;
            if(deleteAffiliation.size()>0) delete deleteAffiliation;
            JSONGenerator gen = JSON.createGenerator(true);
               gen.writeStartObject();
               gen.writeObjectField('Status','Success');
               gen.writeEndObject();
               String pretty = gen.getAsString();
               /* The line below creates and maintains approval(PG_ContactApprovalstatus__c) 
                  for pharmacies which user had affiliated by them self or added my manager*/ 
               if(insertAffiliation.size()>0){ AffiliationApproval.createApproval(insertAffiliation); }
            return pretty;
        }
        catch(Exception e)
        {
            Database.rollback(sp);
            return e.getmessage();
           // throw e;
        }
        
        return '';
    }
    /**DTO to return array of affiliations and affiliation functions for the logged in user**/
    global class AccAffiliation
    {
        Id AffiliationId{get;set;}
        String PharmacyName{get;set;}
        Id Pharmacyid{get;set;}
        String ContactID{get;set;}
        Boolean IsPrimary{get;set;}
        String Approvalstatus{get;set;}
        String VATNumber{get;set;}
        String BillTONumbers{get;set;}
        String APB{get;set;}
        String StreetAddress {get;set;}
        String City {get;set;}
        String PostalCode {get;set;}
        string ShippingStreetAddress{get;set;}
        string ShippingCity{get;set;}
        string ShippingPostalCode{get;set;}
        String Phone {get;set;}
        String Fax {get;set;}
        String SoldTo{get;set;}
        Boolean IsPGAccount{get;set;}
        String EComm_Eligible {get;set;}
        boolean IsHeadOfChain{get;set;}
        string  ChainHeadID{get;set;}
        list<AccAffilitionFunction> Functions{get;set;} 
        global AccAffiliation(){}
    }
    global class AccAffilitionFunction
    {
        string Name{get;set;}
        Id id {get;set;}
        global AccAffilitionFunction(string name,Id id)
        {
            this.Name=name;
            this.id=id;
            
        }
    }
    global class ManageAffiliation
    {
        String action {get;set;}
        Id AffiliationId {get;set;}
        Id PharmacyId {get;set;}
        Id ContactId {get;set;}
        Boolean isPrimary {get;set;}
        list<Function> Functions {get;set;} 
        
    }
    global class Function
    {
        String Name{get;set;}
        Id Id {get;set;}
        String Action{get;set;}
        global Function(string Name,string Id,string action)
        {
            this.Name=name;
            this.Id=id;
            this.Action=action;
            
        }
    }
    global class updateAffiliations
    {
        Id UserId{get;set;}
        List<ManageAffiliation> Affiliations{get;set;}
    }
    
    @HTTPPUT
    global static string approveAffiliations()
    {
        RestRequest req  = RestContext.request;
        RestResponse res = RestContext.response;
        Savepoint sp = Database.setSavepoint();
        Blob body =req.requestbody;
        System.debug('lstAffiliation'+ body.tostring()); 
        AffiliationsApproval lstAffiliation = (AffiliationsApproval)JSON.deserialize(body.tostring(),AffiliationsApproval.class);
        System.debug('lstAffiliation'+ lstAffiliation);        
        try{
            ID userid;
            if(lstAffiliation.UserId != null && lstAffiliation.UserId != ''){
                userid = lstAffiliation.UserId;
            }else{
                userid = userinfo.getUserId();
            }
            User u = [Select Id, PG_UserType__c,LanguageLocalekey,Localesidkey from User where ID =:userid];
            Set<ID> affiliationId = New Set<ID>();
            Set<ID> CASId = New Set<ID>();
            Set<ID> conid = new Set<ID>();
            Boolean mvalue;
            List<PG_ContactApprovalStatus__c> updateApprovals = new List<PG_ContactApprovalStatus__c>();
            Map<ID,ID> mpAffiliation = new Map<ID,ID>();
            List<Account_Affiliation__c> delaff = new List<Account_Affiliation__c>();
            Map<ID,Account_Affiliation__c> mpAff = new Map<ID,Account_Affiliation__c>();
            Map<ID,PG_ContactUser__c>conuser =  new map<ID,PG_ContactUser__c>();
            Map<String, Customer_Service_Settings__c> css = Customer_Service_Settings__c.getall();
            Customer_Service_Settings__c concs = css.get(u.LocaleSidKey);
            List<approveAffiliation> lstApprovals = lstAffiliation.Approvals;
            for(approveAffiliation app :lstApprovals){
                affiliationId.add(app.AffiliationId);
            }
            List<Account_Affiliation__c> lstaff = [Select Id, Account_ID__c, Contact_ID__c, Affiliation_ApprovalState__c from Account_Affiliation__c Where ID IN:affiliationId];
            
            for(Account_Affiliation__c af :lstaff){
                CASId.add(af.Affiliation_ApprovalState__c);
                mpAffiliation.put(af.ID,af.Affiliation_ApprovalState__c);
                mpAff.put(af.Id,af);
                conid.add(af.Contact_ID__c);
            }
            Map<ID,PG_ContactApprovalStatus__c> cas = New Map<ID,PG_ContactApprovalStatus__c>([Select id, Account_ID__c, Contact_ID__c, PG_ApprovalStatus__c,(Select ID, Account_ID__c, Contact_ID__c, isPrimary__c, ApprovalState__c From Account_Affiliations__r) from PG_ContactApprovalStatus__c where Id IN:CASId]);
            List<Contact> lstcon = [Select Id, (Select Contact__c, PG_SubRole__r.role__c, PG_Subrole__r.ManagerActive__c,PG_Subrole__r.ApprovalPharmacist__c,PG_Subrole__r.ApprovalSalesRep__c,PG_Subrole__r.Approval_CustomerService__c From Users__r) from Contact where Id IN:conid];             
            for(Contact con:lstcon){
            	conuser.put(con.id,con.Users__r[0]);
                if(con.Users__r[0].PG_SubRole__r.role__c == 'Manager' ||  con.Users__r[0].PG_SubRole__r.role__c == 'Owner' || con.Users__r[0].PG_SubRole__r.role__c == 'Buyer'){
                    System.debug('Mvalue####');
                    mvalue = true;
                }else{
                    System.debug('Mvalue*****');
                    mvalue = false;
                }   
            }
            
            for(approveAffiliation app :lstApprovals){
                PG_ContactApprovalStatus__c ConAPPStatus = cas.get(mpAffiliation.get(app.AffiliationId));
                Account_Affiliation__c affiliation = mpAff.get(app.AffiliationId);
                if(app.action == 'Approve'){
                    System.debug('ApprovalFlow##'+ConAPPStatus);
                    System.debug('Inside else salesrep approval'+u);
                    if(u.PG_UserType__c == 'External'){
                        if(ConAPPStatus.PG_ApprovalStatus__c == 'Rejected'){
                            throw new customexception(PG_Utils.getException('PC0047',ERROR_TYPE,CustomException__c.getValues('PC0047').Error_Description__c)); 
                        }else{
                            
                            if(u.Localesidkey == concs.Name){
                            	PG_ContactUser__c appus = conuser.get(ConAPPStatus.Contact_ID__c);
                            	if(appus.PG_Subrole__r.ApprovalSalesRep__c)
                            	{
                            		ConAPPStatus.PG_ApprovalStatus__c = 'AwaitingSalesRepApproval';
                            		updateApprovals.add(ConAPPStatus);
                            	}
                            	else
                                	ConAPPStatus.PG_ApprovalStatus__c = 'Accepted';
                                	System.debug('Inside else salesrep approval');
                            }else{
                                ConAPPStatus.PG_ApprovalStatus__c = 'AwaitingSalesRepApproval';
                            }
                        }
                    }
                    else if(u.PG_UserType__c == 'Internal'){
                        //ConAPPStatus.PG_ApprovalStatus__c = 'Accepted';
                        AffiliationApproval.ApproveReject(u.Id,ConAPPStatus.Id,'Approve');
                        
                    }
                }else if(app.action == 'Reject'){
                    //ConAPPStatus.PG_ApprovalStatus__c = 'Rejected';
                    if(mvalue == true){
                        System.debug('ManagerRecord@@@@');
                        delaff.add(affiliation);
                       if(u.PG_UserType__c != 'Internal')ConAPPStatus.PG_ApprovalStatus__c = 'Rejected';
                    }else{
                        System.debug('UserRecord@@@@');
                        ConAPPStatus.PG_ApprovalStatus__c = 'Rejected';
                    }
                }
                 if(ConAPPStatus.PG_ApprovalStatus__c== 'Accepted' || ConAPPStatus.PG_ApprovalStatus__c =='Rejected')updateApprovals.add(ConAPPStatus);
            }           
            System.debug('updateApprovals>>>>'+updateApprovals);
            //if(u.PG_UserType__c != 'Internal') update updateApprovals;
            //Code Update on 10MAR17
            if(updateApprovals.size()>0) update updateApprovals;
            if(delaff.size()>0){
                delete delaff;
            }
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
    
    global class approveAffiliation
    {
        String action {get;set;}
        Id AffiliationId {get;set;}
        Id PharmacyId {get;set;}
        Id ContactId {get;set;}
    } 
    global class AffiliationsApproval
    {
        String UserId{get;set;}
        List<approveAffiliation> Approvals{get;set;}
    }
}