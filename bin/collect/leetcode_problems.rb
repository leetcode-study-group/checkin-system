#!/usr/bin/env ruby
require 'rubygems'
require 'mechanize'
require_relative '../../config/environment.rb'

URL = 'https://leetcode.com/problemset/algorithms/'

agent = Mechanize.new
page = agent.get URL
table = page.search("//table[@id='problemList']").first
headers = table.at_css('thead').xpath('./tr/th')
problems = table.at_css('tbody').xpath('./tr')

problems.each do |tr|
  fields = tr.xpath './td'
  no = fields[1].text
  href = fields[2].at_css 'a'
  title = href.text
  path = href['href']
  difficulty = fields[4].text
  problem = LeetcodeProblem.new(
    no: no,
    title: title,
    path: path,
    difficulty: difficulty
  )
  puts "processing problem ##{no}"
  problem.save
end
