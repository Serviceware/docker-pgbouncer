// pipeline {
//     agent any

//     triggers {
//         bitbucketPush()
//     }

//     stages {
//         stage('Containerize') {
//             steps {
//                 sh '''
// /opt/buildkit/ops-buildctl --debug build \
// 	--frontend dockerfile.v0 --local context=. --local dockerfile=. \
// 	--output type=image,name="docker-registry.services.sabio.de/serviceware-ops/pgbouncer:latest,push=true"
// '''
//             }
//         }
//     }
// }
