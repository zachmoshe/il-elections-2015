#! /usr/bin/env ruby
require 'json' 
require 'csv'

VOTES_18_FILENAME = "raw-votes-18.txt"
VOTES_19_FILENAME = "raw-votes-19.txt"
CITIES_TO_GEO_FILENAME = "cities_geo.txt"
CITIES_TO_GEO = File.read(CITIES_TO_GEO_FILENAME).split("\n").map do |line|
	heb_name, eng_name, lat, long, width, height = line.split("\t")
	heb_name.gsub! /\+/, ' '
	[ heb_name, { eng_name: eng_name, lat: lat, long: long, width: width, height: height }]
end.to_h

PARTIES_MAPPER_FILENAME = "parties_mapper.txt"
PARTIES_MAPPER = File.read(PARTIES_MAPPER_FILENAME).split("\n").map do |r| 
	t = r.split(",")
	[t[0], t[1]]
end.to_h
PARTIES_SIDES = PARTIES_MAPPER.group_by { |k,v| v }.map{ |k,v| [k, v.map{ |x| x[0]} ] }.to_h


def my_csv_parse(content)
	lines = content.split "\n"
	column_names = lines[0].split("\t").map{ |str| str.strip }
	rows = lines[1..-1].map{ |line| line.split "\t"}
	rows.map{ |row| column_names.zip(row).to_h }
end

def raw_row_parser(r, parties_18, city_field, city_id_field, ballot_id_field, bazab_field, total_votes_field, valid_votes_field, invalid_votes_field)
	{ 
		city_id: r[city_id_field],
		city: r[city_field],
		ballot_id: r[ballot_id_field],
		ballot_lat: (CITIES_TO_GEO[r[city_field]][:lat] rescue nil),
		ballot_long: (CITIES_TO_GEO[r[city_field]][:long] rescue nil),
		bazab: r[bazab_field].to_i,
		total_votes: r[total_votes_field].to_i,
		valid_votes: r[valid_votes_field].to_i,
		invalid_votes: r[invalid_votes_field].to_i,
	}.
	merge(r.select{ |k,v| parties_18.include? k}.map{ |k,v| [k,v.to_i]}.to_h).
	merge(PARTIES_SIDES.map do |party_side, parties|
		["side_#{party_side}", r.select{ |k,v| parties.include? k }.values.map(&:to_i).inject(&:+).to_f / r[valid_votes_field].to_i]
	end.to_h)
end


raw_votes_18 = my_csv_parse(File.read VOTES_18_FILENAME)
raw_votes_19 = my_csv_parse(File.read VOTES_19_FILENAME)


cities_18 = raw_votes_18.map{ |r| r["שם ישוב"] }.uniq.sort
cities_19 = raw_votes_19.map{ |r| r["שם ישוב"] }.uniq.sort

parties_18 = (raw_votes_18.first.keys - ["סמל ישוב", "שם ישוב",  "סמל קלפי", "בז''ב", "מצביעים", "כשרים", "פסולים", "ת. עדכון"]).map{ |s| s.strip }
parties_19 = (raw_votes_19.first.keys - ["סמל ישוב", "שם ישוב", "מספר קלפי", "בזב", "מצביעים", "פסולים", "כשרים"]).map{ |s| s.strip}

votes_18 = raw_votes_18.map{ |r| raw_row_parser(r, parties_18, "שם ישוב",  "סמל ישוב", "סמל קלפי", "בז''ב", "מצביעים", "כשרים", "פסולים") }
votes_19 = raw_votes_19.map{ |r| raw_row_parser(r, parties_19, "שם ישוב", "סמל ישוב", "מספר קלפי", "בזב", "מצביעים", "כשרים", "פסולים" ) }


File.write("votes-18.json", JSON.dump(votes_18))
File.write("votes-19.json", JSON.dump(votes_19))
File.open("votes-18.csv", "w") do |f|
	f.puts votes_18.first.keys.join(",")
	f.puts votes_18.map{ |r| r.values.join(",") }.join("\n")
end
File.open("votes-19.csv", "w") do |f|
	f.puts votes_19.first.keys.join(",")
	f.puts votes_19.map{ |r| r.values.join(",") }.join("\n")
end




