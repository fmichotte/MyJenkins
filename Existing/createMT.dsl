import groovy.json.JsonOutput

node {
    stage('Get ticket data') {
        withEnv(['JIRA_SITE=Jira-prod']) {
            def response = jiraGetIssue idOrKey: env.TICKET
            def ticket = response.data.fields

            ticket.issuelinks.each{ link ->
                if (link.inwardIssue && link.inwardIssue.fields.issuetype.name == 'Test') {
                    def linkTicket = jiraGetIssue idOrKey: link.inwardIssue.key
                    linkTicket.data.fields.components.find{ c -> c.id == '11651' } && error("Manual ticket already exists")
                }
            }

            def prefix = ticket.issuetype.name == 'Bug' ? 'Validate ' + env.TICKET + ' ' : '[MT] '

            def components = [[id: '11651']]
            
            def teleroute = ticket.components.find{ v -> v.name == 'teleroute' }
            teleroute && components << teleroute.subMap('id')

            def spotbidding = ticket.components.find{ v -> v.name == 'spotbidding' }
            spotbidding && components << spotbidding.subMap('id')

            def testIssue = [
                    fields: [
                            project          : [key: 'FX'],
                            summary          : prefix + ticket.summary,
                            description      : ticket.description ?: '',
                            priority         : [id: ticket.priority.id],
                            versions         : ticket.versions,
                            fixVersions      : ticket.fixVersions,
                            issuetype        : [name: 'Test'],
                            components       : components,
                            customfield_10442: ticket.customfield_10442,
                            labels           : ticket.labels,
                            environment      : ticket.environment ?: ''
                    ]
            ]

            response = jiraNewIssue issue: testIssue, auditLog: false

            echo response.successful.toString()
            echo response.data.toString()

            jiraAssignIssue idOrKey: response.data.key, userName: 'v.malova-zbyr'
            jiraLinkIssues type: 'is tested by', inwardKey: response.data.key, outwardKey: env.TICKET
        }
    }
}