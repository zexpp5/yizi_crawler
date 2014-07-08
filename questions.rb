require 'nokogiri'
require 'open-uri'
require 'json'
require 'mysql'
require 'watir'

class R5
  URL = "http://www.tizi.com/paper/paper_question/get_question"
end


class Encodec
  def Unicode2utf8(unicode_string)
    unicode_string.gsub(/\\u\w{4}/) do |s|
      str = s.sub(/\\u/, "").hex.to_s(2)
      if str.length < 8
        CGI.unescape(str.to_i(2).to_s(16).insert(0, "%"))
      else
        arr = str.reverse.scan(/\w{0,6}/).reverse.select { |a| a != "" }.map { |b| b.reverse }
        hex = lambda do |s|
          (arr.first == s ? "1" * arr.length + "0" * (8 - arr.length - s.length) + s : "10" + s).to_i(2).to_s(16).insert(0, "%")
        end
        CGI.unescape(arr.map(&hex).join)
      end
    end
  end
end

class Question
  attr_accessor :r_id, :qlevel, :source, :category_name, :qtype, :analysis, :category_id, :answer, :course_id, :body, :date, :id, :title, :qlevel_name

  def initialize(id, r_id, title, category_id, category_name, course_id, date, qtype, qlevel, qlevel_name, source, body, answer, analysis)
    @id = id
    @r_id =r_id
    @title =title
    @category_id =category_id
    @category_name =category_name
    @course_id =course_id
    @date =date
    @qtype =qtype
    @qlevel =qlevel
    @qlevel_name =qlevel_name
    @source =source
    @body =body
    @answer =answer
    @analysis =analysis
  end

end

uri = "http://www.tizi.com/paper/paper_question/get_question?page=1&nselect=1318&cselect=1316&sid=10&qtype=0&qlevel=0&ver=1404531472045"


class LoopIndex

  attr_accessor :subjectIds, :cur_subject_id, :cur_question_type_id, :cur_topic_id, :cur_page, :topicIds, :qTypeIds, :cur_ver, :cur_level_id, :cur_parent_topic_id, :categories

  def initialize(cur_page, cur_topic_id, cur_parent_topic_id, cur_subject_id, cur_question_type_id, cur_level_id, cur_ver, subjectIds, topicIds, categories, qTypeIds)
    @cur_page = cur_page
    @cur_topic_id = cur_topic_id
    @cur_parent_topic_id = cur_parent_topic_id
    @cur_subject_id = cur_subject_id
    @cur_question_type_id = cur_question_type_id
    @cur_level_id = cur_level_id
    @cur_ver = cur_ver
    @subjectIds = subjectIds
    @topicIds = topicIds
    @categories = categories
    @qTypeIds = qTypeIds
  end
end


begin

  loop = LoopIndex.new(0, 0, 0, 0, 0, 0, 0, [], [], [],[])

# connect to the   server
  db = Mysql.init.options(Mysql::SET_CHARSET_NAME, 'utf8')
  db = Mysql.real_connect("localhost", "magpie", "magpie", "tizi", 3306)

  subjectIds = []
  qTypeIds = Hash.new
  categories = Hash.new
  topicIds = Hash.new

  result = db.query("select id from subjects")
  result.each { |row|
    loop.subjectIds << row[0]
  }

  result = db.query("select subject_id,type_id from question_types")
  result.each { |row|
    if !qTypeIds[row[0].to_i] then
      qTypeIds[row[0].to_i] = []
    end
    qTypeIds[row[0].to_i] << row[1]
  }
  loop.qTypeIds = qTypeIds

  result = db.query("select t.raw_id,t.title,s.id from topics t,subjects s where t.stage = s.stage and t.subject = s.subject and t.title like '%知识点库'")
  result.each { |row|
    categories[row[2]] = row[0]
  }
  loop.categories = categories




  result = db.query("select s.id,t.raw_id from topics t,subjects s where s.subject = t.subject and s.stage = t.stage and t.id not in (select distinct tt.parent from topics tt ) and t.title not like '%知识点库'")
  result.each { |row|
    if !topicIds[row[0].to_i] then
      topicIds[row[0].to_i] = []
    end
    topicIds[row[0].to_i] << row[1]
  }
  loop.topicIds = topicIds

  p loop.topicIds
    
    
    


rescue Mysql::Error => e
  print "Error code: ", e.errno, "/n"
  print "Error message: ", e.error, "/n"
ensure
# disconnect from server
  db.close if db
end







