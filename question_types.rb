require 'nokogiri'
require 'open-uri'
require 'json'
require 'mysql'
require 'watir'

class Types
  def initialize(id,name,subjectId,typeId)
    @id = id
    @name = name
    @subjectId =subjectId
    @typeId =typeId
  end

  def id
    @id
  end
  def name
    @name
  end
  def subjectId
    @subjectId
  end
  def typeId
    @typeId
  end
end


subjects = Hash.new


begin
# connect to the   server
  db = Mysql.init.options(Mysql::SET_CHARSET_NAME, 'utf8')
  db = Mysql.real_connect("localhost", "magpie", "magpie", "tizi", 3306)

  result =  db.query("select * from subjects")
  result.each{ |row|
    subjects[row[0]]=row[1]
  }

  #subjects.each{ |k,v|
  #  p "#{k}    #{v}"
  #}

rescue Mysql::Error => e
  print "Error code: ", e.errno, "/n"
  print "Error message: ", e.error, "/n"
ensure
# disconnect from server
  db.close if db
end







site = "http://www.tizi.com/teacher/paper/question/"
types = Hash.new

i = 0

subjects.each{|k,v|
  page = Nokogiri::HTML(open(site+k.to_s))
  page.css('a[data-qtype]').each{|elmt|
    #print "#{elmt[:'data-qtype']}:#{elmt.text}\t"
    t = Types.new(i,elmt.text,k,elmt[:'data-qtype'])
    types[i] = t
    i+=1
  }
}



begin
# connect to the   server
  db = Mysql.init.options(Mysql::SET_CHARSET_NAME, 'utf8')
  db = Mysql.real_connect("localhost", "magpie", "magpie", "tizi", 3306)

  types.each{|k,v|
    db.query("insert into question_types values(#{v.id},\"#{v.name}\",#{v.subjectId},#{v.typeId})")
    p v.id.to_s+"\t"+v.name+"\t"+v.typeId.to_s
  }

rescue Mysql::Error => e
  print "Error code: ", e.errno, "/n"
  print "Error message: ", e.error, "/n"
ensure
# disconnect from server
  db.close if db
end


