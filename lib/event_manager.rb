# frozen_string_literal: true

require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'

def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5, '0')[0..4]
end

def clean_phone_number(phone_number)
  numeric_phone_number = phone_number.gsub(/\D/, '')
  if numeric_phone_number.size == 10
    numeric_phone_number
  elsif numeric_phone_number.size == 11 && numeric_phone_number[0] == '1'
    numeric_phone_number[1..10]
  else
    'invalid phone number'
  end
end

def legislators_by_zipcode(zip)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = 'AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw'
  begin
    civic_info.representative_info_by_address(address: zip,
                                              levels: 'country',
                                              roles: %w[legislatorUpperBody legislatorLowerBody]).officials
  rescue StandardError
    'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials'
  end
end

def save_thank_you_letter(id, form_letter)
  Dir.mkdir('output') unless Dir.exist?('output')

  filename = "output/thanks_#{id}.html"

  File.open(filename, 'w') do |file|
    file.puts form_letter
  end
end

puts 'EventManager initialized.'

contents = CSV.open(
  'event_attendees.csv',
  headers: true,
  header_converters: :symbol
)

template_letter = File.read('form_letter.erb')
erb_template = ERB.new template_letter
hours = Hash.new(0)
days = Hash.new(0)
contents.each do |row|
  puts "#{row[:homephone]}=>#{clean_phone_number(row[:homephone])}"
  time = Time.strptime(row[:regdate], '%m/%d/%Y %k:%M')
  hours[time.hour] += 1
  days[time.wday] += 1

  id = row[0]
  name = row[:first_name]
  zipcode = clean_zipcode(row[:zipcode])
  legislators = legislators_by_zipcode(zipcode)

  form_letter = erb_template.result(binding)

  save_thank_you_letter(id, form_letter)
end

puts hours.max_by { |_, value| value } [0]
puts Date.strptime(days.max_by { |_, value| value } [0].to_s, '%w').strftime('%A')
