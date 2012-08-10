#!/usr/bin/env ruby

# My work generates an silly amount of emails, I wrote this script to do
# various functions such as deleting, marking, counting and watching folders to
# make things more efficient and minimal. 
#
# Usage: ruby cleanmail.rb 
#    -d, --delete               Delete all emails.
#    -m, --marked               Mark all email as read.
#    -c, --count                Count folder messages [default].
#    -l, --list                 List all IMAP folders.
#    -w, --watch [OPT]          Watch the [OPT] folder for email.
#
#
#
# Jay Scott <jay@jayscott.co.uk>
#

require 'net/imap'
require 'optparse'

### START CONFIG

# IMAP settings
NAME = 'My Mail'
HOST = 'host.name.com'
PORT = 993
SSL  = true
USER = 'myusername'
PASS = 'mypassword'

# Watchfolder is the default folder used with the -w/--watch flag. 
WATCHFOLDER   = 'Inbox'

# This is a list of folders that are skipped when using the delete and marked
# flags. Use -l to list all mailboxes.
WHITELIST     = ['Drafts','Sent','Inbox']

### END CONFIG

# Print Message
def pp(message)
    puts "[#{NAME}] #{message}"
end

# Get all messages and mark them as read.
# args: imap object and imap folder name
def markMail(imap, folder)
    pp "MARKED #{folder}.."
    message_ids = imap.uid_search("ALL")
    imap.uid_store(message_ids, "+FLAGS", [:Seen])
    imap.expunge
end

# Get all messages and delete them.
# args: imap object and imap folder name
def delMail(imap, folder)
    pp "Emptying #{folder}.."
    message_ids = imap.uid_search("ALL")
    imap.uid_store(message_ids, "+FLAGS", [:Deleted])
    imap.expunge
end

# Get the current folder size and the loop until the number of messages 
# increases. Display the subject of each new # email recieved while in the 
# loop. 
def watchMail(imap, folder)
  
  # Loop for checking message increase in the folder
  begin
    
    imap.select(folder)
    
    # Get the current folder size
    fsize = imap.status(folder, ["MESSAGES"])
    csize = fsize["MESSAGES"]
    
    loop do
      fsize = imap.status(folder, ["MESSAGES"])
      if fsize["MESSAGES"] > csize
        message_ids = imap.uid_search("ALL")
        uid = message_ids.last
        email = imap.uid_fetch(uid, "ENVELOPE")[0].attr["ENVELOPE"]
        pp "[#{email.from[0].name}] #{email.subject}"
        csize = fsize["MESSAGES"]
      else
        sleep(10)
      end
    end
  rescue => e
    exit(1)
  end
end

options = {}

op = OptionParser.new do|opts|

    opts.banner = "Usage: ruby #{File.basename($0)} "
    options[:count]  = true
    options[:delete] = false
    options[:marked] = false
    options[:list]   = NIL
    options[:watch]  = NIL

    opts.on( '-d', '--delete', 'Delete all emails.' ) do
      options[:delete] = true
    end

    opts.on( '-m', '--marked', 'Mark all email as read.' ) do
      options[:marked] = true
    end

    opts.on( '-c', '--count', 'Count folder messages [default].' ) do
      options[:count] = true
    end
    
    opts.on( '-l', '--list', 'List all IMAP folders.' ) do
      options[:list] = true
    end

    opts.on( '-w', '--watch [OPT]', 'Watch the [OPT] folder for email, the default is defined in the config file.' ) do|f|
      options[:watch] = f || WATCHFOLDER
    end

    opts.on( '-h', '--help', 'Display this screen' ) do
      puts opts
      exit
    end
end

op.parse!

# Get the options passed
marked = options[:marked]
delete = options[:delete]
watch  = options[:watch]
list   = options[:list]

#Connect
pp 'Connecting...'
imap = Net::IMAP.new(HOST, PORT, SSL)
pp 'Logging in...'
imap.login(USER, PASS)

# Watch the define IMAP folder
if !watch.nil?
   pp "Watching folder #{watch}"
   watchMail(imap, watch)
   exit(1)
end

# List all IMAP folders
if !list.nil?
  dLIST = imap.list("", "*")
  dLIST.each do |ff|
      pp ff["name"]
  end
  exit(1)
end

FLIST = imap.list("", "*")

FLIST.each do |ff|
    folder = ff["name"]

    if WHITELIST.include?(folder)
      next
    end

    imap.select(folder)

    if marked == true
      fsize = imap.status(folder, ["MESSAGES"])
      if not fsize["MESSAGES"] == 0
        markMail(imap, folder)
      else
        pp "SKIPPED #{folder}.."
      end
    elsif delete ==  true
    fsize = imap.status(folder, ["MESSAGES"])
      if not fsize["MESSAGES"] == 0
        delMail(imap, folder)
      end
    else
      fsize = imap.status(folder, ["MESSAGES"])
       pp "#{folder} = #{fsize["MESSAGES"]}"
    end
end
