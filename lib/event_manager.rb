# frozen_string_literal: true

require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'
require 'date'

def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5, '0')[0..4]
end

def legislators_by_zipcode(zip)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = 'AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw'

  begin
    civic_info.representative_info_by_address(
      address: zip,
      levels: 'country',
      roles: %w[legislatorUpperBody legislatorLowerBody]
    ).officials
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

def clean_phone_number(phone)
  phone = phone.tr('^0-9', '')
  if phone.length == 11 && phone[0] == '1'
    phone[1..]
  elsif phone.length < 10 || phone.length > 10
    'This number is not valid'
  else
    phone
  end
end

def convert_to_DateTime(reg_date)
  format = '%m/%d/%y %H:%M'
  DateTime.strptime(reg_date, format)
end

def collect_reg_hours(reg_hour, reg_date)
  reg_date = convert_to_DateTime(reg_date)
  reg_hour.push(reg_date.hour)
end

def collect_weekdays(reg_day, reg_date)
  reg_date = convert_to_DateTime(reg_date)
  reg_day.push(reg_date.wday)
end

def find_max(reg)
  freq = reg.tally
  freq_sorted = freq.sort_by { |_k, v| v }.reverse
  max_value = freq_sorted[0][1]
  freq_sorted = freq_sorted.to_h
  freq_sorted.select { |_key, value| value == max_value }.keys
end

def weekday(best_ad_day)
  case best_ad_day
  when 0
    'Sunday'
  when 1
    'Monday'
  when 2
    'Tuesday'
  when 3
    'Wednesday'
  when 4
    'Thursday'
  when 5
    'Friday'
  when 6
    'Saturday'
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
reg_hour = []
reg_day = []

contents.each do |row|
  collect_reg_hours(reg_hour, row[:regdate])
  collect_weekdays(reg_day, row[:regdate])
  phone = clean_phone_number(row[:homephone])
  id = row[0]
  name = row[:first_name]
  zipcode = clean_zipcode(row[:zipcode])
  legislators = legislators_by_zipcode(zipcode)

  form_letter = erb_template.result(binding)
  save_thank_you_letter(id, form_letter)
end

best_ad_time = find_max(reg_hour)
best_ad_day = find_max(reg_day)
puts best_ad_time

best_weekday = weekday(best_ad_day[0])
puts best_weekday
