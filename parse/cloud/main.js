
Parse.Cloud.define("add_build", function(request, response) {
    var manifest_url = request.params.manifest_url
    var bundle_identifier = request.params.bundle_identifier
    var bundle_version = request.params.bundle_version
    var isBeta = request.params.isBeta
    var application_name = request.params.application_name
    var channel_name = request.params.channel_name
    
    var Build = Parse.Object.extend("Build")
    var build = new Build()
    build.set("bundle_identifier", bundle_identifier)
    build.set("bundle_version", bundle_version)
    build.set("isBeta", isBeta)
    build.set("url", manifest_url)
    build.set("application_name", application_name)

    build.save(null, {
        success: function(build) {

            Parse.Push.send({
                channels: [ channel_name ],
                data: {
                    alert: "There is a new build of " + build.get("application_name"),
                    'rrb': { 'url': manifest_url}
                }
            }, {
                success: function() {
                    response.success("Sent push to channel: " + channel_name);
                },
                error: function(error) {
                    response.failed("Failed to send push to channel: " + channel_name + " error: " + error.message);
                }
            })
        },
        error: function(build, error) {
            response.success("Failed to save build: " + build + " error: " + error);
        }
    })
})
