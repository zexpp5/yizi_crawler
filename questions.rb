require 'nokogiri'
require 'open-uri'
require 'json'
require 'mysql'
require 'watir'

class R5
  attr_accessor :url
  URL = "http://www.tizi.com/paper/paper_question/get_question"

  def initialize(page, nselect, cselect, sid, qtype, level, ver)
    @url = URL+"?page=#{page}&nselect=#{nselect}&cselect=#{cselect}&sid=#{sid}&qtype=#{qtype}&qlevel=#{level}&ver=#{ver}"
  end
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

  attr_accessor :subjectIds, :cur_subject_id, :cur_question_type_id, :cur_topic_id, :cur_page, :topicIds, :qTypeIds, :cur_ver, :cur_level_id, :cur_parent_topic_id, :categories, :level, :page

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
    @level = (1 .. 5)
    @page = (1 .. 100)
  end
end


begin

  loop = LoopIndex.new(0, 0, 0, 0, 0, 0, 0, [], [], [], [])

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


  result = db.query("select s.id,t.raw_id from topics t,subjects s where s.subject = t.subject and s.stage = t.stage and t.raw_id not in (select distinct tt.parent from topics tt ) and t.title not like '%知识点库'")
  result.each { |row|
    if !topicIds[row[0].to_i] then
      topicIds[row[0].to_i] = []
    end
    topicIds[row[0].to_i] << row[1]
  }
  loop.topicIds = topicIds


  p loop.subjectIds
  p loop.topicIds
  p loop.categories
  p loop.qTypeIds

  threads = []
  conns = []
  m = Mutex.new
  count_thread = 0

  i = 1700000

  loop.subjectIds.each { |sid|
    loop.level.each { |level|
      loop.qTypeIds[sid.to_i].each { |qtype|

        threads << Thread.new {
          conn = Mysql.real_connect("localhost", "magpie", "magpie", "tizi", 3306)
          conns << conn
          loop.topicIds[sid.to_i].each { |nselect|

            loop.page.each { |page|

              questionListJson = nil

              begin
                open(R5.new(page, nselect, loop.categories[sid.to_i], sid, qtype, level, Time.now.to_i*1000+rand(1000)).url) do |http|
                  questionListJson = JSON.parse http.read
                end
              rescue => e
                p "timeout"
                redo
              end


              break if questionListJson["question"].length == 0
              questionListJson["question"].each { |q|
                j = nil
                m.synchronize {
                  j = i
                  i+=1
                }
                conn.query("insert into questions values(#{j},#{q["id"]},\"#{q["title"]}\",\"#{q["category_name"]}\",#{q["category_id"]},#{nselect},#{sid},#{q["course_id"]},\"#{q["date"].to_s+" 00:00:00"}\",#{q["qtype"]},#{q["qlevel"]},\"#{q["qlevel_name"]}\",\"#{q["source"]}\",\"#{q["body"].gsub(/<img class=\"pre_img\" src=\"/, '').gsub(/\"\/>/, '')}\",\"#{q["answer"].gsub(/<img class=\"pre_img\" src=\"/, '').gsub(/\"\/>/, '')}\",\"#{q["analysis"].gsub(/<img class=\"pre_img\" src=\"/, '').gsub(/\"\/>/, '')}\")")
                #p j

              }
            }
          }
          conn.close

        }
      }
    }
  }

  

rescue Mysql::Error => e
  print "Error code: ", e.errno, "/n"
  print "Error message: ", e.error, "/n"
ensure
# disconnect from server
  db.close if db
end


threads.each { |tt|
  tt.join
}

conns.each { |cc|
  cc.close if cc
}



