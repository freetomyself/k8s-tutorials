pipeline {
    agent {
        kubernetes {
            yaml """
apiVersion: v1
kind: Pod
spec:
  containers:
    - name: golang
      image: "${params.BUILD_IMAGE}"
      command: ["cat"]
      tty: true
"""
        }
    }

    options {
        skipDefaultCheckout(true)
    }

    parameters {
        gitParameter(
            name: 'PROJECT_VERSION',
            type: 'PT_TAG',
            tagFilter: '*',
            defaultValue: 'hello-helm-0.1.0',
            selectedValue: 'DEFAULT',
            sortMode: 'DESCENDING_SMART',
            quickFilterEnabled: true,
            useRepository: '.*k8s-tutorials\\.git',
            description: '选择本次构建的 Git tag'
        )

        string(
            name: 'BUILD_IMAGE',
            defaultValue: 'golang:1.16-buster',
            description: 'Go 编译容器镜像，例如 golang:1.16-buster'
        )
    }

    environment {
        // 项目配置
        PROJECT_GIT_URL = 'https://github.com/freetomyself/k8s-tutorials.git'
        GO_SOURCE_DIR = 'helm-charts/hello-helm'
        GO_BINARY_NAME = 'main'

        // 仅用于代理出网预检
        PROXY_URL = 'http://192.168.1.9:7890'

        // 流水线运行时信息
        PROJECT_VERSION = ''
        BUILD_IMAGE = ''
        PIPELINE_STARTED_EPOCH = ''
        BUILD_STARTED_AT = ''
        GIT_VERSION = ''
        GIT_COMMIT = ''
        GO_VERSION = ''
        GO_TARGET = ''
        PROXY_CHECK_RESULT = '尚未执行'
    }

    stages {
        stage('记录构建开始信息') {
            steps {
                script {
                    if (!params.PROJECT_VERSION?.trim()) {
                        error '没有选到 Git tag。请确认仓库已有 tag，并重新打开参数构建页面。'
                    }
                    if (!params.BUILD_IMAGE?.trim()) {
                        error '构建镜像不能为空'
                    }

                    env.PROJECT_VERSION = params.PROJECT_VERSION.trim()
                    env.BUILD_IMAGE = params.BUILD_IMAGE.trim()

                    // 先用局部变量计算时间，避免从 env 中读取到 null。
                    def startEpoch = sh(
                        script: 'date +%s',
                        returnStdout: true
                    ).trim()

                    def startedAt = sh(
                        script: "TZ=Asia/Shanghai date -d '@${startEpoch}' '+%Y-%m-%d %H:%M:%S %Z'",
                        returnStdout: true
                    ).trim()

                    env.PIPELINE_STARTED_EPOCH = startEpoch
                    env.BUILD_STARTED_AT = startedAt

                    currentBuild.displayName =
                        "#${env.BUILD_NUMBER} ${env.PROJECT_VERSION}"

                    currentBuild.description =
                        "项目版本=${env.PROJECT_VERSION} | " +
                        "构建镜像=${env.BUILD_IMAGE} | " +
                        "Agent=${env.NODE_NAME} | " +
                        "开始=${env.BUILD_STARTED_AT}"
                }
            }
        }

        stage('代理出网预检') {
            steps {
                container('golang') {
                    withEnv([
                        "https_proxy=${env.PROXY_URL}",
                        "HTTPS_PROXY=${env.PROXY_URL}"
                    ]) {
                        sh '''
                            set -eu

                            if ! command -v curl >/dev/null 2>&1; then
                                echo '当前构建镜像没有安装 curl，无法执行代理预检'
                                exit 1
                            fi

                            for url in 'https://www.google.com/generate_204' 'https://github.com/'; do
                                if curl --proxy "$HTTPS_PROXY" --noproxy "" \
                                    --fail --silent --show-error --location \
                                    --connect-timeout 5 --max-time 15 \
                                    --output /dev/null "$url"; then
                                    echo "代理出网正常：$url"
                                    exit 0
                                fi
                            done

                            echo '通过代理访问测试站点失败'
                            exit 1
                        '''
                    }
                }
            }

            post {
                success {
                    script {
                        env.PROXY_CHECK_RESULT = '通过'
                    }
                }
                failure {
                    script {
                        env.PROXY_CHECK_RESULT = '失败'
                    }
                }
            }
        }

        stage('检出代码') {
            steps {
                checkout scmGit(
                    branches: [[name: "refs/tags/${params.PROJECT_VERSION}"]],
                    userRemoteConfigs: [[url: env.PROJECT_GIT_URL]]
                )
            }
        }

        stage('记录代码版本信息') {
            steps {
                script {
                    env.GIT_VERSION = sh(
                        script: 'git describe --tags --always',
                        returnStdout: true
                    ).trim()

                    env.GIT_COMMIT = sh(
                        script: 'git rev-parse HEAD',
                        returnStdout: true
                    ).trim()

                    currentBuild.description =
                        "${currentBuild.description} | " +
                        "Git版本=${env.GIT_VERSION} | " +
                        "Commit=${env.GIT_COMMIT}"
                }
            }
        }

        stage('确认项目文件') {
            steps {
                script {
                    if (!fileExists("${env.GO_SOURCE_DIR}/main.go")) {
                        error "没有找到 Go 源码：${env.GO_SOURCE_DIR}/main.go"
                    }

                    echo "已找到 Go 源码：${env.GO_SOURCE_DIR}/main.go"
                }
            }
        }

        stage('编译 Go 程序') {
            steps {
                container('golang') {
                    script {
                        env.GO_VERSION = sh(
                            script: 'go version',
                            returnStdout: true
                        ).trim()

                        env.GO_TARGET = sh(
                            script: 'printf "linux/%s" "$(go env GOARCH)"',
                            returnStdout: true
                        ).trim()

                        currentBuild.description =
                            "${currentBuild.description} | " +
                            "Go=${env.GO_VERSION} | 目标=${env.GO_TARGET}"
                    }

                    dir(env.GO_SOURCE_DIR) {
                        sh '''
                            set -eu

                            if [ -f go.mod ]; then
                                CGO_ENABLED=0 GOOS=linux go build -o "$GO_BINARY_NAME" .
                            else
                                GO111MODULE=off CGO_ENABLED=0 GOOS=linux go build -o "$GO_BINARY_NAME" .
                            fi
                        '''
                    }
                }
            }
        }

        stage('归档构建产物') {
            steps {
                archiveArtifacts(
                    artifacts: "${env.GO_SOURCE_DIR}/${env.GO_BINARY_NAME}",
                    fingerprint: true
                )
            }
        }
    }

    post {
        always {
            script {
                container('golang') {
                    def endEpoch = sh(
                        script: 'date +%s',
                        returnStdout: true
                    ).trim().toLong()

                    def endedAt = sh(
                        script: "TZ=Asia/Shanghai date -d '@${endEpoch}' '+%Y-%m-%d %H:%M:%S %Z'",
                        returnStdout: true
                    ).trim()

                    def savedStartEpoch = env.PIPELINE_STARTED_EPOCH?.trim()
                    def startEpoch = savedStartEpoch
                        ? savedStartEpoch.toLong()
                        : (currentBuild.startTimeInMillis / 1000L) as long

                    def durationSeconds = Math.max(0, endEpoch - startEpoch)

                    def fields = (currentBuild.description ?: '')
                        .replace(' | ', '\n')
                        .readLines()
                        .findAll { it.trim() }

                    fields.add("代理预检=${env.PROXY_CHECK_RESULT}")
                    fields.add("结束=${endedAt}")
                    fields.add("耗时=${durationSeconds}s")
                    fields.add("结果=${currentBuild.currentResult ?: 'SUCCESS'}")
                    fields.add("构建产物=${env.GO_SOURCE_DIR}/${env.GO_BINARY_NAME}")

                    def escapeHtml = { value ->
                        (value ?: '').toString()
                            .replace('&', '&amp;')
                            .replace('<', '&lt;')
                            .replace('>', '&gt;')
                            .replace('"', '&quot;')
                            .replace("'", '&#39;')
                    }

                    currentBuild.description = fields.collect { field ->
                        def separator = field.indexOf('=')
                        def label = separator >= 0
                            ? field.substring(0, separator)
                            : '信息'
                        def value = separator >= 0
                            ? field.substring(separator + 1)
                            : field

                        """<div style="background-color:#e8f5e9;border:1px solid #a5d6a7;border-radius:6px;padding:8px 12px;margin:6px 0;color:#1b5e20;"><strong>${escapeHtml(label)}：</strong>${escapeHtml(value)}</div>"""
                    }.join('')
                }
            }
        }
    }
}
