=begin
  * Name: boffer-selloff.rb
  * Description:  Script for getting the current boffer(deal) from boffer.co.uk.
                  Normally the boffer changed at midnight every day but on
                  some occasions they do a rapid sale and the boffer can change
                  at anytime. I used the script to watch for changes to try
                  and bag the latest deals :-)
                  
  * Author: Jay Scott
  * Date: 10/06/2011
  * Dependencies: sudo gem install nokogiri  
=end

require 'rubygems'
require 'open-uri'
require 'nokogiri'
require 'time'

STDOUT.sync = true
refresh_time = 4
current_title = String.new
current_price = String.new

begin

loop do

  # Grab the boffer page
  url_data = Nokogiri::HTML(open('http://www.boffer.co.uk/boffer.php'))
  
  current_time  = Time.now.to_s

  # Use XPath to drill down to the right element
  data_title = url_data.xpath("/html/body/table/tr/td/table/tr/td[2]/table/tr/td/font/font[1]")
  data_price = url_data.xpath("/html/body/table/tr/td/table/tr/td[2]/table/tr/td/font/font[2]")

  # If the title or price hasn't changed, update the time else display new boffer
  if data_title.text.eql? current_title and data_price.text.eql? current_price
    print "Last Updated:\t " + current_time + "\r"
  else
    current_title = data_title.text
    current_price = data_price.text

    puts "\n\n### Latest Boffer ###\n\n"
    puts "Current Boffer:\t " + current_title
    puts "Boffer Price:\t " + current_price
    puts "Buy it:\t http://www.boffer.co.uk/basket.php\n\n"
    print "Last Updated:\t " + current_time + "\r"
  end
  
  sleep refresh_time
  
end

rescue Exception => e
  print e, "\n"
end
