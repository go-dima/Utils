#!/usr/bin/env groovy

node ('some-node') {
    def step_succeeds = false
    def counter = 1
    retry(3) {
        try {
            stage("Run #${counter}") {
                sh "echo ${counter}"
                sh "${step_succeeds}"
            }
        } catch (exc) {
            echo "Caught: ${exc}"
            step_succeeds = true
            counter += 1
            sh "false"
        }
    }
}
