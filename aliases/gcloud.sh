_DEFAULT_PROJECT="myorg-platform-observability-test" #TODO
_DEFAULT_REGION="europe-west1"
_DEFAULT_ZONE="${_DEFAULT_REGION}-b"

#_DEFAULT_ENV="preprod" #(dev, test, uat, stage, prod)
#_DEFAULT_OUTPUT="table(name)"
# Naming convention [company tag]-[group tag]-[system name]-[environment (dev, test, uat, stage, prod)]
# https://cloud.google.com/docs/enterprise/best-practices-for-enterprise-organizations

function gcp-instances() {
    proj=${1:="${_DEFAULT_PROJECT}"}
    gcloud compute instances list --format="table(name)" --project "$proj"
}
function gcp-fwdrules() {
    local filter=$1
    local proj=${2:=${_DEFAULT_PROJECT}}
    gcloud compute forwarding-rules list --filter="${filter}" --format="yaml" --project "$proj"
}

function gcp-igs() {
    local filter=$1
    local proj=${2:="${_DEFAULT_PROJECT}"}
    gcloud compute instance-groups list --filter="${filter}" --format="yaml" --project "$proj"
}

function tail-serial-port() {
    local instance=$1
    local proj=${2:="${_DEFAULT_PROJECT}"}
    gcloud compute instances tail-serial-port-output "$instance" --zone "${_DEFAULT_ZONE}" --project "$proj"
}

function gcp-subnets() {
    list=$(gcp-projects)
    while IFS= read -r line; do
        echo GCP_PROJECT: "${line}"
        gcloud compute networks subnets list --project "${line}" --regions "${_DEFAULT_REGION}"
    done <<< "$list"
}

function gke-autoscaler-events() {
    gcloud logging read "logName:cluster-autoscaler-visibility" --project ${_DEFAULT_PROJECT}\
     --format="table(timestamp,jsonPayload.decision.scaleDown,jsonPayload.decision.scaleUp)"
}

function gcp-instance-preempted() {
    local proj=${1:=${_DEFAULT_PROJECT}}
    gcloud logging read "resource.type=gce_instance AND
    protoPayload.methodName=compute.instances.preempted" --project $proj\
     --format="yaml(protoPayload,timestamp)"
}

function gcp-ssh() {
    local proj=${1:=${_DEFAULT_PROJECT}}
    if ! _find_fingerprint; then
        gcp-ssh-withadd $proj
        exit $?
    fi
    gcloud compute --project $proj ssh --zone "${_DEFAULT_ZONE}" --ssh-flag="-A" bastion
}

function gcp-firewallrules() {
    local proj=${1:=${_DEFAULT_PROJECT}}
     gcloud compute firewall-rules list --format="yaml(
        name,
        network,
        direction,
        priority,
        sourceRanges.list():label=SRC_RANGES,
        destinationRanges.list():label=DEST_RANGES,
        allowed[].map().firewall_rule().list():label=ALLOW,
        denied[].map().firewall_rule().list():label=DENY,
        sourceTags.list():label=SRC_TAGS,
        sourceServiceAccounts.list():label=SRC_SVC_ACCT,
        targetTags.list():label=TARGET_TAGS,
        targetServiceAccounts.list():label=TARGET_SVC_ACCT,
        disabled
    )" --project $proj
}

function gke-get-credentials() {
    local cluster=$1 #environment=$2 
    gcloud container clusters get-credentials ${cluster} --region "${_DEFAULT_REGION}" --project $proj
}

function gcp-ssh-withadd() {
    echo "adding ~/.ssh/google_compute_engine to agent"
    ssh-add ~/.ssh/google_compute_engine
    local proj=${1:="${_DEFAULT_PROJECT}"}
    gcloud compute --project $proj ssh --zone "${_DEFAULT_ZONE}" --ssh-flag="-A" bastion
}

function _find_fingerprint() {
    _fingerprints="$(ssh-add -l)"
    _gce_fingerprint="$(ssh-keygen -lf ~/.ssh/google_compute_engine)"
    if [[ "${_fingerprints}" = *"${_gce_fingerprint}"* ]]; then
        echo "figerprint confirmed"
        return 0
    else
        return 1
    fi
}

# list google cloud nat ips
function gcp-natips() {
    project=$1 router=$2 name=$3
    natips=$(gcloud compute routers nats describe --router=${router} --router-region=${_DEFAULT_REGION} --project ${project} --format="csv[no-heading](natIps)" "${name}")
    natips="${natips//;/ }"
    for natip in $( echo $natips );do  #TODO
        gcp-curl "$natip"
    done
}

# curl  google api ( https://www.googleapis.com/ ) resources
function gcp-curl() {
    curl -s -H "Authorization: Bearer $(gcloud auth print-access-token)" $1
}
