# This is a template for a Ruby scraper on morph.io (https://morph.io)
# including some code snippets below that you should find helpful

# require 'scraperwiki'
# require 'mechanize'
#
# agent = Mechanize.new
#
# # Read in a page
# page = agent.get("http://foo.com")
#
# # Find somehing on the page using css selectors
# p page.at('div.content')
#
# # Write out to the sqlite database using scraperwiki library
# ScraperWiki.save_sqlite(["name"], {"name" => "susan", "occupation" => "software developer"})
#
# # An arbitrary query against the database
# ScraperWiki.select("* from data where 'name'='peter'")

# You don't have to do things with the Mechanize or ScraperWiki libraries.
# You can use whatever gems you want: https://morph.io/documentation/ruby
# All that matters is that your final data is written to an SQLite database
# called "data.sqlite" in the current working directory which has at least a table
# called "data".

require 'scraperwiki'
require 'mechanize'
require 'hpricot'

# Process the cpso document and parse it
# into various components. 
# Limited currently to:
# Phone, Fax, City, Address, First Name, Last Name, Active/inactive, Family Doctor (Yes/No)
# Assumes the province is Ontario.
class CPSONameDocument

  attr_accessor :cpso,  :specialty

  def page=(value)
    @page = value
  end

  def phone
    return @phone
  end

  def fax
    @fax
  end

  def city
    clean(@city)
  end

  def process
    get_names
    process_address
  end

  def names
    @names
  end

  def first_name
    @first_name
  end

  def last_name
    @last_name
  end

  def get_names
    begin
      name_doc = @page.search("//*[@id='profile-content']/div[1]/p']").inner_html
      first_name = /(Given Name:)(.*\n)(.*)<strong>/.match(name_doc.to_s)
      @first_name =  first_name[3].gsub!("&nbsp;", '').to_s  unless first_name.nil?
      @first_name.strip!

      last_name = /(Surname:)(.*\n)(.*)<br/.match(name_doc.to_s)
      @last_name =  last_name[3]  unless last_name.nil?
      @last_name.strip!

    rescue => e
      puts "Exception caught during name processing #{e}"
    end
  end

  def is_family_doctor?
    specialty = @page.search("//*[@id='profile-content']/div[4]/table")
    specialty.to_s.include?("Family Medicine")
  end

  def is_active?
    active = @page.search("//*[@id='profile-content']")
    if (active.to_s.include?("Active Member"))
      return "active"
    else
      return "inactive"
    end
  end

  def process_address
    @address = @page.search("//*[@id='profile-content']/div[2]/p")
    begin
      address = /<p>.*(\n)(.*)(<br)/.match(@address.to_s)
      @address_line_1 = address[2].to_s unless address.nil?

      city = /(<br \/>)(.*)(ON)/.match(@address.to_s)
      
      if (city.to_s.include?("<br />"))
        city = city[2].to_s.split("<br />").last
        @city = city unless city.nil?
      else
        @city = city[2] unless city.nil?
      end

    rescue => e
      puts "Exception thrown during the processing of the address #{e}"
      puts e
      @city = 'Unknown'
      @address_line_1 = 'Unknown'
    end

    process_phone
    process_fax

    @specialty = @page.search("//*[@id='profile-content']/div[4]/table/tr[2]/td[1]").to_s

    @specialty.gsub!("<td>", "")
    @specialty.gsub!("</td>", "")
    @specialty.strip!
  end

  def process_fax
    fax = /(Fax:.*)((\()[0-9]{3}(\))(\s)[0-9]{3}(-)[0-9]{4})/.match(@address.to_s)
    @fax =  fax[2]  unless fax.nil?
  end

  def process_phone
    phone = /(Phone:.*)(\()([0-9]{3})(\))(\s)([0-9]{3}(-)[0-9]{4}).*/.match(@address.to_s)
    @phone =  phone[3] + " " + phone[6]  unless phone.nil?
  end

  def province
    "ON"
  end

  def address_line_1
    clean(@address_line_1)
  end

  def city
    clean(@city)\
  end

  def clean(text)
    return if text.nil?
    text.gsub!("&nbsp;", "")
    text.gsub!("<br />", "\r")
    text.strip!
    
    text
  end

  def postal_code
    puts @address
    postal_code = /[A-Z][0-9][A-Z](\s)[0-9][A-Z][0-9]/.match(@address.to_s)
    @postal_code =  postal_code.to_s
    puts "Postal Code Found: #{@postal_code}"
    clean(@postal_code)
  end

  def address_is_present?
    if (@address_lines.size==1)
      return false
    end

    !self.address_line_1.include?("Practice Address Not Available")
  end

  def address_is_valid?
    if (self.postal_code.eql?(""))
      return false
    end
    if (self.city.eql?(""))
      return false
    end
    if (self.city == self.postal_code)
      return false
    end
    if (self.postal_code ==self.address_line_3)
      return false
    end
    if (self.postal_code == self.address_line_2)
      return false
    end
    
    true
  end

  def raw_output
    @address_lines.each { |line|
      puts line.to_s
    }
  end
end

(100000..110000).step(1).each do |cpso_number|
  agent = Mechanize.new

  begin
    page = agent.get("http://www.cpso.on.ca/docsearch/details.aspx?view=1&id=#{cpso_number}")
    @response = page.content

    doc = Hpricot(@response)
    
    extractor = CPSONameDocument.new
    extractor.cpso = cpso_number
    extractor.page = doc
    extractor.process

      ScraperWiki.save_sqlite(
        [:doctor] ,
        {
          cpso: extractor.cpso,
          last_name: extractor.last_name,
          first_name: extractor.first_name,
          phone: extractor.phone,
          fax: extractor.fax,
          specialty: extractor.specialty,
          address_line_1: extractor.address_line_1,
          city: extractor.city,
          postal_code: extractor.postal_code,
          is_active: extractor.is_active?
        }
      )
  rescue => e
    puts "Exception thrown during the processing of the document #{e}"
    puts "Skipping #{cpso_number}"
  end
end










