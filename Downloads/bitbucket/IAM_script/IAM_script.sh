#!/bin/bash

set -e
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
webhook="https://hooks.slack.com/services/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"

#### Store Error log Output ####
exec 2> $HOME/IAM_error.txt

#### Define function to handle errors ####
handle_error() {
    #### Log error to file ####
    echo "$(date +"%Y-%m-%d %T") Error: $1" >> $HOME/IAM_error.txt

    #### Construct payload for Slack message ####
    log_path="$HOME/IAM_error.txt"
    script_path=$(readlink -f "$0")
    payload='{ "blocks": [ { "type": "section", "text": { "type": "mrkdwn", "text": "Error occurred Check. Please check the logs at:\nLog Path: `'"$HOME/IAM_error.txt"'`\nScript Path: `'"$0"'`\nError Details: \n```'"$(date +"%Y-%m-%d %T") $1"'```" } } ] }'

    #### Post payload to Slack channel ####
    curl -X POST -H 'Content-type: application/json' --data "$payload" $webhook
}

# Set trap to call handle_error function on errors
trap 'handle_error "Script failed at line $LINENO"' ERR



# Set the output file name
output_file="example.csv"
# Get all IAM user names
user_names=$(aws iam list-users --query "Users[].UserName" --output text)
# Loop through each user
for user_name in $user_names
do
  # Get MFA status of the user
  mfa=$(aws iam list-mfa-devices --user-name $user_name --query "MFADevices[].UserName" --output text)
  # Get the access keys of the user
  access_keys=$(aws iam list-access-keys --user-name $user_name --query "AccessKeyMetadata[].[AccessKeyId,CreateDate,Status]" --output text)
  # Loop through each access key
  while read -r access_key_id create_date status; do
    # Calculate the age of the access key in days
    age=$(echo "$(date +%s) - $(date -d "$create_date" +%s)" | bc)
    age_in_days=$((age / 86400))
    # Check if the access key is older than 90 days
    if [[ $age_in_days -ge 90 ]]; then
      # Print the user name, access key ID and age in days to the output file
      echo "$user_name,$access_key_id,$age_in_days" >> $output_file
    fi
  done <<< "$access_keys"
  # Check if the user has MFA enabled
  if [[ -z $mfa ]]; then
    # Print the user name to the output file
    echo "$user_name,No MFA" >> $output_file
  fi
done

# Set the Slack webhook URL

# Set the file path
#FILE_PATH="/home/ubuntu/iam_users_report.csv"

# Use curl to upload the file
#curl -X POST -H 'Content-type: application/json' \
#--data "{\"text\":\"Here's the file!\", \"attachments\":[{\"fallback\":\"$FILE_PATH\",\"title\":\"$FILE_PATH\",\"text\":\"$FILE_PATH\",\"color\":\"#36a64f\",\"attachment_type\":\"default\",\"actions\":[{\"name\":\"download\",\"text\":\"Download\",\"type\":\"button\",\"url\":\"$FILE_PATH\"}]}]}" \
#-F file=@$FILE_PATH \
#$SLACK_WEBHOOK_URL

curl -F file=@$output_file -F "initial_comment=Example file" -F channels=C021A8R89U1, -H "Authorization: Bearer xoxb-3379100562-5095818157232-zlTkg6wI1l8tiqCFkyD3xF77" https://slack.com/api/files.upload > /dev/null 2>&1
