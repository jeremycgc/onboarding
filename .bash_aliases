alias tf="terraform"
alias tfi="tf init"
alias tfp="tf plan"
alias tfa="tf apply"
alias tg="terragrunt"
alias tgi="tg init"
alias tgp="tg plan"
alias tga="tg apply"
alias tgrmcache="find . -name ".terragrunt-cache" -type d -exec rm -rf "{}" \;"
alias hg="history | grep"
alias k="kubectl"
alias kvu="k view-utilization -h"
alias synchw="sudo hwclock -s"

alias awsl="aws sso login --profile cdev"
alias gawsl="aws sso login --profile gdev"
alias awswhoami="aws sts get-caller-identity --output table"
alias ssm="aws ssm start-session --target"

# Set AWS Profile
init() {
    echo "Select an Aws Profile"
    profile
    if [[ $AWS_PROFILE == twn ]]; then
      echo "Selecting us-gov-west-1 region"
      region us-gov-west-1
      mfalogin
    else
      echo "Select default AWS Region"
      region
    fi
    echo "Select a Kubeconfig Context"
    context
}

awsmfakey() {
  export AWS_USER=`aws sts get-caller-identity --profile $AWS_PROFILE | grep arn:aws | sed 's/.* "\(.*\)"/\1/'`
  export AWS_MFA=`echo $AWS_USER | sed 's/user/mfa/'`
  export CREDS=$(aws sts get-session-token --profile $AWS_PROFILE --serial-number "$AWS_MFA" --token-code $1 --output text)
  awk -v OFS='\n\n' '/\[twn-mfa\]/{n=5}; n {n--; next}; 1' < ~/.aws/credentials > ~/.aws/.credentials.mfa
  echo $CREDS | awk '{printf("[twn-mfa]\naws_access_key_id=%s\naws_secret_access_key=%s\naws_session_token=%s\naws_security_token=%s\n",$2,$4,$5,$5)}' >> ~/.aws/.credentials.mfa
  mv -f ~/.aws/.credentials.mfa ~/.aws/credentials
  aws sts get-caller-identity --profile $AWS_PROFILE
}

mfalogin() {
  if [ $1 ]; then
    awsmfakey $1
  else
    MFA=$(gum input --prompt "Enter MFA: ")
    awsmfakey $MFA
  fi
}

profile() {
    if [ $1 ]; then
    export ACTIVE_ENV="$1"
    export AWS_PROFILE="$1"
  else
    TYPE=$(gum choose $(aws configure list-profiles | sort))
    export ACTIVE_ENV="$TYPE"
    export AWS_PROFILE="$TYPE"
  fi
}

# Set K8 Context
context() {
    if [ $1 ]; then
      export KUBE_CONTEXT=$1
      kubectl config use-context $1
    else
      TYPE=$(gum choose $(kubectl config get-contexts -o name))
      export KUBE_CONTEXT=$TYPE
      kubectl config use-context $TYPE
    fi
}

namespace() {
  if [ $1 ]; then
    kubectl config set-context $KUBE_CONTEXT --namespace $1
  else
    TYPE=$(gum choose $(kubectl get namespaces))
    kubectl config set-context $KUBE_CONTEXT --namespace $TYPE
  fi
}

region() {
  if [ $1 ]; then
    export AWS_DEFAULT_REGION="$1"
  else
    if [[ $AWS_PROFILE == twn* ]]; then
      export AWS_DEFAULT_REGION=us-gov-west-1
    else
      export AWS_DEFAULT_REGION=us-east-1
    fi
    REGION=$(gum spin --show-output -s globe --title 'Loading Regions...' -- aws ec2 describe-regions | jq -r '.Regions | to_entries[] | .value.RegionName' | gum filter --placeholder "Pick a region")
    export AWS_DEFAULT_REGION="$REGION"
  fi
}

contextadd() {
  profile
  if [[ $AWS_PROFILE == twn ]]; then
    echo "Selecting us-gov-west-1 region"
    region us-gov-west-1
  else
    echo "Select default AWS Region"
    region
  fi
  name=$(gum choose $(aws eks list-clusters --output text --query 'clusters[*]'))
  aws eks update-kubeconfig --name $name --alias $name
}
#Choose Product

ssd() {
  id=$(agi)
  ssm $id
}

instance_filter() {
  name=$(aws ec2 describe-instances --output text --filters "Name=instance-state-name,Values=running" --query 'Reservations[*].Instances[*].{Tags:Tags[?Key == `Name`] | [0].Value}'| gum filter)
}

agi() {
    name=$(aws ec2 describe-instances --output text --filters "Name=instance-state-name,Values=running" --query 'Reservations[*].Instances[*].{Tags:Tags[?Key == `Name`] | [0].Value}' | gum filter)
    eid $name
}

eid() {
  if [ -n "$1" ]; then
    echo $(aws ec2 describe-instances --filters "Name=tag:Name,Values=$1" "Name=instance-state-name,Values=running" --output text --query 'Reservations[*].Instances[*].InstanceId')
  else
    echo "Please Specify a Value for tag:Name"
  fi
}

#PortForward
pf() {
  if [ -n "$1" ]; then
    ssm $1 --document-name AWS-StartPortForwardingSession --parameters "portNumber=[$2],localPortNumber=[$3]"
  else
    echo "usage: pfp instance_id remote-port local-port"
  fi
}

pfr() {
  if [ -n "$1" ]; then
    aws ssm start-session --target $1 --document-name AWS-StartPortForwardingSessionToRemoteHost --parameters '{"portNumber":[$2],"localPortNumber":[$3],"host":[$4]}'
  else
    echo "usage: pfr instance_id remote-port local-port remote-host"
  fi
}
