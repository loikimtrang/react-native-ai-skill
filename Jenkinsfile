_BUILD_NUMBER = env.BUILD_NUMBER
_BRANCH_NAME = env.BRANCH_NAME

TIMEZONE = "GMT+7"
APP_BOOT_TIME_SECOND = 5
SLACK_CHANNEL_NAME = "GMQ6JQ1FT"

APP_NAME="react-native"
TARTGET_FOLDER_DEPLOY="/opt/data/_techstacks/stacks"

HOST_DEPLOY="192.168.201.12"
CREDENTIAL_ID="ssh_credentials"

TAR_FILE_NAME="ios.tar.gz"

node{
    try {
        if (_BRANCH_NAME.matches("dev")) {
            HOST_DEPLOY="192.168.201.12"
            CREDENTIAL_ID="ssh_credentials"
            build()
        }else if (_BRANCH_NAME.matches("master")) {
            HOST_DEPLOY="192.168.0.18"
            CREDENTIAL_ID="ssh_credentials_ilms"
            build()
        } 

        currentBuild.result = "SUCCESS"
    } catch (e) {
        currentBuild.result = "FAILURE"
        throw e
    } finally {
        def time = formatMilisecondTime(currentBuild.timeInMillis, TIMEZONE)
        def duration = durationFormat(currentBuild.duration)
        def buildDetail = "\n————————————————————" +
                          "\n*Build Time:* ${time}" +
                          "\n*Duration:* ${duration}" +
                          "\n*Change Log (DESC):*\n${getChangeLog()}"

        notifyBuild(currentBuild.result, SLACK_CHANNEL_NAME, buildDetail)
    }

}

def build(){
    notifyBuild("STARTED", SLACK_CHANNEL_NAME)

    stage ("Checkout source") {
        checkout scm
    }

    BUILD_COMMAND = """
                        tar  --exclude=${TAR_FILE_NAME}  --exclude=Jenkinsfile  --exclude=.gitignore -czf /tmp/${TAR_FILE_NAME} .
                    """
    stage ("Build source") {
        sh """
            ${BUILD_COMMAND}
        """
    }

    stage("Upload to remote") {

        def remote = [:]
        remote.name = "Server"
        remote.host = HOST_DEPLOY
        remote.allowAnyHosts = true

        withCredentials([sshUserPrivateKey(credentialsId: "${CREDENTIAL_ID}", keyFileVariable: 'identity', passphraseVariable: '', usernameVariable: 'userName')]) {
            remote.user = userName
            remote.identityFile = identity

            try {
                // Delete old data
                sshRemove remote: remote, path: "${TARTGET_FOLDER_DEPLOY}/${APP_NAME}"

            } catch (e) {

            }
            
            // Tao folder target neu chua tao
            sshCommand remote: remote, command: "mkdir -p ${TARTGET_FOLDER_DEPLOY}/${APP_NAME}"

            // Upload source len remote
            sshPut remote: remote, from: "/tmp/${TAR_FILE_NAME}", into: "${TARTGET_FOLDER_DEPLOY}/${APP_NAME}"
            sshCommand remote: remote, command: "cd ${TARTGET_FOLDER_DEPLOY}/${APP_NAME} && tar -xzf ${TAR_FILE_NAME}"
            sshRemove remote: remote, path: "${TARTGET_FOLDER_DEPLOY}/${APP_NAME}/${TAR_FILE_NAME}"
        }

        sh "rm -rf /tmp/${TAR_FILE_NAME}"
        
    }
}

// ================================
// HELPER FUNCTION
// ================================

def notifyEnv(String message = "",String channelName) {
    def colorName = "good"
    def emoji = ":white_check_mark:"
    
    def text = "${emoji} ${message}"
    slackSend (channel: channelName, failOnError: true, color: colorName, message: text)
}

def notifyBuild(String buildStatus, String channelName, String message = "") {
    def colorName = ""
    def emoji = ""
    if (buildStatus == "STARTED") {
        colorName = "#2196f3"
        emoji = ":fast_forward:"
    } else if (buildStatus == "SUCCESS") {
        colorName = "good"
        emoji = ":white_check_mark:"
    } else {
        colorName = "#dc3545"
        emoji = ":x:"
    }

    def text = "${emoji} ${buildStatus}: Job <${env.BUILD_URL}/console|${env.JOB_NAME} - build ${env.BUILD_NUMBER}>"
    if (!message.isEmpty()) {
        // concat a Combining Grapheme Joiner character U+034F before special character to prevent markdown formatting
        // [char] => U+034F [char]
        // reference: https://en.wikipedia.org/wiki/Combining_Grapheme_Joiner
        text += message.replaceAll("`", "͏`")
    }

    slackSend (channel: channelName, failOnError: true, color: colorName, message: text)
}

def getChangeLog() {
    def changeLogSets = currentBuild.changeSets
    if (changeLogSets.isEmpty()) {
        return "    (No changes)"
    }

    def text = ""
    for (int i = changeLogSets.size() - 1; i >= 0; i--) {
        for (def entry in changeLogSets[i].items) {
            text += ":white_small_square: ${entry.author} - ${entry.msg}\n"
        }
    }
    return text
}

def formatMilisecondTime(timeInMillis, timeZone) {
    return new Date(timeInMillis).format("MMM dd, yyyy HH:mm:ss", TimeZone.getTimeZone(timeZone))
}

def durationFormat(long milisecond) {
    def min = milisecond.intdiv(1000).intdiv(60)
    def sec = milisecond.intdiv(1000) % 60
    def result = (min > 0 ? "${min}m " : "") + (sec > 0 ? "${sec}s" : "")
    return result
}