gh workflow run bastion_deploy.yml -f environment=$1 -f command=destroy -f connect-to-database=false -f connect-to-export-efs=false
sleep 10
RUN_ID=$(gh api -H 'Accept: application/vnd.github+json' "/repos/nationalarchives/tdr-scripts/actions/runs?status=waiting" | jq '.workflow_runs[0].id')
ENVIRONMENT_ID=$(gh api -H "Accept: application/vnd.github+json" /repos/nationalarchives/tdr-scripts/environments/$1| jq '.id')
curl -X POST  -H "Accept: application/vnd.github+json" -H "Authorization: token $GITHUB_TOKEN" https://api.github.com/repos/nationalarchives/tdr-scripts/actions/runs/$RUN_ID/pending_deployments  -d "{\"environment_ids\":[$ENVIRONMENT_ID],\"state\":\"approved\",\"comment\":\"\"}" | jq '.[0].url'
