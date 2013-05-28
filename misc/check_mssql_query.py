#!/usr/bin/python

import pynag.Plugins
import pymssql

helper = pynag.Plugins.PluginHelper()


helper.parser.add_option('--host', help="MSSQL Server to connect to", dest="host")
helper.parser.add_option('--username', help="MSSQL Username to connect with", dest="username")
helper.parser.add_option('--password', help="MSSQL Server to connect to", dest="password")
helper.parser.add_option('--database', help="MSSQL Database", dest="database")
helper.parser.add_option('--query', help="MSSQL Query to execute", dest="query")

# When parse_arguments is called some default options like --threshold and --no-longoutput are automatically added
helper.parse_arguments()


host = helper.options.host
username = helper.options.username
password = helper.options.password
database = helper.options.database
query = helper.options.query
#enable_debugging = helper.options.debug
enable_debugging = helper.options.verbose

def debug(message):
  if enable_debugging:
    print "debug: %s" % str(message)

  
if not host:
  helper.parser.error('--host is required')
if not username:
  helper.parser.error('--username is required')
if not password:
  helper.parser.error('--password is required')
if not database:
  helper.parser.error('--database is required')



# Actual coding logic starts

conn = pymssql.connect(host=host, user=username, password=password, database=database)
debug("connecting to host")
cur = conn.cursor()
debug("Executing sql query: %s" % query)
cur.execute(query)

status,text = None,None
for row in cur:
  debug(row)
  status, text = row[0], row[1]
  if text == '':
    text = "No text in this field"
  if status not in pynag.Plugins.state_text:
    helper.add_summary("Invalid status: %s" % status)
    status = pynag.Plugins.unknown

  helper.status(status)
  helper.add_long_output("%s: %s" % (pynag.Plugins.state_text.get(status,'unknown'), text) )
  

if not helper.get_summary():
  if not text:
    helper.add_summary("Hey! Af hverju er enginn texti?")
  else: 
    helper.add_summary(text)

helper.check_all_metrics()
helper.exit()
