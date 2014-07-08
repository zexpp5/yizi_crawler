require 'nokogiri'
require 'open-uri'
require 'json'
require 'mysql'
require 'watir'

class Topic
  def initialize(r_id,title,level,parent,stage,subject)
    @r_id = r_id
    @title = title
    @level =level
    @parent =parent
    @stage = stage
    @subject = subject
  end

  def r_id
    @r_id
  end
  def title
    @title
  end
  def level
    @level
  end
  def parent
    @parent
  end
  def stage
    @stage
  end
  def subject
    @subject
  end
end

site = "http://www.tizi.com/teacher/paper/question/"
topics = Hash.new

for i in (1  .. 30) do
  page = Nokogiri::HTML(open(site+i.to_s))

  s = page.css('.currentSubject').text[46,page.css('.currentSubject').text.length]
  s = s[0,s.index("\n")]

  parent = nil
  level = nil
  stage = s[0,2]
  subject = s[2,s.length]
  parent1 = 0
  parent2 = 0
  parent3 = 0

  page.css('.fn-clear').each{ |item|
    item.css('.tree-title1,.tree-title2,.tree-title3,.tree-title4').each{ |item1|
      out = ""
      if item1["class"].to_s.index("title1") then  out="-1-" end
      if item1["class"].to_s.index("title2") then  out="-2-" end
      if item1["class"].to_s.index("title3") then  out="-3-" end
      if item1["class"].to_s.index("title4") then  out="-4-" end
      item1.css(".item").each{|item2|
        if out.index("-1-") == 0 then level = 1 end
        if out.index("-2-") == 0 then level = 2; parent = parent1 end
        if out.index("-3-") == 0 then level = 3; parent = parent2 end
        if out.index("-4-") == 0 then level = 4; parent = parent3 end
        t = Topic.new(item2["data-nselect"],item2["title"],level,parent,stage,subject)
        topics[item2["data-nselect"]] = t

        if out.index("-1-") == 0 then parent1 = item2["data-nselect"] end
        if out.index("-2-") == 0 then parent2 = item2["data-nselect"] end
        if out.index("-3-") == 0 then parent3 = item2["data-nselect"] end

      }
    }
  }

end


begin
# connect to the   server
  db = Mysql.init.options(Mysql::SET_CHARSET_NAME, 'utf8')
  db = Mysql.real_connect("localhost", "magpie", "magpie", "tizi", 3306)

  count = 0
  k = 0
  topics.each{|key,value|
    db.query("insert into topics values(#{k},\"#{value.title}\",#{value.level},#{value.r_id},#{value.parent},\"#{value.stage}\",\"#{value.subject}\")")
    k+=1
    p  count+=1
  }

rescue Mysql::Error => e
  print "Error code: ", e.errno, "/n"
  print "Error message: ", e.error, "/n"
ensure
# disconnect from server
  db.close if db
end






