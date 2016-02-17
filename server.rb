require 'sinatra'
require 'redis'
require 'json'
require 'date'

class Server < Sinatra::Base
  redis = Redis.new url: ENV["REDISTOGO_URL"]

  def parsedate(date_str)
    DateTime.parse(date_str).to_time.utc
  end

  set :views, settings.root + '/view'
  set :public_folder, File.dirname(__FILE__) + '/public'

  get '/:attr/:type/:idate/?:edate?.json' do
    idate = parsedate(params[:idate])
    edate = params[:edate] ? parsedate(params[:edate]) : Time.now
    type_instances = redis.zrangebyscore(params[:type], idate.to_i, edate.to_i).map{|json| JSON.parse(json)}.uniq{|inst| inst['expiration_date']}

    data = {}
    type_instances.each do |type_instance|
      expiration_date = type_instance['expiration_date']
      instancekey = type_instance['key']
      data[expiration_date] = redis.zrangebyscore(instancekey, idate.to_i, edate.to_i).map do |attributes_key|
        attrs = JSON.parse(redis.get(attributes_key))
        {
          date: attrs['date'],
          value: attrs[params[:attr]]['min']
        }
      end
    end

    JSON.dump(
      type: params[:type],
      data: data
    )
  end

  get '/:attr/:type/:idate/?:edate?' do
    erb :index
  end
end
