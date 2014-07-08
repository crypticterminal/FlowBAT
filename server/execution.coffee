Process = Npm.require("child_process")

share.Queries.after.update (userId, query, fieldNames, modifier, options) ->
  if not userId # fixtures
    return
  if not query.stale or not query.string
    return
  user = Meteor.users.findOne(userId)
  rwfilterArguments = query.string.split(" ")
  rwfilterArguments.push("--pass=stdout")
  command = "rwfilter --site-config-file=/usr/local/etc/silk.conf " + rwfilterArguments.join(" ")
  if query.sortField
    rwsortArguments = ["--fields=" + query.sortField]
    if query.sortReverse
      rwsortArguments.push("--reverse")
    command += " | " + "rwsort " + rwsortArguments.join(" ")
  rwcutArguments = ["--num-recs=" + user.profile.numRecs, "--start-rec-num=" + query.startRecNum, "--delimited"]
  command += " | " + "rwcut " + rwcutArguments.join(" ")
  config = share.Configs.findOne()
  if config.isSSH
    identityFile = process.env.PWD + "/settings/identity"
    command = "ssh -i " + identityFile + " "+ config.user + "@" + config.host + " \"" + command + "\""
    cl process.env.PWD
    cl command
  Process.exec(command, Meteor.bindEnvironment((err, stdout, stderr) ->
    result = stdout.trim()
    error = stderr.trim()
    code = if err then err.code else 0
    if error is "rwfilter: Error writing to stream 'stdout': Broken pipe"
      # rwcut closes stdin after reading first --num-recs records
      error = ""
      code = 0
    share.Queries.update(query._id, {$set: {result: result, error: error, code: code, stale: false}})
  ))
