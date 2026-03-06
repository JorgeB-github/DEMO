#!/bin/sh

USERNAME="$1"
CONSUMER_KEY="$2"
JWT_KEY_FILE_PATH="$3"
PROJECT_KEY="$4"
START_DATE="$5"
END_DATE="$6"
ENVIRONMENT="$7"
STATUS="$8"
TYPE="$9"

AUTH_COMMAND="sf org login jwt --username $USERNAME --client-id $CONSUMER_KEY --jwt-key-file $JWT_KEY_FILE_PATH --alias devops-reports"

echo ""
echo "## AUTHENTICATING"
echo "## COMMAND: $AUTH_COMMAND"
echo ""
eval $AUTH_COMMAND

echo ""
echo "## REPORTING"
echo ""

# Grab auth token
sf org display --target-org devops-reports --json > ./org-data.json
ACCESS_TOKEN=$(cat ./org-data.json | jq -r '.result.accessToken')
INSTANCE_URL=$(cat ./org-data.json | jq -r '.result.instanceUrl')
rm -rf ./org-data.json

echo ""
echo "## START DATE"
echo $START_DATE

echo ""
echo "## END DATE"
echo $END_DATE

echo ""
echo "## ENVIRONMENT"
echo $ENVIRONMENT

echo ""
echo "## PROJECT_KEY"
echo $PROJECT_KEY

echo ""
echo "## STATUS"
echo $STATUS

echo ""
echo "## TYPE"
echo $TYPE

# Fire event
curl -X POST "$INSTANCE_URL/services/data/v64.0/sobjects/Event__c" \
    -H "Authorization: Bearer $ACCESS_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{
        "StartDate__c": "'"$START_DATE"'",
        "EndDate__c": "'"$END_DATE"'",
        "Environment__c": "'"$ENVIRONMENT"'",
        "Project__r": {
            "Key__c": "'"$PROJECT_KEY"'"
        },
        "Status__c": "'"$STATUS"'",
        "Type__c": "'"$TYPE"'"
    }'
