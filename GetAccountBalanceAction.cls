public class GetAccountBalanceAction {
    
    public class Input {
        @InvocableVariable(label='Customer Email' required=true)
        public String customerEmail;
        
        @InvocableVariable(label='Last 4 Digits of Account Number' required=false)
        public String lastFourDigits;
    }
    
    public class Output {
        @InvocableVariable(label='Account Balance')
        public String balanceMessage;
        
        @InvocableVariable(label='Success')
        public Boolean success;
    }
    
    @InvocableMethod(label='Get Account Balance' 
                     description='Fetches account balance for a customer using their email address.')
    
    public static List<Output> getBalance(List<Input> inputs) {
        List<Output> results = new List<Output>();
        
        for (Input inp : inputs) {
            Output out = new Output();
            try {
                // Find contact by email
                Contact con = [SELECT Id, Name 
                               FROM Contact 
                               WHERE Email = :inp.customerEmail 
                               LIMIT 1];
                
                // Query bank accounts for this contact
                List<Bank_Account__c> accounts = [
                    SELECT Account_Number__c, Account_Type__c, Balance__c 
                    FROM Bank_Account__c 
                    WHERE Customer__c = :con.Id
                ];
                
                if (accounts.isEmpty()) {
                    out.success = false;
                    out.balanceMessage = 'No bank accounts found for the entered customer email address.';
                } else {
                    // Filter by last 4 digits if provided
                    Bank_Account__c matched = null;
                    for (Bank_Account__c acc : accounts) {
                        if (inp.lastFourDigits != null && 
                            acc.Account_Number__c.right(4) == inp.lastFourDigits) {
                            matched = acc;
                            break;
                        }
                    }
                    if (matched == null) matched = accounts[0];
                    
                    out.success = true;
                    out.balanceMessage = 'Your ' + matched.Account_Type__c + 
                                        ' account ending ' + 
                                        matched.Account_Number__c.right(4) + 
                                        ' has a current balance of ₹' + 
                                        matched.Balance__c.format() + '.';
                }
            } catch (Exception e) {
                out.success = false;
                out.balanceMessage = 'Unable to retrieve balance. Please try again.';
            }
            results.add(out);
        }
        return results;
    }
}