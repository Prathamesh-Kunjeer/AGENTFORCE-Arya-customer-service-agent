public class FetchTransactionsAction {
    
    public class Input {
        @InvocableVariable(label='Customer Email' required=true)
        public String customerEmail;
        
        @InvocableVariable(label='Number of Transactions' required=false)
        public Integer transactionLimit;
        
        @InvocableVariable(label='Payment Mode (UPI/POS/Online/Net-Banking)' required=false)
        public String paymentMode;
        
        @InvocableVariable(label='Payment Type (Grocery/Fuel/Food etc.)' required=false)
        public String paymentType;
        
        @InvocableVariable(label='Start Date (YYYY-MM-DD)' required=false)
        public String startDate;
        
        @InvocableVariable(label='End Date (YYYY-MM-DD)' required=false)
        public String endDate;
        
        @InvocableVariable(label='Aggregate Total Amount' required=false)
        public Boolean aggregateTotal;
        
        @InvocableVariable(label='Send Email Statement' required=false)
        public Boolean sendEmail;
    }
    
    public class Output {
        @InvocableVariable(label='Transaction Summary')
        public String transactionSummary;
        
        @InvocableVariable(label='Success')
        public Boolean success;
    }
    
    @InvocableMethod(label='Fetch Recent Transactions' 
                     description='Fetches transactions with dynamic filters.')
    public static List<Output> fetchTransactions(List<Input> inputs) {
        List<Output> results = new List<Output>();
        
        for (Input inp : inputs) {
            Output out = new Output();
            try {
                // Step 1: Find Contact
                List<Contact> cons = [SELECT Id, Name, Email 
                                      FROM Contact 
                                      WHERE Email = :inp.customerEmail 
                                      LIMIT 1];
                if (cons.isEmpty()) {
                    out.success = false;
                    out.transactionSummary = 'No customer found with email: ' + inp.customerEmail;
                    results.add(out);
                    continue;
                }
                Contact con = cons[0];
                
                // Step 2: Find Bank Accounts
                List<Bank_Account__c> accounts = [
                    SELECT Id FROM Bank_Account__c 
                    WHERE Customer__c = :con.Id
                ];
                if (accounts.isEmpty()) {
                    out.success = false;
                    out.transactionSummary = 'No bank accounts found for this customer.';
                    results.add(out);
                    continue;
                }
                
                // Step 3: Find Cards
                List<Card__c> cards = [
                    SELECT Id FROM Card__c 
                    WHERE Bank_Account__c IN :accounts
                ];
                if (cards.isEmpty()) {
                    out.success = false;
                    out.transactionSummary = 'No cards found linked to your account.';
                    results.add(out);
                    continue;
                }
                
                // Step 4: Extract Card IDs
                List<Id> cardIds = new List<Id>();
                for (Card__c c : cards) {
                    cardIds.add(c.Id);
                }
                
                // Step 5: Fetch Transactions using static SOQL with filters in memory
                Integer limitVal = (inp.transactionLimit != null) ? inp.transactionLimit : 5;
                
                List<Transaction__c> allTxns = [
                    SELECT Id, Amount__c, Merchant__c, 
                           Transaction_Date__c, Payment_Mode__c, Payment_Type__c
                    FROM Transaction__c
                    WHERE Card_Number__c IN :cardIds
                    ORDER BY Transaction_Date__c DESC
                    LIMIT 50
                ];
                
                // Step 6: Apply filters in memory
                List<Transaction__c> filtered = new List<Transaction__c>();
                for (Transaction__c t : allTxns) {
    Boolean include = true;
    if (t.Transaction_Date__c == null) {
        filtered.add(t);
        continue;
    }

                    
                    if (String.isNotBlank(inp.paymentMode) && 
                        t.Payment_Mode__c != inp.paymentMode) {
                        include = false;
                    }
                    if (String.isNotBlank(inp.paymentType) && 
                        t.Payment_Type__c != inp.paymentType) {
                        include = false;
                    }
                    if (String.isNotBlank(inp.startDate)) {
    try {
        Date sd = Date.valueOf(inp.startDate);
        if (t.Transaction_Date__c.date() < sd) include = false;
    } catch(Exception ex) {
        // Skip invalid date
    }
}
if (String.isNotBlank(inp.endDate)) {
    try {
        Date ed = Date.valueOf(inp.endDate);
        if (t.Transaction_Date__c.date() > ed) include = false;
    } catch(Exception ex) {
        // Skip invalid date
    }
}
                    
                    if (include) filtered.add(t);
                    if (filtered.size() >= limitVal) break;
                }
                
                if (filtered.isEmpty()) {
                    out.success = false;
                    out.transactionSummary = 'No transactions found matching your criteria.';
                    results.add(out);
                    continue;
                }
                
                // Step 7: Build response
                if (inp.aggregateTotal == true) {
                    Decimal total = 0;
                    for (Transaction__c t : filtered) {
                        if (t.Amount__c != null) total += t.Amount__c;
                    }
                    out.success = true;
                    out.transactionSummary = 'Total amount spent' +
                        (String.isNotBlank(inp.paymentType) ? ' on ' + inp.paymentType : '') +
                        ' is ₹' + total.format() + '.';
                } else {
                    String summary = 'Here are your recent transactions:\n';
                    Integer i = 1;
                    for (Transaction__c t : filtered) {
                        String merchant = (t.Merchant__c != null) ? t.Merchant__c : 'Unknown';
                        String mode = (t.Payment_Mode__c != null) ? t.Payment_Mode__c : '';
                        String dateStr = (t.Transaction_Date__c != null) ? 
                 t.Transaction_Date__c.format('dd MMM yyyy') : '';

                        summary += i + '. ₹' + (t.Amount__c != null ? t.Amount__c.format() : '0') +
                                   ' - ' + merchant +
                                   ' (' + mode + ')' +
                                   ' on ' + dateStr + '\n';
                        i++;
                    }
                    out.success = true;
                    out.transactionSummary = summary;
                }
                
                // Step 8: Send email if requested
                if (inp.sendEmail == true) {
                    sendStatementEmail(con.Email, con.Name, filtered);
                }
                
            } catch (Exception e) {
                out.success = false;
                out.transactionSummary = 'Error: ' + e.getMessage();
            }
            results.add(out);
        }
        return results;
    }
    
    private static void sendStatementEmail(String email, String name, 
                                            List<Transaction__c> txns) {
        String body = 'Dear ' + name + ',\n\nYour recent transaction statement:\n\n';
        for (Transaction__c t : txns) {
            String merchant = (t.Merchant__c != null) ? t.Merchant__c : 'Unknown';
            body += '• ₹' + (t.Amount__c != null ? t.Amount__c.format() : '0') + 
                    ' - ' + merchant + 
                    ' on ' + (t.Transaction_Date__c != null ? t.Transaction_Date__c.format() : '') + '\n';
        }
        body += '\nThank you for banking with Arya Financial Services.';
        
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setToAddresses(new List<String>{email});
        mail.setSubject('Your Arya Financial Services Transaction Statement');
        mail.setPlainTextBody(body);
        Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{mail});
    }
}