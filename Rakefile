require './tesouro-direto-crawler'
require './tesouro-direto-to-redis'

desc "update db"
task 'db:update' do
  spreadsheet2db = SpreadsheetToDatabase.new
  spreadsheet2db.reset
  SpreadsheetCrawler.each_spreadsheet do |content, year, type|
    spreadsheet2db.persist(content, year, type)
  end
end
