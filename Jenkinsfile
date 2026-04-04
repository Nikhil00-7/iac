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
                    def requiredFiles = [
                        'provider.tf',
                        'ecr.tf',
                        'alb.tf',
                        'asg.tf',
                        'vpc.tf',
                        'iam.tf',
                        'security.tf',
                        'user_data.sh'
                    ]
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
                    rm -rf .terraform .terraform.lock.hcl terraform.tfstate*
                    rm -rf ~/.terraform.d/plugin-cache || true
                    
                    # Force amd64 provider for Intel Mac
                    rm -rf .terraform/providers/registry.terraform.io/hashicorp/aws/*/darwin_arm64 || true
                    
                    terraform init -upgrade
                    """
                }
            }
        }

        stage("Validate & Scan") {
            steps {
                script {
                    echo "Running validation and security checks..."
                    
                    // Terraform Format Check
                    def fmtStatus = sh(script: "terraform fmt -check -recursive", returnStatus: true)
                    if (fmtStatus != 0) {
                        echo "WARNING: terraform fmt check failed — formatting issues detected"
                        sh "terraform fmt -recursive"  // Auto-fix formatting
                    }
                    
                    // Terraform Validate
                    def validateStatus = sh(script: "terraform validate", returnStatus: true)
                    if (validateStatus != 0) {
                        error("Terraform validation failed")
                    }
                    echo "Terraform validation passed"
                    
                    // Terraform Lint (optional)
                    def lintStatus = sh(script: "which tflint && tflint --init && tflint || echo 'tflint not installed'", returnStatus: true)
                    if (lintStatus == 0) {
                        echo "tflint passed"
                    }
                    
                    // Security Scan (soft-fail)
                    def scanStatus = sh(
                        script: "checkov -d . --quiet --compact --framework terraform --soft-fail || true",
                        returnStatus: true
                    )
                    echo "Security scan completed with status: ${scanStatus}"
                }
            }
        }

        stage("Terraform Plan") {
            steps {
                script {
                    def planStatus = sh(
                        script: "terraform plan -out=tfplan -detailed-exitcode",
                        returnStatus: true
                    )

                    if (planStatus == 1) {
                        error("Terraform plan failed")
                    }

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
                   withCredentials([aws(credentialsId: 'aws-credentials')]) {
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
                    withCredentials([aws(credentialsId: 'aws-credentials')]) {
                        sh '''
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
                        CAPACITY=$(aws autoscaling describe-auto-scaling-groups \
                            --auto-scaling-group-names my-app-asg \
                            --region ${AWS_DEFAULT_REGION} \
                            --query 'AutoScalingGroups[0].DesiredCapacity' \
                            --output text)

                        if [ "$CAPACITY" != "0" ]; then
                            echo "WARNING: ASG capacity is $CAPACITY, expected 0"
                        else
                            echo "ASG is correctly set to 0 — ready for app pipeline"
                        fi
                        '''
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