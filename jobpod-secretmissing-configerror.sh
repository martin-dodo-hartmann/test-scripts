#!/bin/bash
# Creates 'instanceCount' jobs, which just run a busybox, but have a dependency
# for a secret to mount. These secrets get created after the job.
# Expected: All jobs run successfully after the secret exists.
# Actual: Some job-pods are stuck in CreateContainerConfigError state.

# count of job instances to create
instanceCount=50

# secret template
testSecret='{
    "apiVersion": "v1",
    "data": {
        "val": "Zm9vYmFy"
    },
    "kind": "Secret",
    "metadata": {
        "name": "busybox-secret-NUMBER",
        "namespace": "default",
        "labels": {
            "component": "busybox",
            "id": "test-busybox-NUMBER"
        }
    },
    "type": "Opaque"
}'

# busybox job template
testJob='{
    "apiVersion": "batch/v1",
    "kind": "Job",
    "metadata": {
        "labels": {
            "component": "busybox",
            "id": "test-busybox-NUMBER"
        },
        "name": "test-busybox-NUMBER",
        "namespace": "default"
    },
    "spec": {
        "backoffLimit": 3,
        "completions": 1,
        "parallelism": 1,
        "template": {
            "metadata": {
                "labels": {
                    "component": "busybox",
                    "job-name": "test-busybox-NUMBER",
                    "id": "test-busybox-NUMBER"
                },
                "name": "test-busybox-NUMBER",
                "namespace": "default"
            },
            "spec": {
                "containers": [
                  {
                    "env": [
                        {
                            "name": "SECRET_VALUE",
                            "valueFrom": {
                                "secretKeyRef": {
                                    "key": "val",
                                    "name": "busybox-secret-NUMBER"
                                }
                            }
                        }
                    ],
                    "image": "busybox",
                    "name": "busybox",
                    "args": ["env"]
                  }
                ],
                "dnsPolicy": "ClusterFirst",
                "restartPolicy": "Never",
                "schedulerName": "default-scheduler",
                "securityContext": {},
                "terminationGracePeriodSeconds": 30
            }
        }
    }
}'

# Create jobs, which are waiting for their secrets
createJobs() {
  for ((i=1;i<=instanceCount;i++));
  do
    rm jobTempFile.json >> /dev/null
    echo $testJob | sed -e "s/NUMBER/${i}/g" >> jobTempFile.json
    kubectl apply -f jobTempFile.json
  done
}

# Creating secrets, 5 seconds delayed
createSecrets() {
  for ((i=1;i<=instanceCount;i++));
  do
    rm secTempFile.json >> /dev/null
    echo $testSecret | sed -e "s/NUMBER/${i}/g" >> secTempFile.json
    kubectl apply -f secTempFile.json
    sleep 5
  done
}

createJobs &
createSecrets &
wait
