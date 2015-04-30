class Dashing.Text extends Dashing.Widget
  onData: (data) ->
    if data.status
      # clear existing "zabbix-*" classes
      $(@get('node')).attr 'class', (i,c) ->
        c.replace /\bzabbix-\S+/g, ''
      # add new class
      $(@get('node')).addClass "zabbix-#{data.status}"