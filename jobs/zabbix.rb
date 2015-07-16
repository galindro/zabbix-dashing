require "zabbixapi"
require "json"

# :first_in sets how long it takes before the job is first run. In this case, it is run immediately
SCHEDULER.every '1m', :first_in => 0 do |job|
	
	config_file = File.read(Dir.pwd + '/jobs/zabbix-monitor-config.json')
	config_parsed = JSON.parse(config_file)

	#Your template names
	templates = config_parsed['Zabbix']['templates']

	#Your auth token
	auth_token = config_parsed['auth_token']

	#Your Zabbix API configuration
	zbx = ZabbixApi.connect(
		:url => config_parsed['Zabbix']['api_config']['url'],
		:user => config_parsed['Zabbix']['api_config']['user'],
		:password => config_parsed['Zabbix']['api_config']['password']
	)

	zbx_priorities = {
		0 => "ok",
		1 => "nothing",
		2 => "warning",
		3 => "average",
		4 => "high",
		5 => "disaster",
		10 => "acknowledged"
	}

	templateids = []
	application_names = []

	#Get template ids
	template_ids = zbx.query(
		:method => "template.get",
		:params => {
			:filter => {
				:host => templates
			},
			:output => [
				"templateid"
			]
		}
	)

	#Gen list of template ids
	(template_ids).each do |template|
		templateids << template['templateid']
	end

	if not config_parsed['Zabbix'].has_key?('applications_include')
		#Get application names from template ids
		applications = zbx.query(
			:method => "application.get",
			:params => {
				:templated => true,
				:templateids => templateids,
				:output => [
					"name"
				]
			}
		)
	else
		#Get application names from template ids
		applications = zbx.query(
			:method => "application.get",
			:params => {
				:templated => true,
				:templateids => templateids,
				:filter => {
					:name => config_parsed['Zabbix']['applications_include'],
				},
				:output => [
					"name"
				]
			}
		)
	end

	#Gen list of application names
	(applications).each do |application|
		if config_parsed['Zabbix'].has_key?('applications_exclude')
			if config_parsed['Zabbix']['applications_exclude'].include?(application['name'])
				next
			end
		end
		application_names << application['name']
	end

	application_names = application_names.uniq

	(application_names).each do |app_name|

		triggers = []
		items = []
		events = []
		last_priority = 0
		priority = 0
		trigger_name = ""
		trigger_id = ""
		acks = ""

		#Get application ids inherited from templates that is equal to app_name
		application = zbx.query(
			:method => "application.get",
			:params => {
				:inherited => true,
				:filter => {
					:name => app_name,
				},
				:output => [
					"applicationid"
				]
			}
		)

		#Get triggers with state problem where application ids is equal to application[0]['applicationid']
		triggers = zbx.query(
			:method => "trigger.get",
			:params => {
				:filter => {
					:value => 1,
					:status => 0
				},
				:applicationids => [application[0]['applicationid']],
				:output => [
					"description",
					"priority",
					"triggerid"
				]
			}
		)

		#If there are triggers
		if triggers.any?
		
			(triggers).each do |trigger|

				#Get the greater priority
				if trigger['priority'].to_i > last_priority
					priority = trigger['priority'].to_i
					last_priority = priority
					trigger_name = trigger['description']
					trigger_id = trigger['triggerid']
				end

			end

			# Check associated items
			items = zbx.query(
				:method => "item.get",
				:params => {
					:triggerids => trigger_id,
					:webitems => true,
					:filter => {
						:status => 0
					},
					:output => [
						"itemid"
					]
				}
			)

			# Check if the associated items are disabled
			if not items.any?
				priority = 0
			else
				#Get events from trigger with acknowledgedment = yes
				events = zbx.query(
					:method => "event.get",
					:params => {
						:objectids => trigger_id,
						:select_acknowledges => "extend",
						:sortfield => "clock",
						:sortorder => "DESC",
						:limit => 1,
						:filter => {
							:acknowledged => 1
						},
						:output => [
							"eventid"
						]
					}
				)
			end
		end

		#If there are acknowledgedment
		if events.any?
			#Send event to the application widget with ack
			send_event(app_name, { auth_token: auth_token, status: zbx_priorities[10], text: trigger_name })
		else
			#Send event to the application widget without ack
			send_event(app_name, { auth_token: auth_token, status: zbx_priorities[priority], text: trigger_name })
		end

	end

	#Set the array zabbix_widget_names with the application_names that will be used for generate widgets
	set :zabbix_widget_names, application_names

end
