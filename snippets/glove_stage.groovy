#!/usr/bin/env groovy

def GloveStage(String stage_name, Closure closure) {
    stage(stage_name) {
            try {
                echo "I'm in GloveStage"
                closure.call()
            } catch (exc) {
                error "Failed at ${stage_name} with: ${exc.getMessage()}"
            }
    }
}


node ('some-node') {
    try {
        GloveStage('Fail', {
            sh 'false'
        })

    } catch (exc) {
        echo "Caught: ${exc}"
    }
}
