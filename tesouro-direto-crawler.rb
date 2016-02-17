require "typhoeus"
require "nokogiri"
require "fileutils"

module SpreadsheetCrawler
  extend self

  YEARS = (2002..2016).to_a
  TYPES = %w{NTN-B\ Principal LFT LTN NTN-C NTN-B NTN-F}

  def each_spreadsheet(&block)
    doc = Nokogiri::HTML(File.read("./tesouro_direto_links.fragment.html"))

    all_refs = doc.css("a").map do |a|
      ref = a['href']
      if ref.start_with? 'http'
        ref
      else
        "http://www.tesouro.fazenda.gov.br" + ref
      end
    end

    refs = Hash.new

    all_refs.each do |ref|; TYPES.each do |type|
      filename = ref.match(%r{[^\/]+$})[0]
      year = filename.match(/\d{4}/)[0].to_i
      refs[year] ||= {}
      if is_of_type(filename, type)
        refs[year][type] = ref
        break
      end
    end; end

    hydra = Typhoeus::Hydra.new(max_concurrency: 20)
    refs.each_pair do |year, yrefs|
      yrefs.each_pair do |type, ref|
        req = Typhoeus::Request.new(ref)
        req.on_complete do |res|
          if res.success?
            block.call(res.body, year, type)
          else
            puts "Failed: #{year} #{type} #{ref}"
          end
        end
        hydra.queue(req)
      end
    end
    hydra.run
  end

  private
  def is_of_type(ref, type)
    ref.match(type.gsub(/\s/, '_')) ||
    ref.match(type.gsub(/[-\s]/, ''))
  end
end
