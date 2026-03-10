public class SearchKnowledgeAction {
    
    public class Input {
        @InvocableVariable(label='Customer Question' required=true)
        public String customerQuestion;
    }
    
    public class Output {
        @InvocableVariable(label='Policy Answer')
        public String policyAnswer;
        
        @InvocableVariable(label='Success')
        public Boolean success;
    }
    
    @InvocableMethod(label='Search Knowledge Articles' 
                     description='Searches Salesforce Knowledge Articles for insurance policy information based on customer question.')
    
    public static List<Output> searchKnowledge(List<Input> inputs) {
        List<Output> results = new List<Output>();
        
        for (Input inp : inputs) {
            Output out = new Output();
            try {
                // Search published Knowledge Articles
                List<Knowledge__kav> articles = [
                    SELECT Title, Summary, Body__c
                    FROM Knowledge__kav
                    WHERE PublishStatus = 'Online'
                    AND Language = 'en_US'
                    AND (Title LIKE :('%' + inp.customerQuestion + '%')
                    OR Summary LIKE :('%' + inp.customerQuestion + '%'))
                    LIMIT 3
                ];
                
                if (articles.isEmpty()) {
                    // Try broader search with keywords
                    String keyword = extractKeyword(inp.customerQuestion);
                    articles = [
                        SELECT Title, Summary, Body__c
                        FROM Knowledge__kav
                        WHERE PublishStatus = 'Online'
                        AND Language = 'en_US'
                        AND (Title LIKE :('%' + keyword + '%')
                        OR Summary LIKE :('%' + keyword + '%'))
                        LIMIT 3
                    ];
                }
                
                if (articles.isEmpty()) {
                    // Return all published articles as fallback
                    articles = [
                        SELECT Title, Summary, Body__c
                        FROM Knowledge__kav
                        WHERE PublishStatus = 'Online'
                        AND Language = 'en_US'
                        LIMIT 3
                    ];
                }
                
                if (articles.isEmpty()) {
                    out.success = false;
                    out.policyAnswer = 'I could not find specific information for your query. Please contact our support team for detailed policy information.';
                } else {
                    String answer = '';
                    for (Knowledge__kav art : articles) {
                        answer += '📋 ' + art.Title + '\n';
                        if (String.isNotBlank(art.Summary)) {
    answer += stripHtml(art.Summary) + '\n\n';
}
if (String.isNotBlank(art.Body__c)) {
    answer += stripHtml(art.Body__c) + '\n\n';
}

                    }
                    out.success = true;
                    out.policyAnswer = answer.trim();
                }
                
            } catch (Exception e) {
                out.success = false;
                out.policyAnswer = 'Error searching knowledge base: ' + e.getMessage();
            }
            results.add(out);
        }
        return results;
    }
    
    private static String extractKeyword(String question) {
        // Extract key insurance terms from question
        String q = question.toLowerCase();
        if (q.contains('health')) return 'Health';
        if (q.contains('life')) return 'Life';
        if (q.contains('vehicle') || q.contains('car') || q.contains('motor')) return 'Vehicle';
        if (q.contains('claim')) return 'claim';
        if (q.contains('premium')) return 'premium';
        if (q.contains('coverage') || q.contains('cover')) return 'coverage';
        if (q.contains('policy')) return 'Insurance';
        return 'Insurance'; // default
    }
    private static String stripHtml(String html) {
    if (String.isBlank(html)) return '';
    // Remove HTML tags
    String stripped = html.replaceAll('<[^>]+>', ' ');
    // Clean up extra spaces
    stripped = stripped.replaceAll('&nbsp;', ' ');
    stripped = stripped.replaceAll('&amp;', '&');
    stripped = stripped.replaceAll('&lt;', '<');
    stripped = stripped.replaceAll('&gt;', '>');
    stripped = stripped.replaceAll(' +', ' ');
    stripped = stripped.trim();
    return stripped;
}

}