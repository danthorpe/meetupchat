require 'open3'
require 'json'

def title(text)
	puts "--- #{text}"
end

def log(text)
	puts "#{text}"
end

def write_buildbox_data(key, value)
  buildbox_data='~/.buildbox/buildbox-data'
  command = "#{buildbox_data} set #{key} #{value} --job '#{ENV['BUILDBOX_JOB_ID']}' --agent-access-token '#{ENV['BUILDBOX_AGENT_ACCESS_TOKEN']}'"
  sh command
end

def read_buildbox_data(key)
  buildbox_data='~/.buildbox/buildbox-data'
  command = "#{buildbox_data} get #{key} --job '#{ENV['BUILDBOX_JOB_ID']}' --agent-access-token '#{ENV['BUILDBOX_AGENT_ACCESS_TOKEN']}'"
  result = false
  Open3.popen3(command) do |stdin, stdout, stderr, wait_thr|
    result = stdout.read
  end
  return result
end

def updateSubmodules
	title("Updating Submodules")
	command = "git submodule update --init --recursive --remote"
	result = system(command)
end

def provideDefaultEnvironmentVariables
	ENV['PROJECT_DIR'] = 'apps/soccer' unless ENV.has_key?('PROJECT_DIR')
	ENV['OUTPUT_DIR'] = 'output' unless ENV.has_key?('OUTPUT_DIR')		
	ENV['ARTIFACT_DIR'] = 'artifacts' unless ENV.has_key?('ARTIFACT_DIR')
	
	ENV['WORKSPACE'] = 'Yakatak' unless ENV.has_key?('WORKSPACE')
	ENV['SDK'] = 'iphonesimulator' unless ENV.has_key?('SDK')
	ENV['CONFIGURATION'] = 'Debug' unless ENV.has_key?('CONFIGURATION')
	ENV['KEYCHAIN'] = 'build' unless ENV.has_key?('KEYCHAIN')		
	ENV['KEYCHAIN_PASSWORD'] = 'Pa$$w0rd' unless ENV.has_key?('KEYCHAIN_PASSWORD')

	ENV['RINSEREPEATBUILD_ARTIFACTS_ROOT'] = '/home/danthorpe/webapps/rrbstatic/a' unless ENV.has_key?('RINSEREPEATBUILD_ARTIFACTS_ROOT')
	ENV['RINSEREPEATBUILD_ARTIFACTS_URL'] = 'https://rinse.repeat.build/a' unless ENV.has_key?('RINSEREPEATBUILD_ARTIFACTS_URL')

  
end

def buildNumber
  return 'latest' unless ENV.has_key?('BUILDBOX_BUILD_NUMBER')
  return ENV['BUILDBOX_BUILD_NUMBER']
end

def projectDirectory
	return "#{Dir.pwd}/#{ENV['PROJECT_DIR']}"
end

def podsRoot
	return "#{projectDirectory()}/Pods"
end

def isDebug()
  return ENV['CONFIGURATION'] == 'Debug'
end

desc 'Configure Environment'
task :configure_env do
	provideDefaultEnvironmentVariables()		
end

namespace :xcode do

	def exportXcodeVersion
		command = "xcodebuild -version"
		sh command
	end
	
	def killSimulator
		command = "killall QUIT iOS\ Simulator"
		result = system(command)
	end
	
	def podsRoot
		return "#{projectDirectory()}/Pods"
	end

	def workspaceArgument
		return "-workspace \"#{ENV['PROJECT_DIR']}/#{ENV['WORKSPACE']}.xcworkspace\""
	end

	def configurationArgument
		return "-configuration #{ENV['CONFIGURATION']}"
	end

	def derivedDataPathArgument
		return "-derivedDataPath #{ENV['OUTPUT_DIR']}"
	end

	def packageApplicationArgument(scheme)
		return "#{Dir.pwd}/#{ENV['OUTPUT_DIR']}/Build/Products/#{ENV['CONFIGURATION']}-iphoneos/#{scheme}.app"	
	end

	def packageOutputArgument
		return "#{Dir.pwd}/#{ENV['ARTIFACT_DIR']}"
	end

	def codeSigningArgument
		return "OTHER_CODE_SIGN_FLAGS=\"--keychain #{ENV['KEYCHAIN']}\""
	end

  def prepareForBuild
  	exportXcodeVersion()  
  	command = "mkdir -p #{ENV['OUTPUT_DIR']}"
  	sh command
  end

  def prepareForArtifacts
  	command = "mkdir -p #{ENV['ARTIFACT_DIR']}"
  	sh command
  end

	def checkPods
		manifest = "#{podsRoot()}/Manifest.lock"
		if File.file? manifest
			title("Updating Cocoapods")
			sh "pod update"
		else
			title("Installing Cocoapods")		
			sh "pod install"
		end
	end

	def unlockKeychain(keychain, password)
		command = "security unlock-keychain -p \"#{password}\" #{keychain}"
		sh command
		command = "security default-keychain -s #{keychain}"
		sh command		
	end

  def pathToBuiltInfoPlist(scheme)
    return "#{packageApplicationArgument(scheme)}/Info.plist"
  end

  def get_bundle_identifier(scheme)
    command = "/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' \"#{pathToBuiltInfoPlist(scheme)}\""
    result = false
    Open3.popen3(command) do |stdin, stdout, stderr, wait_thr|
      result = stdout.read
    end
    return result.chop
  end

  def get_bundle_version(scheme)
    command = "/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' \"#{pathToBuiltInfoPlist(scheme)}\""
    result = false
    Open3.popen3(command) do |stdin, stdout, stderr, wait_thr|
      result = stdout.read
    end
    return result.chop
  end
  
  def write_bundle_identifier(scheme)
    bundle_identifier = get_bundle_identifier(scheme)
    write_buildbox_data('BUNDLE_IDENTIFIER', bundle_identifier)
  end

  def write_bundle_version(scheme)
    bundle_version = get_bundle_version(scheme)
    write_buildbox_data('BUNDLE_VERSION', bundle_version)
  end

  def save_build_variables(scheme)
    if ENV['CI'] && ENV['BUILDBOX']
      write_bundle_identifier(scheme)
      write_bundle_version(scheme)
    end
  end

	def test(scheme)
		command = "xcodebuild #{workspaceArgument()} #{configurationArgument()} -sdk #{ENV['SDK']} -scheme \"#{scheme}\" test | xcpretty -c && exit ${PIPESTATUS[0]}"
		sh command
	end

	def build(scheme, app)
		title("Building #{scheme}")	
		prepareForBuild()
		command = "xcodebuild #{workspaceArgument()} #{configurationArgument()} -sdk iphoneos -scheme \"#{scheme}\" #{derivedDataPathArgument()} clean build #{codeSigningArgument()} | xcpretty -c && exit ${PIPESTATUS[0]}"
		sh command
	end

	def package(scheme, ipa)
		title("Packaging #{scheme}")	
		prepareForArtifacts()
		command = "xcrun -sdk iphoneos PackageApplication -v \"#{packageApplicationArgument(scheme)}\" -o \"#{packageOutputArgument()}/#{ipa}\""
		sh command
	end
		
	desc 'Update Submodules'
	task :update_submodules do
		updateSubmodules()
	end

	desc 'Unlock Keychain'
	task :unlock_keychain do
		title("Unlocking Keychain")		
		unlockKeychain(ENV['KEYCHAIN'], ENV['KEYCHAIN_PASSWORD'])
	end

	desc 'Update Cocoapods'
	task :pods => ['configure_env', 'update_submodules'] do
		Dir.chdir(projectDirectory()) do			
			checkPods()
		end
	end

	namespace :test do

		desc 'Runs all the Unit Tests'
		task :all => ['meetup'] do
		end

		desc 'Meetup Chat'
		task :meetup do
			test('Meetup Chat')
		end

	end

	namespace :build do

		desc 'Build All Application'
		task :all => ['meetup'] do
		end
		
		desc 'Meetup Chat'
		task :meetup => ['unlock_keychain'] do
			build('Meetup Chat', 'Meetup.ipa')
      save_build_variables('Meetup Chat')
		end

	end
	
	namespace :package do
	
		desc 'Package All Applications'
		task :all => ['meetup'] do 
		end

		desc 'Meetup Chat'
		task :meetup => ['build:meetup'] do
			package('Meetup Chat', 'Meetup.ipa')		
		end

	end
		
end


namespace :distribute do

  require 'net/http'
  require 'openssl'

  def application_id
    return ENV['PARSE_APPLICATION_ID']
  end
  
  def rest_api_key
    return ENV['PARSE_REST_API_KEY']
  end
  
  def run_cloud_function(functionName, body)
    title("Will call Parse Cloud function: #{functionName}")      
    https = Net::HTTP.new('api.parse.com', 443)
    https.use_ssl = true
    https.verify_mode = OpenSSL::SSL::VERIFY_NONE
    
    request = Net::HTTP::Post.new("/1/functions/#{functionName}")
    request.add_field('Content-Type', 'application/json')
    request.add_field('X-Parse-Application-Id', "#{application_id()}")
    request.add_field('X-Parse-REST-API-Key', "#{rest_api_key()}")
    request.body = body
    response = https.request(request)
    log("'#{functionName}': [#{response.code}] #{response.message} -> #{response.body()}")

  end

  def project_folder(project)
    return "#{ENV['RINSEREPEATBUILD_ARTIFACTS_ROOT']}/#{project}/"
  end

  def project_url(project)
    return "#{ENV['RINSEREPEATBUILD_ARTIFACTS_URL']}/#{project}/"
  end

  def push_channel_name(bundle_identifier)
    channel_name = bundle_identifier.gsub(".", "_")
    if isDebug()
      channel_name = "beta_" + channel_name
    end
    return channel_name
  end

  def add_build_to_cloud(manifest_url, bundle_identifier, bundle_version, application_name)
    title("Will add build for #{application_name} (#{bundle_version}) to the cloud.")
    params = {}
    params["bundle_identifier"] = bundle_identifier
    params["bundle_version"] = bundle_version
    params["manifest_url"] = manifest_url
    params["isBeta"] = isDebug()
    params['channel_name'] = push_channel_name(bundle_identifier)
    params['application_name'] = application_name
    log("params: #{params.to_json}")
    run_cloud_function("add_build", params.to_json)
  end

  def manifest_template(project)
    template_filename = "#{project_folder(project)}/manifest.plist"
    file = File.open(template_filename, 'rb')
    contents = file.read
    file.close
    return contents
  end

  def generate_manifest(ipa_url, project, bundle_identifier, bundle_version, display_title)
    title("Will generate manifest from template for #{ipa_url}, #{bundle_identifier}, #{bundle_version}, #{display_title}")
    template = manifest_template(project)
    template = template.gsub("PLACEHOLDER_IPA_URL", ipa_url)
    template = template.gsub("PLACEHOLDER_BUNDLE_IDENTIFIER", bundle_identifier)
    template = template.gsub("PLACEHOLDER_BUNDLE_VERSION", bundle_version)
    template = template.gsub("PLACEHOLDER_DISPLAY_TITLE", display_title)
    log(template)    
    return template
  end

  def create_manifest_file(project, build, manifest)
    filename = "#{directory_on_artifact_server(project, build)}manifest.plist"
    title("Will write manifest to #{filename}")
    file = File.open(filename, 'wb') do |file|
      file.write(manifest)
    end
    return "#{url_on_artifact_server(project, build)}manifest.plist"
  end

  def directory_on_artifact_server(project, build)
    return "#{project_folder(project)}#{build}/"
  end
  
  def location_on_artifact_server(ipa, project, build)
    return "#{directory_on_artifact_server(project, build)}/#{ipa}"
  end
  
  def url_on_artifact_server(project, build)
    return "#{project_url(project)}#{build}/"
  end

  def move_artifacts(ipa, project, build)
    title("Moving #{ipa} to the correct location")
    filename = "#{ENV['ARTIFACT_DIR']}/#{ipa}"
    targetDirectory = directory_on_artifact_server(project, build)
    result = "#{targetDirectory}#{ipa}"
    move = "mv #{targetDirectory}#{filename} #{result}"
    sh move
    delete = "rm -rf #{targetDirectory}#{ENV['ARTIFACT_DIR']}"
    sh delete
    return "#{url_on_artifact_server(project, build)}#{ipa}"
  end
  
  def download_artifacts(ipa, project, build)
    filename = "#{ENV['ARTIFACT_DIR']}/#{ipa}"
    targetDirectory = directory_on_artifact_server(project, build)
    title("Download: #{filename} to #{targetDirectory}")
    buildbox_artifact='~/.buildbox/buildbox-artifact'
    job = "'Debug Build'"
    make_dir = "mkdir -p #{targetDirectory}"
    artifact = "#{buildbox_artifact} download #{filename} #{targetDirectory} --job #{job} --build '#{ENV['BUILDBOX_BUILD_ID']}' --agent-access-token '#{ENV['BUILDBOX_AGENT_ACCESS_TOKEN']}'"
    command = "#{make_dir} && #{artifact}"
    sh command
  end
  
	def distribute(ipa, project, build, title)

    download_artifacts(ipa, project, build)
    ipaurl = move_artifacts(ipa, project, build)
    
    bundle_identifier = read_buildbox_data('BUNDLE_IDENTIFIER')
    log("Bundle Identifier: #{bundle_identifier}")
    bundle_version = read_buildbox_data('BUNDLE_VERSION')
    log("Bundle Version: #{bundle_version}")

    if bundle_identifier == false && bundle_version == false
      log("Failed to get the bundle identifier and version from previous build steps.")
      return -1
    end
    manifest = generate_manifest(ipaurl, project, bundle_identifier, bundle_version, title)
    manifest_url = create_manifest_file(project, build, manifest)
    
    add_build_to_cloud(manifest_url, bundle_identifier, bundle_version, title)
	end

	desc 'Distribute All Applications'
	task :beta => ['beta_meetup'] do 
	end

	desc 'Distribute All Applications'
	task :all => ['meetup'] do 
	end

	desc 'Meetup Chat'
	task :meetup => ['configure_env'] do
		distribute('Meetup.ipa', 'ios-london-group/meetup-chat', buildNumber(), 'Meetup Chat')
	end

end


