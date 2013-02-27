fs = require 'fs'
http = require 'http'
crypto = require 'crypto'
home = process.env['HOME']

require.extensions[".json"] = (m) ->
    m.exports = JSON.parse fs.readFileSync m.filename

config = require "#{home}/.mailgunner/config.json"

config.appId ||= 20207

# Run this file using the following syntax
# node mailgunner path_to_test_file.html [recipient@gmail.com]

unless config.apikey and config.portalId and config.appId
    throw "Set your api key and portalId in ./config.json"

args = process.argv
switch args.length
    when 1, 2
        return console.log('Incorrect number of arguments')
    when 3
        path = args[2]
        recipients = config.recipients
    when 4
        recipients = args[3]

sendIt = (emailBody, subject) ->
    options =
      hostname: 'api.hubapi.com'
      port: 80
      path: "/email/v1/messages?portalId=#{config.portalId}&hapikey=#{config.apikey}"
      method: 'POST'
      headers:
        'Content-Type': 'application/json'

    for email in recipients
      payload =
        message:
          id:
            sendId: crypto.randomBytes(16).toString('base64')
            to: email
            portalId: ~~config.portalId
            subscriptionId: 1
            appId: ~~config.appId
          to: [email]
          from: config.sender
          subject: subject
          html: emailBody

      json = JSON.stringify(payload)
      options.headers['Content-Length'] = json.length

      req = http.request options, (res) ->
        do (email) ->
          res.setEncoding 'utf8'
          responseText = ""
          res.on 'data', (chunk) -> responseText += chunk
          res.on 'end', ->
            if res.statusCode > 299
              console.log "Error #{responseText}"
            else
              console.log "Sent email with status code #{res.statusCode} to #{email}"

      req.write(json)
      req.end()

# Send urls
if path.substring(0, 4).toLowerCase() is 'http'
    request path, (err, response, body) ->
        subject = "#{path} #{config.subject}"

        # Add a <base> tag to get all the assets
        closingHead = "</head>"
        baseTag = "<base href='#{path}'>"
        # I'm not proud of this solution
        rebasedBody = body.replace closingHead, "#{baseTag}#{closingHead}"

        sendIt rebasedBody, subject

# Send local files
else
    if path.charAt(0) isnt '/'
        path = process.cwd() + '/' + path

    filename = path.split('/').slice(-1)
    subject = "#{filename} #{config.subject}"
    fs.readFile path, 'utf8', (err, contents) ->
        sendIt contents, subject
