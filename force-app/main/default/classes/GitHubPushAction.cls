public class GitHubPushAction {
    
    @InvocableMethod(label='Push Code to GitHub' 
                     description='Pushes code changes to a GitHub repository'
                     category='GitHub')
    public static List<PushResult> pushToGitHub(List<PushRequest> requests) {
        List<PushResult> results = new List<PushResult>();
        
        for(PushRequest req : requests) {
            PushResult result = new PushResult();
            try {
                String currentSHA = getCurrentBranchSHA(req.owner, req.repo, req.branch);
                String baseTreeSHA = getBaseTree(req.owner, req.repo, currentSHA);
                List<Map<String, String>> treeItems = new List<Map<String, String>>();
                for(FileChange fileChange : req.fileChanges) {
                    String blobSHA = createBlob(req.owner, req.repo, fileChange.content);
                    treeItems.add(new Map<String, String>{
                        'path' => fileChange.path,
                        'mode' => '100644',
                        'type' => 'blob',
                        'sha' => blobSHA
                    });
                }
                String newTreeSHA = createTree(req.owner, req.repo, baseTreeSHA, treeItems);
                String commitSHA = createCommit(
                    req.owner, 
                    req.repo, 
                    req.commitMessage, 
                    newTreeSHA, 
                    currentSHA
                );
                updateReference(req.owner, req.repo, req.branch, commitSHA);
                result.success = true;
                result.message = 'Successfully pushed changes to ' + req.branch;
                result.commitSHA = commitSHA;
                
            } catch(Exception e) {
                result.success = false;
                result.message = 'Error: ' + e.getMessage();
                System.debug('Push Error: ' + e.getMessage());
                System.debug('Stack Trace: ' + e.getStackTraceString());
            }
            results.add(result);
        }
        return results;
    }
    
    private static String getCurrentBranchSHA(String owner, String repo, String branch) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:GitHub_NC/repos/' + owner + '/' + repo + '/git/ref/heads/' + branch);
        req.setMethod('GET');
        req.setHeader('Accept', 'application/vnd.github.v3+json');
        req.setTimeout(60000);
        Http http = new Http();
        HttpResponse res = http.send(req);
        System.debug('Get Branch SHA - Status: ' + res.getStatusCode());
        System.debug('Get Branch SHA - Response: ' + res.getBody());
        if(res.getStatusCode() == 200) {
            Map<String, Object> result = (Map<String, Object>)JSON.deserializeUntyped(res.getBody());
            Map<String, Object> objectData = (Map<String, Object>)result.get('object');
            return (String)objectData.get('sha');
        }
        throw new GitHubException('Failed to get branch reference: ' + res.getBody());
    }
    
    private static String getBaseTree(String owner, String repo, String commitSHA) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:GitHub_NC/repos/' + owner + '/' + repo + '/git/commits/' + commitSHA);
        req.setMethod('GET');
        req.setHeader('Accept', 'application/vnd.github.v3+json');
        req.setTimeout(60000);
        Http http = new Http();
        HttpResponse res = http.send(req);
        System.debug('Get Base Tree - Status: ' + res.getStatusCode());
        System.debug('Get Base Tree - Response: ' + res.getBody());
        if(res.getStatusCode() == 200) {
            Map<String, Object> result = (Map<String, Object>)JSON.deserializeUntyped(res.getBody());
            Map<String, Object> tree = (Map<String, Object>)result.get('tree');
            return (String)tree.get('sha');
        }
        throw new GitHubException('Failed to get base tree: ' + res.getBody());
    }
    
    private static String createBlob(String owner, String repo, String content) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:GitHub_NC/repos/' + owner + '/' + repo + '/git/blobs');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('Accept', 'application/vnd.github.v3+json');
        req.setTimeout(60000);
        
        Map<String, String> body = new Map<String, String>{
            'content' => content,
            'encoding' => 'utf-8'
        };
        req.setBody(JSON.serialize(body));
        
        Http http = new Http();
        HttpResponse res = http.send(req);
        
        System.debug('Create Blob - Status: ' + res.getStatusCode());
        System.debug('Create Blob - Response: ' + res.getBody());
        
        if(res.getStatusCode() == 201) {
            Map<String, Object> result = (Map<String, Object>)JSON.deserializeUntyped(res.getBody());
            return (String)result.get('sha');
        }
        throw new GitHubException('Failed to create blob: ' + res.getBody());
    }
    
    private static String createTree(String owner, String repo, String baseTree, List<Map<String, String>> treeItems) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:GitHub_NC/repos/' + owner + '/' + repo + '/git/trees');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('Accept', 'application/vnd.github.v3+json');
        req.setTimeout(60000);
        
        Map<String, Object> body = new Map<String, Object>{
            'base_tree' => baseTree,
            'tree' => treeItems
        };
        req.setBody(JSON.serialize(body));
        
        Http http = new Http();
        HttpResponse res = http.send(req);
        
        System.debug('Create Tree - Status: ' + res.getStatusCode());
        System.debug('Create Tree - Response: ' + res.getBody());
        
        if(res.getStatusCode() == 201) {
            Map<String, Object> result = (Map<String, Object>)JSON.deserializeUntyped(res.getBody());
            return (String)result.get('sha');
        }
        throw new GitHubException('Failed to create tree: ' + res.getBody());
    }
    
    private static String createCommit(String owner, String repo, String message, String treeSHA, String parentSHA) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:GitHub_NC/repos/' + owner + '/' + repo + '/git/commits');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('Accept', 'application/vnd.github.v3+json');
        req.setTimeout(60000);
        
        Map<String, Object> body = new Map<String, Object>{
            'message' => message,
            'tree' => treeSHA,
            'parents' => new List<String>{parentSHA}
        };
        req.setBody(JSON.serialize(body));
        
        Http http = new Http();
        HttpResponse res = http.send(req);
        
        System.debug('Create Commit - Status: ' + res.getStatusCode());
        System.debug('Create Commit - Response: ' + res.getBody());
        
        if(res.getStatusCode() == 201) {
            Map<String, Object> result = (Map<String, Object>)JSON.deserializeUntyped(res.getBody());
            return (String)result.get('sha');
        }
        throw new GitHubException('Failed to create commit: ' + res.getBody());
    }
    
    private static void updateReference(String owner, String repo, String branch, String commitSHA) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:GitHub_NC/repos/' + owner + '/' + repo + '/git/refs/heads/' + branch);
        req.setMethod('PATCH');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('Accept', 'application/vnd.github.v3+json');
        req.setTimeout(60000);
        
        Map<String, Object> body = new Map<String, Object>{
            'sha' => commitSHA,
            'force' => false
        };
        req.setBody(JSON.serialize(body));
        
        Http http = new Http();
        HttpResponse res = http.send(req);
        
        System.debug('Update Reference - Status: ' + res.getStatusCode());
        System.debug('Update Reference - Response: ' + res.getBody());
        
        if(res.getStatusCode() != 200) {
            throw new GitHubException('Failed to update reference: ' + res.getBody());
        }
    }

    public class PushRequest {
        @InvocableVariable(required=true label='Repository Owner')
        public String owner;
        
        @InvocableVariable(required=true label='Repository Name')
        public String repo;
        
        @InvocableVariable(required=true label='Branch Name')
        public String branch;
        
        @InvocableVariable(required=true label='Commit Message')
        public String commitMessage;
        
        @InvocableVariable(required=true label='File Changes')
        public List<FileChange> fileChanges;
    }
    
    public class FileChange {
        @InvocableVariable(required=true label='File Path')
        public String path;
        
        @InvocableVariable(required=true label='File Content')
        public String content;
    }
    
    public class PushResult {
        @InvocableVariable(label='Success')
        public Boolean success;
        
        @InvocableVariable(label='Message')
        public String message;
        
        @InvocableVariable(label='Commit SHA')
        public String commitSHA;
    }
    
    public class GitHubException extends Exception {}
}