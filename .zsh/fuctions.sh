# commit
commit () {
    commitMessage="$1"

    if [ "$commitMessage" = "" ]
    then
        commitMessage="WIP"
    fi

    git add .
    eval "git commit -a -m '${commitMessage}'"
}

# commit and push to github
commit:push () {
    commitMessage="$1"
    gitCurrentBranch=$(git branch --show-current)

    if [ "$commitMessage" = "" ]
    then
        commitMessage="WIP"
    fi

    git add .
    eval "git commit -a -m '${commitMessage}'"
    eval "git push origin ${gitCurrentBranch}"
}