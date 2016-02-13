#!/usr/bin/env ruby
require_relative '../../config/environment.rb'

def error msg
  puts msg
  Rails.logger.error "Collect::progress: " + msg
end

def login account
  logout
  $browser.goto "#{HOST}#{LOGIN_PAGE}"
  $browser.text_field(:name => 'login').set account.email
  $browser.text_field(:name => 'password').set account.password
  $browser.button(:class => "btn btn-primary").click
  if /login/ =~ $browser.url
    error "incorrect account info for '#{account.email}'"
    return false
  end
  puts "#{account.email} login successful"
  true
end

def logout
  $browser.goto "#{HOST}#{LOGOUT_PAGE}"
end

def last_update_time model
  model.last ? model.last.updated_at : 100.years.ago
end

def analyze account
  return unless login account
  $browser.goto "#{HOST}#{PROGRESS_PAGE}"
  sleep 3 # wait for js animation
  html = Nokogiri::HTML.parse $browser.html

  username = html.xpath('//a[@class="dropdown-toggle"]')[1].text.strip
  account.update(username: username) if account.username != username

  # Total progress
  LeetcodeProgress.create(
    ac:         html.xpath('//span[@id="ac_total"]').text,
    submissions: html.xpath('//p[@id="ac_submissions"]').text,
    slack_id: account.id
  ) if Time.zone.now >= last_update_time(LeetcodeProgress) + 1.hour

  # each submissions in details
  $browser.goto "#{HOST}#{SUBMISSION_PAGE}"

  page_num = 1
  loop do
    # current page
    html = Nokogiri::HTML.parse $browser.html
    table = html.at_css('div[@class="submissions-table"]')
    break if table.at_css('p[@class="nomore"]')
    records = table.xpath('.//table/tbody/tr')

    records.each do |record|
      cols = record.xpath('./td')
      submit_time = parse_time(cols[0].text)
      break if submit_time <= last_update_time(LeetcodeSubmission)

      submission = LeetcodeSubmission.new(
        submit_time: submit_time,
        path:        get_path(cols[1]),
        status:      cols[2].at_css('a').text,
        detail_path: cols[2].at_css('a')['href'],
        runtime:     cols[3].text.strip,
        lang:        cols[4].text.strip,
        leetcode_id: account.id
      )
      submission.save
      puts "#{cols[0].text} - #{submission.status}"
    end

    # to next page
    next_page = html.at_css('ul[@class="pager"]').xpath('./li')[1]
    break if /next disabled/ =~ next_page['class']
    page_num += 1
    # visible clickable component is not reliable in headless mode
    $browser.goto "#{HOST}#{SUBMISSION_PAGE}/#{page_num}/"
  end
end

def parse_time text
  first, second = text.gsub("\u00a0", '.').gsub(/\s+ago/, '').split(/\s*,\s*/)
  eval(first + '.ago') - (second ? eval(second + '.to_i') : 0)
end

def get_path dom
  dom.at_css('a')['href']
end


HOST = 'https://leetcode.com'
LOGIN_PAGE = '/accounts/login/'
LOGOUT_PAGE = '/accounts/logout/'
PROGRESS_PAGE = '/progress/'
SUBMISSION_PAGE = '/submissions/'

headless = Headless.new
headless.start
$browser = Watir::Browser.new :chrome

Leetcode.all.each do |account|
  analyze account
end

headless.destroy
