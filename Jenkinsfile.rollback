pipeline {
    agent any

    parameters {
        string(
            name:         'SERVICE_NAME',
            defaultValue: '',
            description:  'Name of the service to rollback (e.g. payment-api)'
        )
        string(
            name:         'FAILED_IMAGE',
            defaultValue: '',
            description:  'Docker image that failed (e.g. payment-api:v101)'
        )
        string(
            name:         'FAILURE_REASON',
            defaultValue: 'Health check failed 5 consecutive times',
            description:  'Why the rollback was triggered'
        )
        string(
            name:         'FAILED_AT',
            defaultValue: '',
            description:  'Timestamp when failure was detected'
        )
    }

    environment {
        DB_HOST = credentials('DB_HOST')
        DB_PASSWORD = credentials('DB_PASSWORD')
        TELEGRAM_TOKEN = credentials('TELEGRAM_TOKEN')
        TELEGRAM_CHAT_ID = credentials('TELEGRAM_CHAT_ID')
    }

    stages {
        stage('Get Target') {
            steps {
                script {
                    echo "Looking up last safe build for: ${params.SERVICE_NAME}"

                    def result = sh(
                        script: """
                            python3 -c "
                            from dotenv import load_dotenv
                            load_dotenv()
                            from build_registry import get_last_safe_build
                            safe = get_last_safe_build('${params.SERVICE_NAME}')
                            if safe:
                                print(safe['image'])
                            else:
                                print('NOT_FOUND')
                            "
                        """,
                        returnStdout: true
                    ).trim()

                    if (result == 'NOT_FOUND') {
                        error("No safe build found for ${params.SERVICE_NAME}. Manual intervention required!")
                    }

                    env.SAFE_IMAGE = result
                    echo "Rollback target: ${env.SAFE_IMAGE}"
                }
            }
        }

        stage('Execute Rollback') {
            steps {
                script {
                    echo "Rolling back ${params.SERVICE_NAME} to ${env.SAFE_IMAGE}"

                    sh """
                        kubectl set image deployment/${params.SERVICE_NAME} \
                            ${params.SERVICE_NAME}=${env.SAFE_IMAGE}
                    """

                    echo "Rollback command executed"
                }
            }
        }

        stage('Verify Deployed') {
            steps {
                script {
                    echo "Waiting for rollback to complete..."

                    def rolloutStatus = sh(
                        script: "kubectl rollout status deployment/${params.SERVICE_NAME} --timeout=5m",
                        returnStatus: true
                    )

                    if (rolloutStatus == 0) {
                        env.ROLLBACK_STATUS = "SUCCESS"
                        echo "Rollback verified — ${params.SERVICE_NAME} is running ${env.SAFE_IMAGE}"
                    } else {
                        env.ROLLBACK_STATUS = "FAILED"
                        error("Rollback failed — ${params.SERVICE_NAME} did not stabilize!")
                    }
                }
            }
        }

        stage('Notify') {
            steps {
                script {
                    echo "Sending Telegram alert..."

                    sh """
                        python3 -c "
                        from telegram_alerter import send_rollback_alert
                        send_rollback_alert(
                            service='${params.SERVICE_NAME}',
                            failed_image='${params.FAILED_IMAGE}',
                            safe_image='${env.SAFE_IMAGE}',
                            reason='${params.FAILURE_REASON}',
                            rollback_status='${env.ROLLBACK_STATUS}',
                            failed_at='${params.FAILED_AT}',
                            jenkins_url='${env.BUILD_URL}'
                        )
                        "
                    """
                }
            }
        }
    }

    post {
        success {
            echo "Rollback pipeline completed successfully"
        }
        failure {
            echo "Rollback pipeline failed — manual intervention may be required"
            sh """
                python3 -c "
                from telegram_alerter import send_rollback_alert
                send_rollback_alert(
                    service='${params.SERVICE_NAME}',
                    failed_image='${params.FAILED_IMAGE}',
                    safe_image='${env.SAFE_IMAGE ?: 'unknown'}',
                    reason='${params.FAILURE_REASON}',
                    rollback_status='PIPELINE FAILED',
                    failed_at='${params.FAILED_AT}',
                    jenkins_url='${env.BUILD_URL}'
                )
                " || true
            """
        }
    }
}