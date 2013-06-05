#!/usr/bin/python

import pynag.Plugins
import cx_Oracle

helper = pynag.Plugins.PluginHelper()


helper.parser.add_option('--username', help="Username to the database", dest="username")
helper.parser.add_option('--password', help="Log in with this password", dest="password")
helper.parser.add_option('--tns', help="TNS name to use", dest="tns")
helper.parser.add_option('--query', help="MSSQL Query to execute", dest="query")
helper.parser.add_option('--oracle_home', help="Set $ORACLE_HOME to this", dest="oracle_home")

# When parse_arguments is called some default options like --threshold and --no-longoutput are automatically added
helper.parse_arguments()


username = helper.options.username
password = helper.options.password
tns = helper.options.tns
query = helper.options.query

enable_debugging = helper.options.verbose

def debug(message):
  if enable_debugging:
    print "debug: %s" % str(message)

  
if not username:
  helper.parser.error('--username is required')
if not password:
  helper.parser.error('--password is required')
if not tns:
  helper.parser.error('--tns is required')
#if not oracle_home is None:





# Actual coding logic starts

conn = cx_Oracle.connect(username, password, tns)
debug("connecting to host")
cur = conn.cursor()
debug("Executing sql query: %s" % query)
cur.execute(query)

status,text = None,None
problem_items = 0
total_items = 0
for row in cur:
  total_items += 1
  debug(row)
  if len(row) > 0:
    status = row[0]
  if len(row) > 1:
    text = row[1]
  else:
    text = ""
  if text == '':
    text = "No text in this field"
  if status not in pynag.Plugins.state_text:
    helper.add_summary("Invalid status: %s" % status)
    status = pynag.Plugins.unknown
  if status > 0:
    problem_items += 1
    helper.add_summary(text)

  helper.status(status)
  helper.add_long_output("%s: %s" % (pynag.Plugins.state_text.get(status,'unknown'), text) )
  
if total_items == 0:
  helper.add_summary("SQL Query returned 0 rows")
  helper.status(pynag.Plugins.unknown)
if not helper.get_summary():
  helper.add_summary("%s items checked. %s problems" % (total_items, problem_items))

helper.check_all_metrics()
helper.exit()
