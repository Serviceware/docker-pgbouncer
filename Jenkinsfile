pipeline {
    agent { label 'libvirt' }

    // Jenkins builds from the Bitbucket mirror (sabio-it/docker-pgbouncer),
    // which is auto-synced from the canonical GitHub repo. Trigger matches
    // the build source, consistent with the other containerize-* jobs.
    triggers {
        bitbucketPush()
    }

    options {
        timestamps()
        disableConcurrentBuilds()
    }

    environment {
        IMAGE = 'images.tools.swops.cloud/platform-engineering/pgbouncer'
    }

    stages {
        stage('Resolve version') {
            steps {
                script {
                    // Single source of truth: the PgBouncer version is the ARG in the Dockerfile.
                    env.PGB_VERSION = sh(
                        script: "grep -oP '^ARG VERSION=\\K.*' Dockerfile",
                        returnStdout: true
                    ).trim()
                    echo "PgBouncer version from Dockerfile: ${env.PGB_VERSION}"
                }
            }
        }

        stage('Containerize') {
            steps {
                // BuildKit on Greta, push to Harbor with two tags:
                //   :${BUILD_NUMBER}  -> build traceability
                //   :${PGB_VERSION}   -> semver pin so consumers pin a PgBouncer version, not a build
                sh """
/opt/buildkit/ops-buildctl --debug build \\
  --frontend dockerfile.v0 \\
  --local context=. --local dockerfile=. \\
  --output type=image,\\"name=${env.IMAGE}:${env.BUILD_NUMBER},${env.IMAGE}:${env.PGB_VERSION}\\",push=true
"""
            }
        }
    }
}
