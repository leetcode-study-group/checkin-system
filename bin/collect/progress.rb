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

def last_updated_at model, account
  records = model.where('leetcode_id = ?', account.id)
  records.last ? records.last.updated_at : 100.years.ago
end

def analyze account
  return unless login account
  $browser.goto "#{HOST}#{PROGRESS_PAGE}"
  sleep 3 # wait for js animation
  html = Nokogiri::HTML.parse $browser.html

  username = html.xpath('//ul[@id="navBar-right"]/li/a')[0].text.strip
  account.update(username: username) if account.username != username

  # Total progress
  LeetcodeProgress.create(
    ac:         html.xpath('//span[@id="ac_total"]').text,
    submissions: html.xpath('//p[@id="ac_submissions"]').text,
    leetcode_id: account.id
  ) if Time.zone.now >= last_updated_at(LeetcodeProgress, account) + 1.hour

  # each submissions in details
  $browser.goto "#{HOST}#{SUBMISSION_PAGE}"
  Goal.rollback # remove any manually marked progresses
  LeetcodeRecent.delete_all

  last_updated_time = last_updated_at(LeetcodeSubmission, account)
  page_num = 1
  catch :scanned_all do
    loop do
      # current page
      html = Nokogiri::HTML.parse $browser.html
      table = html.at_css('div[@class="submissions-table"]')
      break if table.at_css('p[@class="nomore"]')
      records = table.xpath('.//table/tbody/tr')

      records.each do |record|
        cols = record.xpath('./td')
        submit_time = parse_time(cols[0].text)
        throw :scanned_all if submit_time <= last_updated_time

        submission = LeetcodeSubmission.create(
          submit_time: submit_time.in_time_zone(Time.zone.name),
          path:        get_path(cols[1]),
          status:      cols[2].at_css('a').text,
          detail_path: cols[2].at_css('a')['href'],
          runtime:     cols[3].text.strip,
          lang:        cols[4].text.strip,
          leetcode_id: account.id
        )
        submission.update_goal
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

  questions = LeetcodeRecent.all.map do |q|
    problem = LeetcodeProblem.find_by_no q.no
    "#{q.no}(#{problem.difficulty[0]})"
  end

  unless questions.empty?
    $recents[account.slack.team_id] += "#{account.slack.slack_name} completed #{questions.join(', ')}\n"
  end
end

def parse_time text
  first, second = text.gsub("\u00a0", '.').gsub(/\s+ago/, '').split(/\s*,\s*/)
  eval(first + '.ago') - (second ? eval(second + '.to_i') : 0)
end

def get_path dom
  dom.at_css('a')['href']
end

def send_to_slack team_id, msg
  return false if msg.empty?
  receiver = Receiver.find_by_team_id team_id
  return false unless receiver
  receiver.send_to_slack(text: msg)
end


HOST = 'https://leetcode.com'
LOGIN_PAGE = '/accounts/login/'
LOGOUT_PAGE = '/accounts/logout/'
PROGRESS_PAGE = '/progress/'
SUBMISSION_PAGE = '/submissions/'

headless = Headless.new
headless.start
$browser = Watir::Browser.new :chrome

$recents = Hash.new('')
Leetcode.all.each do |account|
  analyze account
end

$recents.each {|team_id, msg| send_to_slack team_id, msg}

headless.destroy
