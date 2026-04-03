pipeline {
    agent any

    tools {
        terraform 'terraform'
    }

    environment {
        AWS_DEFAULT_REGION = 'us-east-1'
        TF_IN_AUTOMATION   = 'true'
        PATH = "/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
    }

    options {
        timeout(time: 30, unit: 'MINUTES')
        timestamps()
        buildDiscarder(logRotator(numToKeepStr: '10'))
    }

    stages {

        stage("Checkout Code") {
            steps {
                git branch: 'main', url: 'https://github.com/Nikhil00-7/iac.git'
            }
        }

        stage("Pre Check") {
            steps {
                script {
                    def requiredFiles = ['provider.tf', 'ecr.tf']
                    requiredFiles.each { file ->
                        if (!fileExists(file)) {
                            error "Required file missing: ${file}"
                        }
                    }
                    echo "All required files present"
                }
            }
        }

        stage("Terraform Init") {
            steps {
                retry(3) {
                    sh """
                    rm -rf .terraform .terraform.lock.hcl
                      export GOARCH=arm64
            export GOOS=darwin
                    terraform init -upgrade
                    """
                }
            }
        }

        stage("Validate & Scan") {
            failFast true
            parallel {

                stage("Terraform Format Check") {
                    steps {
                        sh "terraform fmt -check -recursive"
                    }
                }

                stage("Terraform Validate") {
                    steps {
                        sh "terraform validate"
                    }
                }

                stage("Terraform Lint") {
                    steps {
                        script {
                            def status = sh(script: "tflint", returnStatus: true)
                            if (status != 0) {
                                unstable("tflint found issues — review recommended")
                            }
                        }
                    }
                }

                stage("Security Scan") {
                    steps {
                        script {
                            def status = sh(
                                script: "checkov -d . --quiet --compact",
                                returnStatus: true
                            )
                            if (status != 0) {
                                unstable("Checkov found security issues — review before production")
                            }
                        }
                    }
                }
            }
        }

        stage("Terraform Plan") {
            steps {
                script {
                    sh "terraform plan -out=tfplan -detailed-exitcode || true"
                    archiveArtifacts artifacts: 'tfplan', fingerprint: true
                }
            }
        }

        stage("Manual Approval") {
            steps {
                script {

                    sh "terraform show -no-color tfplan"

                    def userChoice = input(
                        id: "ProceedWithApply",
                        message: "Review the plan above. Proceed with terraform apply?",
                        submitterParameter: "APPROVER",
                        parameters: [
                            choice(
                                name: "confirmation",
                                choices: ["no", "yes"],
                                description: "Select YES only after reviewing the plan"
                            )
                        ]
                    )

                    env.APPROVER = userChoice['APPROVER']

                    if (userChoice['confirmation'] != "yes") {
                        error("Deployment aborted by ${env.APPROVER}")
                    }

                    echo "Approved by: ${env.APPROVER}"
                }
            }
        }

        stage("Terraform Apply") {
            steps {
                script {
                    withCredentials([[
                        $class: 'AmazonWebServicesCredentialsBinding',
                        credentialsId: 'aws-credentials'
                    ]]) {
                        retry(2) {
                            sh "terraform apply -auto-approve tfplan"
                        }
                    }
                }
            }
        }

        stage("Verify Infrastructure") {
            steps {
                script {
                    withCredentials([[
                        $class: 'AmazonWebServicesCredentialsBinding',
                        credentialsId: 'aws-credentials'
                    ]]) {
                        sh """
                        echo "Verifying ECR repository..."
                        aws ecr describe-repositories \
                            --repository-names my-ecr-repository \
                            --region ${AWS_DEFAULT_REGION}

                        echo "Verifying ASG exists..."
                        aws autoscaling describe-auto-scaling-groups \
                            --auto-scaling-group-names my-app-asg \
                            --region ${AWS_DEFAULT_REGION} \
                            --query 'AutoScalingGroups[0].AutoScalingGroupName' \
                            --output text

                        echo "Verifying ASG desired capacity is 0..."
                        CAPACITY=\$(aws autoscaling describe-auto-scaling-groups \
                            --auto-scaling-group-names my-app-asg \
                            --region ${AWS_DEFAULT_REGION} \
                            --query 'AutoScalingGroups[0].DesiredCapacity' \
                            --output text)

                        if [ "\$CAPACITY" != "0" ]; then
                            echo "WARNING: ASG capacity is \$CAPACITY, expected 0"
                        else
                            echo "ASG is correctly set to 0 — ready for app pipeline"
                        fi
                        """
                    }
                }
            }
        }
    }

    post {
        always {
            echo "Cleaning workspace..."
            cleanWs()
        }

        success {
            echo "Infrastructure deployed successfully!"
            emailext(
                subject: "SUCCESS: ${env.JOB_NAME} #${env.BUILD_NUMBER}",
                body: """
                Infrastructure Pipeline Succeeded

                Job:      ${env.JOB_NAME}
                Build:    #${env.BUILD_NUMBER}
                URL:      ${env.BUILD_URL}
                Approver: ${env.APPROVER ?: 'N/A'}

                Infrastructure is ready. You can now run the App Pipeline.
                """,
                to: "kujurnikhil0007@gmail.com"
            )
        }

        failure {
            echo "Pipeline failed!"

            script {
                if (!fileExists('tfplan')) {
                    echo "Failed before apply — no infrastructure was created"
                } else {
                    echo "Apply may have partially run — MANUAL REVIEW REQUIRED"
                }
            }

            emailext(
                subject: "FAILURE: ${env.JOB_NAME} #${env.BUILD_NUMBER}",
                body: """
                Infrastructure Pipeline FAILED

                Job:   ${env.JOB_NAME}
                Build: #${env.BUILD_NUMBER}
                URL:   ${env.BUILD_URL}

                ACTION REQUIRED: Check AWS console before any manual intervention.
                """,
                to: "kujurnikhil0007@gmail.com"
            )
        }
    }
}