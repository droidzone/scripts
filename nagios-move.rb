#!/usr/bin/env ruby
#
# Move all nagios messages to nagios_history
#
# Jay Scott 2012
#
require 'net/imap'


# START CONFIG

NAME = ''
HOST = ''
PORT = 993
SSL  = true
USER = ''
PASS = ''
TARGET_MAILBOX = 'Nagios/Nagios-History'

# END CONFIG


# Print Message
def pp(message)
   puts "[#{NAME}] #{message}"
end

def moveMail(imap, folder)

  pp "Moving #{folder} to #{TARGET_MAILBOX}"
  
  message_ids = imap.uid_search("ALL")
  imap.uid_store(message_ids, "+FLAGS", [:Seen])
  imap.uid_copy(message_ids, "#{TARGET_MAILBOX}")
  imap.uid_store(message_ids, "+FLAGS", [:Deleted])
  imap.expunge
  
end

# Connect
pp 'Connecting...'
imap = Net::IMAP.new(HOST, PORT, SSL)
pp 'Logging in...'
imap.login(USER, PASS)

FLIST = imap.list("", "Nagios/%")

FLIST.each do |ff|
  
  folder = ff["name"]
  if folder == "#{TARGET_MAILBOX}"
    next
  end
  
  imap.select(folder)
 
  fsize = imap.status(folder, ["MESSAGES"])
  
  if not fsize["MESSAGES"] == 0
    pp "#{folder} has #{fsize["MESSAGES"]} messages..."
    moveMail(imap, folder)
  else
    pp "#{folder} has #{fsize["MESSAGES"]} messages...skipping"
  end
end


