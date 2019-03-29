import groovy.json.JsonOutput

node {
    stage('Get ticket data') {
        withEnv(['JIRA_SITE=Jira-prod']) {
            def response = jiraGetIssue idOrKey: env.TICKET
            def ticket = response.data.fields

            def components = [[id: '11652']]
            
            def teleroute = ticket.components.find{ v -> v.name == 'teleroute' }
            teleroute && components << teleroute.subMap('id')

            def spotbidding = ticket.components.find{ v -> v.name == 'spotbidding' }
            spotbidding && components << spotbidding.subMap('id')

            def testIssue = [
                    fields: [
                            project          : [key: 'FX'],
                            summary          : '[AT]' + ticket.summary.minus('[MT]').minus('Validate'),
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

            ticket.issuelinks.each{ link ->
                if (link.inwardIssue) {
                    jiraLinkIssues type: 'is tested by', inwardKey: response.data.key, outwardKey: link.inwardIssue.key
                }
            }
            jiraLinkIssues type: 'is tested by', inwardKey: response.data.key, outwardKey: env.TICKET
        }
    }
}