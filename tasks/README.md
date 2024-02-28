# Project Tasks

This project uses [Task](https://taskfile.dev/#/), a task runner / simpler Make alternative written in Go, to manage tasks.

## Taskfile Structure

The `Taskfile.yml` includes tasks from two other files: `GlobalTasks.yml` and `KubeTasks.yml`.

### Included Taskfiles

- `UtilsTasks.yml`: Contains utils tasks that can be used across the project.
- `KubeTasks.yml`: Contains tasks related to Kubernetes operations.

## Tasks

### port-forward

This task depends on `utils:verify-platform` and `utils:update-tasks-repo` tasks defined in `UtilsTasks.yml`. It runs the `k8s:port-forward-wrapper` task defined in `KubeTasks.yml`.

To run the tasks, use the following commands:

```bash
# install taskfile binary
brew install go-task

# usage: run task
[VAR_NAME="VARVALUE"] task [-f path/to/Taskfile.yml] <task_name>

# usage: list tasks in current dir
task --list

# simple usage from the same dir ( existing Taskfile.yml)
task port-forward 

# simple usage from any dir ( with path to taskfile )
task -f /path/to/Taskfile.yml] port-forward [-vv]


# overriding env vars 
SERVICES="postgresql,kafka"  NAMESPACE=foo task port-forward
SERVICES="kosmos-ui-v1" NAMESPACE=production task -t pf
```

recommended setup:
```bash
# inside current directory
task utils:generate-global-tasks

# pro tip: use kubens tool to pin the default namespace in every context and the task will use it automatically 

# from there on it will create a global taskfile and any command above could be done with kodem prefix i.e:
task -g kodem:port-forward # or kodem:pf for short
NAMESPACE="staging" SERVICES="kafka,kafka-ui,kosmos-ui-v1" task -g kodem:pf
CONTEXT="gke_kosmos-staging-0_us-central1-a_kosmos-staging-us-central1" task -g kodem:pf
```