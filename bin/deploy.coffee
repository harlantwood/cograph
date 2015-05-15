require 'shelljs/global'
util = require 'util'

APP = process.argv[2] ? throw new Error('Usage: bin/deploy <heroku app name>')
DEPLOY_BRANCH = 'deploy-temp'

CommandFailedError = (command, output, code) ->
  Error.captureStackTrace this, this.constructor
  this.name = this.constructor.name
  this.command = command
  this.output = output
  this.code = code
util.inherits CommandFailedError, Error

run = (cmd, options = {}) ->
  continue_on_failure = options.continue_on_failure ? false
  echo "==> #{cmd}"
  {code, output} = exec cmd
  if code isnt 0 and not continue_on_failure
    throw new CommandFailedError cmd, output, code
  {code, output}

@old_branch = null
@result = null

try
  @old_branch = run("git rev-parse --abbrev-ref HEAD").output.trim()
  run "git branch -D #{DEPLOY_BRANCH}", continue_on_failure: true
  run "git checkout -b #{DEPLOY_BRANCH}"
  run "bin/compile"
  # run "git add --force --no-ignore-removal ."
  run "git add ."
  run "git commit -a -m 'deploy'"
  run "heroku maintenance:on --app #{APP}"
  @result = run("git push --force git@heroku.com:#{APP}.git HEAD:master", continue_on_failure: true).code
  run "heroku maintenance:off --app #{APP}"
catch error
  if error instanceof CommandFailedError
    console.error "COMMAND FAILED"
    @result = error.code
  else
    throw error
finally
  run "git checkout --force #{@old_branch}", continue_on_failure: true
  run "git branch -D #{DEPLOY_BRANCH}", continue_on_failure: true
exit @result
