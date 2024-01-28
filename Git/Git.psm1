function Git-Get-CommitByMessage
{
    param
    (
        [Parameter(Mandatory=$true)]
        [string] $Message
    )
    
    git log --all --perl-regexp --grep="$Message" --fixed-strings -i
}

function Git-Get-BranchByCommit
{
    param
    (
        [Parameter(Mandatory=$true)]
        [string] $CommitHash
    )
    
    git branch --contains $CommitHash
}