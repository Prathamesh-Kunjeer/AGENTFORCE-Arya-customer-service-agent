public class BlockCardAction {
    
    public class Input {
        @InvocableVariable(label='Customer Email' required=true)
        public String customerEmail;
        
        @InvocableVariable(label='Last 4 Digits of Card' required=true)
        public String lastFourDigits;
    }
    
    public class Output {
        @InvocableVariable(label='Result Message')
        public String resultMessage;
        
        @InvocableVariable(label='Success')
        public Boolean success;
    }
    
    @InvocableMethod(label='Block Card' 
                     description='Blocks the customers credit or debit card and sends confirmation email.')
    
    public static List<Output> blockCard(List<Input> inputs) {
        List<Output> results = new List<Output>();
        
        for (Input inp : inputs) {
            Output out = new Output();
            try {
                // Find contact
                Contact con = [SELECT Id, Name, Email 
                               FROM Contact 
                               WHERE Email = :inp.customerEmail 
                               LIMIT 1];
                
                // Find the card by last 4 digits
                List<Bank_Account__c> accounts = [
                    SELECT Id FROM Bank_Account__c 
                    WHERE Customer__c = :con.Id
                ];
                
                Card__c card = [
                    SELECT Id, Card_Number__c, Card_Type__c, Status__c 
                    FROM Card__c 
                    WHERE Bank_Account__c IN :accounts 
                    AND Card_Number__c LIKE :('%' + inp.lastFourDigits)
                    AND Status__c = 'Active'
                    LIMIT 1
                ];
                
                // Block the card
                card.Status__c = 'Blocked';
                update card;
                
                // Send confirmation email
                String body = 'Dear ' + con.Name + ',\n\n' +
                    'Your ' + card.Card_Type__c + ' card ending ' + 
                    inp.lastFourDigits + ' has been successfully blocked.\n\n' +
                    'If you did not request this, please contact us immediately.\n\n' +
                    'Thank you,\nArya Financial Services';
                
                Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                mail.setToAddresses(new List<String>{con.Email});
                mail.setSubject('Card Blocking Confirmation - Arya Financial Services');
                mail.setPlainTextBody(body);
                Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{mail});
                
                out.success = true;
                out.resultMessage = 'Your ' + card.Card_Type__c + 
                                    ' card ending ' + inp.lastFourDigits + 
                                    ' has been successfully blocked. A confirmation email has been sent to ' + 
                                    con.Email + '.';
                                    
            } catch (QueryException e) {
                out.success = false;
                out.resultMessage = 'No active card ending ' + inp.lastFourDigits + 
                                    ' was found on your account.';
            } catch (Exception e) {
                out.success = false;
                out.resultMessage = 'Unable to block card. Please try again or contact support.';
            }
            results.add(out);
        }
        return results;
    }
}