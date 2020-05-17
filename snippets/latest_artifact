def artifactoryBaseUrl = ARTIFACTORY_URL
def repository = REPO_NAME
def folder_path = FOLDER
def name_parts = env.BRANCH_NAME.split("-|/", 2) (feature/sample)
def branchType = name_parts[0]
def latestArtifact = sh(script: """
	curl -X POST -H "Content-Type: text/plain" -k -u '${artifactory_user}:${
			artifactory_password
		}' ${artifactoryBaseUrl}/api/search/aql -d 'items.find({"repo":{"\$eq":"${
			repository
		}"}, "path":{"\$match": "*/${folder_path}/*"}}).sort({"\$desc" : ["repo","created"]}).limit(1)'
	""", returnStdout: true)
def queryReply = readJSON text: latestArtifact
def latestArtifactPath = queryReply["results"][0]["path"]
int last_slash = latestArtifactPath.lastIndexOf('/')
def latestVersion = latestArtifactPath.substring(last_slash + 1)
