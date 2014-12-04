#!/usr/bin/env ruby
# encoding: UTF-8

#
#	Bibliotheken
#
require "Date"
require "FileUtils"
require "uri"
require "redcloth"
require "i18n"; I18n.enforce_available_locales = false


#
#	Konstanten
#
ROOT_DIR = "/Users/LYNX/Documents/Piratenpartei/breitseite/"
TMPL_DIR = "#{ROOT_DIR}Templates/"
OUTPUT_ROOT_DIR = "#{ROOT_DIR}/Ausgaben"

URI_SCHEMES = ["http","https","mailto"]
FREE_TEXT_SECTIONS = ["Editorial","Schluss"]


#
# Routinen
#

def to_html( txt )
	## subline = $1.gsub(/"(.+?":(.+?) /,' ')
	#0 txt = RedCloth.new( url_to_html( txt ) ).to_html
	#1 txt = url_to_html( txt )
	#1 txt = txt.gsub(/\*(.+?)\*/) { |bold| "<strong>#{$1}</strong>" }
	txt = RedCloth.new( txt ).to_html
end

def url_to_html( txt )
	URI.extract( txt, URI_SCHEMES ).each do |url|
		txt = txt.gsub( url, "<a href=\"#{url}\" target=\"_blank\">#{url}</a>" )
	end
	txt
end

def make_dir( dir, verbose = false )
	unless File.exist?(dir) && File.directory?(dir)
		puts "Verzeichnis #{dir} nicht vorhanden." if verbose
		if (res = FileUtils.mkdir_p dir)
			puts "Verzeichnis #{dir} angelegt." if verbose
		else
			puts "Verzeichnis #{dir} konnte nicht angelegt werden." if verbose
			return false
		end
	end
	return true
end


#
# INIT (Checks & Parameter)
#

unless File.exists?(TMPL_DIR)
	puts "file not found '#{TMPL_DIR}'."
	exit
end

unless ARGV.length == 3
	puts "usage: breitseite nr 'tt.mm.jjjj' quellenfile"
	exit
else
	breiteseite_nummer = ARGV[0].to_i
	if breiteseite_nummer.zero?
		puts "usage: breitseite ausgabe_nr ausgabe_datum quellenfile --- 'ausgabe_nr' must be integer"
		exit
	end

	begin
		breiteseite_datum  = Date.parse(ARGV[1])
	rescue
		puts "usage: breitseite ausgabe_nr ausgabe_datum quellenfile --- 'ausgabe_datum' must be valid date"
		exit
	end
	
	rawfile_name = ARGV[2]
	unless File.exists?(rawfile_name)
		puts "usage: breitseite ausgabe_nr ausgabe_datum quellenfile --- file not found: #{rawfile_name}"
		exit
	end
	breiteseite_quellenfile = File.basename( rawfile_name, ".txt" )

end

output_dir = "#{OUTPUT_ROOT_DIR}/#{I18n.localize( breiteseite_datum, :format => "%Y" )}-#{I18n.localize( breiteseite_datum, :format => "%m" )}-breitseite-#{breiteseite_nummer}/"
exit unless make_dir( output_dir )

breiteseite_link = "http://landesportal.piratenpartei-sh.de/team-presse/#{I18n.localize( breiteseite_datum, :format => "%Y" )}/#{I18n.localize( breiteseite_datum, :format => "%m" )}/breitseite-#{breiteseite_nummer}/"


#
#	INPUT
#

sections = []

section = nil
File.open( rawfile_name ).each do |line|
	subline = nil
	#	Beginn einer (neuen) Sektion
	if line =~ /^=== (.+?)$/
		sections << section unless section.nil?
		section = { name: $1, text_items: [], html_items: [] }
		next
	end
	# Beginn eines (strukturierten) Beitrages
	if line =~ /^    (?:\[.+?\] )?(.+)/
		subline = $1.gsub(/ +/,' ').strip
		section[:text_items] << subline
		section[:html_items] << to_html( subline )
		next
	end
	# Beginn einer Freitext-Zeile
	if FREE_TEXT_SECTIONS.include?(section[:name])
		subline = line.gsub(/ +/,' ').strip
		section[:text_items] << subline
		section[:html_items] << to_html( subline ) unless subline.empty?
	end
end
sections << section	#	letzte Sektion noch hinzufügen


marker = {}

sections.each do |sec|
	case sec[:name]

	when "Editorial", "Schluss"
		marker.merge!( { "###___SECTION[#{sec[:name]}]TEXT___###" => sec[:text_items].join("\r\n") } )
		marker.merge!( { "###___SECTION[#{sec[:name]}]MAIL___###" => sec[:html_items].collect{ |item| "#{item}" }.join("\n") } )	#	<p>#{item}</p>
		marker.merge!( { "###___SECTION[#{sec[:name]}]HTML___###" => sec[:html_items].collect{ |item| "#{item}" }.join("\n") } )	#	<p>#{item}</p>

	when "Termine"
		__anker = sec[:name].gsub(/\s/,'_').downcase

		marker.merge!( { "###___SECTION[#{sec[:name]}]TEXT___###" => <<-TEXT
#{sec[:name]}
- - - - - - -
#{sec[:text_items].join("\r\n")}
TEXT
		} )

		marker.merge!( { "###___SECTION[#{sec[:name]}]MAIL___###" => <<-HTML
<h2>#{sec[:name]}</h2>
<ul>
#{ sec[:html_items].collect{ |item| "\t<li>#{item}</li>" }.join("\n") }
</ul>
HTML
		} )

		marker.merge!( { "###___SECTION[#{sec[:name]}]HTML___###" => <<-HTML
<a name="#{__anker}"></a>
<h2>#{sec[:name]}</h2>
<ul>
#{ sec[:html_items].collect{ |item| "\t<li>#{item}</li>" }.join("\n") }
</ul>
HTML
		} )

	else
		__anker = sec[:name].gsub(/ä/,'ae').gsub(/[\s,-]/,'_').gsub(/__/,'_').downcase

		marker.merge!( { "###___SECTION[#{sec[:name]}]TEXT___###" => <<-TEXT
#{sec[:name]}
- - - - - - -
#{sec[:text_items].first}

Weitere Beiträge aus der Rubrik „#{sec[:name]}“ siehe ###___AUSGABE_LINK___#####{__anker}
TEXT
		} )

		marker.merge!( { "###___SECTION[#{sec[:name]}]MAIL___###" => <<-HTML
<h2>#{sec[:name]}</h2>
<ul>
	<li>#{sec[:html_items].first}</li>
	<li>Weitere Beiträge aus der Rubrik <a href="###___AUSGABE_LINK___#####{__anker}" target="_blank">#{sec[:name]}</a></li>
</ul>
HTML
		} )

		marker.merge!( { "###___SECTION[#{sec[:name]}]HTML___###" => <<-HTML
<a name="#{__anker}"></a>
<h2>#{sec[:name]}</h2>
<ul>
	#{ sec[:html_items].collect{ |item| "\t\t\t\t<li>#{item}</li>" }.join("\n") }
</ul>
<hr />
HTML
		} )

	end
end

marker.merge!( { "###___AUSGABE_NUMMER___###" => "#{breiteseite_nummer}" } )
marker.merge!( { "###___AUSGABE_TAG___###" => "#{I18n.localize( breiteseite_datum, :format => "%d" )}" } )
marker.merge!( { "###___AUSGABE_MONAT___###" => "#{I18n.localize( breiteseite_datum, :format => "%m" )}" } )
marker.merge!( { "###___AUSGABE_JAHR___###" => "#{I18n.localize( breiteseite_datum, :format => "%Y" )}" } )
marker.merge!( { "###___AUSGABE_NAME___###" => "Ausgabe #{breiteseite_nummer} (#{I18n.localize( breiteseite_datum, :format => "%Y" )}/#{I18n.localize( breiteseite_datum, :format => "%m" )})" } )
marker.merge!( { "###___AUSGABE_LINK___###" => breiteseite_link } )


#
#	OUTPUT
#

Dir.glob( "#{TMPL_DIR}*" ).each do |tmpl_name|
	tmpl_basename = File.basename( tmpl_name )
	tmpl_cont = File.read( tmpl_name )
	marker.each do |key,val|
		tmpl_cont = tmpl_cont.gsub( key, val )
	end
	File.open( "#{output_dir}#{tmpl_basename}", "w" ) { |file| file.puts tmpl_cont }
end

