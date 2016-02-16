require "redis"
require "spreadsheet"
require "json"

def date2time(date)
  return nil if date.nil?
  datetime = nil
  if date.is_a?(String)
    if date.match(%r{\d{2}/\d{2}/\d{4}})
      datetime = DateTime.parse(date, "%d/%m/%Y")
    else
      puts "Do not recognize date format: #{date}"
    end
  elsif date.is_a? Date
    datetime = DateTime.parse(date.to_s)
  else
    puts "Didn't recognize date: #{date.inspect}"
    return nil
  end
  datetime.to_time.utc
end

def prettymonth(time)
  time.strftime("%Y-%m")
end

def prettydate(time)
  time.strftime("%Y-%m-%d")
end

class FinancesDAO
  SEPARATOR = "|"
  def initialize(redis)
    @redis = redis
  end

  def set_day(year, type, expiration_date, attributes)
    date = attributes[:date]
    attributes[:date] = prettymonth(date)

    # set brute date
    datekey = key_for_date(year, type, expiration_date, date)
    @redis.set(datekey, JSON.dump(attributes))

    # set index type+exp => brute date
    typekey = key_for_type(type, expiration_date)
    @redis.zadd(typekey, date.to_i, datekey)

    # set index date range => type+exp (by date)
    @redis.zadd(type, date.to_i, JSON.dump(expiration_date: prettydate(expiration_date), key: typekey, year: year))
  end

  private
  def key_for_type(type, expiration_date)
    [type, prettydate(expiration_date)].join SEPARATOR
  end

  def key_for_date(year, type, expiration_date, date)
    [year, type, prettydate(expiration_date), prettymonth(date)].join SEPARATOR
  end
end

ATTRS_NAMES = %i{buy_tax sell_tax buy_PU sell_PU base_PU}

def minmax_of_all(infos)
  minmax = {}
  ATTRS_NAMES.each do |attr|
    minmax[attr] = {min: Float::INFINITY, max: 0, avg: 0, count: 0}
  end
  infos.each do |info|
    ATTRS_NAMES.each do |attr|
      if info[attr]
        minmax[attr][:min] = info[attr] if minmax[attr][:min] > info[attr]
        minmax[attr][:max] = info[attr] if minmax[attr][:max] < info[attr]
        minmax[attr][:avg] += info[attr]
        minmax[attr][:count] += 1
      end
    end
  end
  ATTRS_NAMES.each do |attr|
    minmax[attr][:avg] = minmax[attr][:count].zero? ? 0 : minmax[attr][:avg] / minmax[attr].delete(:count)
  end
  minmax
end

redis = Redis.new
redis.flushall
dao = FinancesDAO.new(redis)

Dir["./data/*.xls"].each do |sheetpath|
  puts "=> #{sheetpath}"
  sheet = Spreadsheet.open(sheetpath)
  year, type = File.basename(sheetpath, ".xls").split "_"
  year = year.to_i

  sheet.worksheets.each do |ws|
    name = ws.name
    puts "> #{name}"
    expiration_date = date2time ws.row(0)[1]
    rows = ws.rows[2..-1]

    info = rows.map do |row|
      attrs = {
        date: date2time(row[0]),
        buy_tax: row[1],
        sell_tax: row[2],
        buy_PU: row[3],
        sell_PU: row[4],
        base_PU: row[5]
      }
      ATTRS_NAMES.each do |attr|
        if attrs[attr].is_a?(String) && attrs[attr].empty?
          attrs[attr] = nil
        end
      end
      if attrs[:date] && (attrs[:buy_tax] || attrs[:sell_tax] || attrs[:buy_PU] || attrs[:sell_PU] || attrs[:base_PU])
        attrs
      else
        nil
      end
    end.compact

    info_by_month = info.group_by do |info|
      DateTime.new(info[:date].year, info[:date].month).to_time.utc
    end

    month_attrs = info_by_month.map do |month, infos|
      attrs = minmax_of_all infos
      attrs.merge(date: month)
    end

    month_attrs.each do |attrs|
      dao.set_day(year, type, expiration_date, attrs)
    end
  end
end
