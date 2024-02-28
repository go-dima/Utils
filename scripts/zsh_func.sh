alias jurl='(){ curl -s $@ | json_pp }'
alias build_docker_no_tag='() { set -x; docker build $@ --platform linux/amd64 --ssh=default="${GITSSH_CREDS_PATH}" --secret=id=gcloud,src="${GCLOUD_APPLICATION_CREDS}" --build-arg GOOGLE_APPLICATION_CREDENTIALS=/run/secrets/gcloud . }'
alias build_docker='() { build_docker_no_tag -t $(basename `git rev-parse --show-toplevel`):local $@}'
