public class OTPVerificationAction {
    
    public class Input {
        @InvocableVariable(label='OTP Entered by Customer' required=true)
        public String otpEntered;
    }
    
    public class Output {
        @InvocableVariable(label='Is OTP Valid')
        public Boolean isValid;
        
        @InvocableVariable(label='Message')
        public String message;
    }
    
    @InvocableMethod(label='Verify OTP' 
                     description='Verifies the OTP entered by the customer. Hardcoded as 1234 for demo.')
    
    public static List<Output> verifyOTP(List<Input> inputs) {
        List<Output> results = new List<Output>();
        for (Input inp : inputs) {
            Output out = new Output();
            if (inp.otpEntered == '1234') {
                out.isValid = true;
                out.message = 'Authentication SUCCESSFUL !! How may I help you?';
            } else {
                out.isValid = false;
                out.message = '!! INCORRECT OTP !! Please try again.... ';
            }
            results.add(out);
        }
        return results;
    }
}