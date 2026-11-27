pipeline {
    agent {
        kubernetes {
            yaml """
apiVersion: v1
kind: Pod
spec:
  containers:
    - name: golang
      image: "${params.BUILD_IMAGE?.trim() ?: 'golang:1.16-buster'}"
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
            description: 'Go 编译容器镜像'
        )

        string(
            name: 'PROJECT_GIT_URL',
            defaultValue: 'https://github.com/freetomyself/k8s-tutorials.git',
            description: '项目 Git 仓库地址'
        )

        booleanParam(
            name: 'USE_PROXY',
            defaultValue: false,
            description: '选中后，流水线步骤使用代理'
        )

        string(
            name: 'PROXY_URL',
            defaultValue: 'http://192.168.1.9:7890',
            description: '代理地址；仅勾选 USE_PROXY 时使用'
        )

        string(
            name: 'GO_SOURCE_DIR',
            defaultValue: 'helm-charts/hello-helm',
            description: '包含 main.go 的 Go 源码目录'
        )

        string(
            name: 'GO_BINARY_NAME',
            defaultValue: 'main',
            description: '编译生成的二进制文件名'
        )
    }

    environment {
        PROJECT_VERSION = "${params.PROJECT_VERSION?.trim() ?: 'hello-helm-0.1.0'}"
        BUILD_IMAGE = "${params.BUILD_IMAGE?.trim() ?: 'golang:1.16-buster'}"
        PROJECT_GIT_URL = "${params.PROJECT_GIT_URL?.trim() ?: 'https://github.com/freetomyself/k8s-tutorials.git'}"
        PROXY_URL = "${params.PROXY_URL?.trim() ?: 'http://192.168.1.9:7890'}"
        GO_SOURCE_DIR = "${params.GO_SOURCE_DIR?.trim() ?: 'helm-charts/hello-helm'}"
        GO_BINARY_NAME = "${params.GO_BINARY_NAME?.trim() ?: 'main'}"

        HTTP_PROXY = "${params.USE_PROXY ? (params.PROXY_URL?.trim() ?: 'http://192.168.1.9:7890') : ''}"
        HTTPS_PROXY = "${params.USE_PROXY ? (params.PROXY_URL?.trim() ?: 'http://192.168.1.9:7890') : ''}"
        http_proxy = "${params.USE_PROXY ? (params.PROXY_URL?.trim() ?: 'http://192.168.1.9:7890') : ''}"
        https_proxy = "${params.USE_PROXY ? (params.PROXY_URL?.trim() ?: 'http://192.168.1.9:7890') : ''}"
        ALL_PROXY = "${params.USE_PROXY ? (params.PROXY_URL?.trim() ?: 'http://192.168.1.9:7890') : ''}"
        all_proxy = "${params.USE_PROXY ? (params.PROXY_URL?.trim() ?: 'http://192.168.1.9:7890') : ''}"
        NO_PROXY = ''
        no_proxy = ''
    }

    stages {
        stage('记录构建开始信息') {
            steps {
                script {
                    if (!env.PROJECT_VERSION?.trim()) {
                        error '没有选到 Git tag'
                    }

                    def startEpoch =
                        (currentBuild.startTimeInMillis / 1000L) as long

                    def startedAt = sh(
                        script: "TZ=Asia/Shanghai date -d '@${startEpoch}' '+%Y-%m-%d %H:%M:%S %Z'",
                        returnStdout: true
                    ).trim()

                    def proxyDescription = params.USE_PROXY
                        ? env.PROXY_URL
                        : '未启用'

                    currentBuild.displayName =
                        "#${env.BUILD_NUMBER} ${env.PROJECT_VERSION}"

                    currentBuild.description =
                        "项目版本=${env.PROJECT_VERSION} | " +
                        "构建镜像=${env.BUILD_IMAGE} | " +
                        "仓库=${env.PROJECT_GIT_URL} | " +
                        "代理=${proxyDescription} | " +
                        "Agent=${env.NODE_NAME} | " +
                        "开始=${startedAt}"
                }
            }
        }

        stage('代理出网预检') {
            steps {
                script {
                    if (params.USE_PROXY) {
                        container('golang') {
                            sh '''
                                set -eu

                                if ! command -v curl >/dev/null 2>&1; then
                                    echo '当前构建镜像没有安装 curl，无法执行代理预检'
                                    exit 1
                                fi

                                for url in 'https://www.google.com/generate_204' 'https://github.com/'; do
                                    if curl --proxy "$PROXY_URL" --noproxy "" \
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
                    } else {
                        echo '未启用代理，跳过代理出网预检'
                    }
                }
            }

            post {
                success {
                    script {
                        def status = params.USE_PROXY ? '通过' : '已跳过'
                        currentBuild.description =
                            "${currentBuild.description} | 代理预检=${status}"
                    }
                }
                failure {
                    script {
                        currentBuild.description =
                            "${currentBuild.description} | 代理预检=失败"
                    }
                }
            }
        }

        stage('检出所选版本') {
            steps {
                checkout scmGit(
                    branches: [[name: "refs/tags/${env.PROJECT_VERSION}"]],
                    userRemoteConfigs: [[url: env.PROJECT_GIT_URL]]
                )
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
                        def goVersion = sh(
                            script: 'go version',
                            returnStdout: true
                        ).trim()

                        currentBuild.description =
                            "${currentBuild.description} | Go=${goVersion}"
                    }

                    dir(env.GO_SOURCE_DIR) {
                        sh '''
                            set -eu

                            if [ -f go.mod ]; then
                                CGO_ENABLED=0 GOOS=linux \
                                    go build -o "$GO_BINARY_NAME" .
                            else
                                GO111MODULE=off CGO_ENABLED=0 GOOS=linux \
                                    go build -o "$GO_BINARY_NAME" .
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

                    def startEpoch =
                        (currentBuild.startTimeInMillis / 1000L) as long
                    def durationSeconds = Math.max(0, endEpoch - startEpoch)

                    def info = [:]
                    (currentBuild.description ?: '')
                        .replace(' | ', '\n')
                        .readLines()
                        .each { field ->
                            def separator = field.indexOf('=')
                            if (separator > 0) {
                                def label = field.substring(0, separator)
                                def value = field.substring(separator + 1)
                                info[label] = value
                            }
                        }

                    def escapeHtml = { value ->
                        (value ?: '').toString()
                            .replace('&', '&amp;')
                            .replace('<', '&lt;')
                            .replace('>', '&gt;')
                            .replace('"', '&quot;')
                            .replace("'", '&#39;')
                    }

                    def repository = info['仓库'] ?: '未知'
                    def repositoryEscaped = escapeHtml(repository)
                    def repositoryHtml = repository ==~ /^https?:\/\/.+/
                        ? """<a href="${repositoryEscaped}">${repositoryEscaped}</a>"""
                        : repositoryEscaped

                    def rows = [
                        [
                            ['项目版本', info['项目版本'] ?: '未知'],
                            ['构建镜像', info['构建镜像'] ?: '未知']
                        ],
                        [
                            ['仓库', repository]
                        ],
                        [
                            ['代理', info['代理'] ?: '未启用'],
                            ['代理预检', info['代理预检'] ?: '未执行']
                        ],
                        [
                            ['环境', info['Go'] ?: '未编译']
                        ],
                        [
                            ['结果', currentBuild.currentResult ?: 'SUCCESS'],
                            ['开始', info['开始'] ?: '未知'],
                            ['结束', endedAt],
                            ['耗时', "${durationSeconds}s"]
                        ],
                        [
                            ['构建产物', "${env.GO_SOURCE_DIR}/${env.GO_BINARY_NAME}"]
                        ]
                    ]

                    currentBuild.description = rows.collect { row ->
                        def contents = row.collect { item ->
                            def label = item[0]
                            def value = item[1]

                            def renderedValue = label == '仓库'
                                ? repositoryHtml
                                : escapeHtml(value)

                            "<strong>${escapeHtml(label)}：</strong>${renderedValue}"
                        }.join(' &nbsp; - &nbsp; ')

                        """<div style="background-color:#e8f5e9;border:1px solid #a5d6a7;border-radius:6px;padding:8px 12px;margin:6px 0;color:#1b5e20;max-width:100%;box-sizing:border-box;white-space:normal;overflow-wrap:anywhere;word-break:break-word;">${contents}</div>"""
                    }.join('')
                }
            }
        }
    }
}
