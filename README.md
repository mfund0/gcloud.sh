# gcloud.sh
gcloud quick commands

### List instance names that match a regex:
    gcloud compute instances list --project <project-name> --filter="name~'<REGEX>'"  --format='table[no-heading](name)'

### List and describe firewall rules
    project=<PROJECT-NAME>
    list=`gcloud compute firewall-rules list  --project $project --filter="name~''" --format='table[no-heading](name)'`
    while IFS= read -r line; do
        gcloud compute firewall-rules describe $line --project $project >> $project-firewall-rules.yaml
        echo "\n" >> $project-firewall-rules.yaml
        sleep 3
    done <<< "$list"
