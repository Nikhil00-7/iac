pipeline {
    agent any

    tools {
        terraform 'terraform'  
    }

    environment {
        AWS_ACCESS_KEY_ID = credentials('aws-access-key')
        AWS_SECRET_ACCESS_KEY = credentials('aws-secret-key')
        AWS_DEFAULT_REGION    = 'us-east-1'
        TF_IN_AUTOMATION      = 'true'   
    }

    options {
        timeout(time: 30, unit: 'MINUTES')  
        timestamps()
        ansiColor('xterm')
        buildDiscarder(logRotator(numToKeepStr: '10'))
    }

    stages {

        stage("Checkout Code") {
            steps {
                git branch: 'main', url: 'YOUR_REPO_URL_HERE'
            }
        }

        stage("Pre Check") {
            steps {
                script {
                    def requiredFiles = ['provider.tf', 'ecr.tf', 'main.tf']
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
                    sh "terraform init"
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
                sh "terraform plan -out=tfplan"
        
                archiveArtifacts artifacts: 'tfplan', fingerprint: true
            }
        }

        stage("Manual Approval") {
            steps {
                script {
           
                    sh "terraform show -no-color tfplan"

                    def userChoice = input(
                        id: "ProceedWithApply",
                        message: "Review the plan above. Proceed with terraform apply?",
                        parameters: [
                            choice(
                                name: "confirmation",
                                choices: ["no", "yes"],
                                description: "Select YES only after reviewing the plan"
                            )
                        ]
                    )

                    if (userInput['confirmation'] != "yes") {
                        error("Deployment aborted by ${env.APPROVER}")
                    }

                    echo "Approved by: ${env.APPROVER}"
                }
            }
        }

        stage("Terraform Apply") {
            steps {
                
                sh "terraform apply -auto-approve tfplan"
            }
        }

 
        stage("Verify Infrastructure") {
            steps {
                script {
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
                    echo "Do NOT auto-destroy — check AWS console first"
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
                Do NOT run terraform destroy without reviewing current state.
                """,
                to: "kujurnikhil0007@gmail.com"
            )
        }
    }
}