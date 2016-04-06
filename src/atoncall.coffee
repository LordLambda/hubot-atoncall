# Description:
#   Listens for @oncall, and grabs the oncall person for the configured service.
#
# Dependencies:
#   None :magic:
#
# Configuration:
#   HUBOT_PAGERDUTY_SUBDOMAIN
#   HUBOT_PAGERDUTY_API_KEY
#   HUBOT_ONCALL_SERVICE
#   HUBOT_SLACK_TOKEN (Optional)
#
# Commands:
#   @on-?call - Grabs the current user oncall
#   hubot clear oncall cache - Clears the on call cache.
#
# Author:
#   Eric <ecoan@instructure.com>

pagerDutySubdomain = process.env.HUBOT_PAGERDUTY_SUBDOMAIN
pagerDutyApiKey = process.env.HUBOT_PAGERDUTY_API_KEY
slackToken = process.env.HUBOT_SLACK_TOKEN
pagerDutyBaseUrl = "https://#{pagerDutySubdomain}.pagerduty.com/api/v1/"

serviceToCheck = process.env.HUBOT_ONCALL_SERVICE

cache = null

module.exports = (robot) ->

  getUserNameFromEmail = (email, cb) ->
    if cache == null
      console.log cache
      if slackToken
        robot.http("https://slack.com/api/users.list?token=#{slackToken}")
          .get() (err, res, body) ->
            if err
              console.log "Calling Slack API Errord: #{err}"
              return null
            console.log body
            json = JSON.parse body
            console.log json
            userMap = {}
            userMap[member.profile.email] = member.name for member in json.members

            cache = userMap
            slackId = cache[email]
            console.log cache
            console.log slackId
            unless slackId
              slackId = null
            cb slackId
      else
        cb null
     else
       if cache == null
         return cb null
       userName = cache[email]
       unless userName
         userName = null
       cb userName

  missingEnvironmentForApi = (msg) ->
    missingAnything = false
    unless pagerDutySubdomain?
      msg.send "PagerDuty Subdomain is missing:  Ensure that HUBOT_PAGERDUTY_SUBDOMAIN is set."
      missingAnything |= true
    unless pagerDutyApiKey?
      msg.send "PagerDuty API Key is missing:  Ensure that HUBOT_PAGERDUTY_API_KEY is set."
      missingAnything |= true
    missingAnything

  pagerDutyGet = (msg, url, query, cb) ->
    if missingEnvironmentForApi(msg)
      return

    auth = "Token token=#{pagerDutyApiKey}"
    msg.http(pagerDutyBaseUrl + url).query(query)
      .headers(Authorization: auth, Accept: 'application/json')
      .get() (err, res, body) ->
        json_body = null
        if res.statusCode == 200
          json_body = JSON.parse(body)
        else
          console.log res.statusCode
          console.log body
          json_body = null
        cb json_body

  robot.hear /@on-?call/i, (msg) ->
    pagerDutyGet msg, "escalation_policies/on_call", {}, (json) ->
      unless json
        msg.send "Can't determine who's on call right now. 😞"
      escalationPolicyIndex = -1
      i = 0
      while i < json.escalation_policies.length
        escalationPolicy = json.escalation_policies[i]
        for service in escalationPolicy.services
          if service.name == serviceToCheck
            escalationPolicyIndex = i
        ++i
      for person in json.escalation_policies[escalationPolicyIndex].on_call
        if person.level == 1
          primaryOnCall = person

      if primaryOnCall
        getUserNameFromEmail primaryOnCall.user.email, (userName) ->
          if userName
            msg.send "@#{userName} ^^^^"
          else
            msg.send "#{primaryOnCall.user.name} ^^^^"
      else
        msg.send "Couldn't find any people in the project. :sadthethings:"

  robot.respond /clear on-?call cache/i, (msg) ->
    cache = null
    msg.send "Cleared. I'll refetch on the next request."
