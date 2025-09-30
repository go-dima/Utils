#!/usr/bin/env groovy

@Library('custom-library')_

properties([
    disableConcurrentBuilds(),
    parameters([
        string(
            name: 'SAMPLE_STRING',
            defaultValue: 'Hello World',
            description: 'A sample string parameter'
        ),
        choice(
            name: 'SAMPLE_CHOICE',
            choices: ['default', 'manual', 'from-http'].join('\n'),
            description: 'A sample multiple choice parameter'
        ),
        booleanParam(
            name: 'SAMPLE_BOOLEAN',
            defaultValue: false,
            description: 'A sample boolean parameter'
        )
    ])
])

podTemplateCloudToolsYamlClosure {
    stage('Print Parameters') {
        echo '=== Sample Parametrized Pipeline ==='
        echo "String Parameter (SAMPLE_STRING): ${params.SAMPLE_STRING}"
        echo "Choice Parameter (SAMPLE_CHOICE): ${params.SAMPLE_CHOICE}"
        echo "Boolean Parameter (SAMPLE_BOOLEAN): ${params.SAMPLE_BOOLEAN}"
        echo '==================================='

        // Additional parameter information
        echo 'Parameter types:'
        echo "- SAMPLE_STRING is a string with value: '${params.SAMPLE_STRING}'"
        echo "- SAMPLE_CHOICE is a choice with selected value: '${params.SAMPLE_CHOICE}'"
        echo "- SAMPLE_BOOLEAN is a boolean with value: ${params.SAMPLE_BOOLEAN}"
    }

    stage('Parameter Validation') {
        currentBuild.displayName = "#${env.BUILD_NUMBER}.${params.SAMPLE_CHOICE}"
        currentBuild.description = params.SAMPLE_STRING ? params.SAMPLE_STRING : 'String is empty'

        if (params.SAMPLE_BOOLEAN) {
            addInfoBadge(text: "Selected: ${params.SAMPLE_CHOICE}")
        } else {
            addWarningBadge(text: 'Boolean is false')
        }
    }
}
