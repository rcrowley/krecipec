require 'erb'
require 'fileutils'
require 'rdiscount'
require 'sinatra/base'

class App < Sinatra::Base

  set :root, File.dirname(__FILE__)

  configure :production do
    set :dir, "/var/lib/krecipec"
  end
  configure :development do
    set :dir, "/tmp/krecipec"
  end

  set :allowed, %w{67.174.197.197}

  def initialize
    FileUtils.mkdir_p settings.dir
    FileUtils.mkdir_p File.join(settings.dir, "search")
    super
  end

  helpers do

    def slugify(name)
      name.strip.downcase.gsub(/\s/, "-").gsub(/[^0-9a-z-]/, "")
    end

    def deslugify(slug)
      slug.gsub(/-/, " ").capitalize
    end

    def save(slug, text)
      File.open File.join(settings.dir, slug), "w" do |f|
        f.write text
      end
    end

    def tagify(text)
      tags = text.split(" ")
      tags.map! { |tag| tag.downcase.gsub(/[^0-9a-z]/, "") }
      tags.reject! { |tag| 0 == tag.length }
      tags
    end

    def tag(slug, tags)
      tags.each do |tag|
        FileUtils.mkdir_p File.join(settings.dir, "search", tag)
        FileUtils.touch File.join(settings.dir, "search", tag, slug)
      end
    end

    def tags(slug)
      Dir[File.join(settings.dir, "search", "*", slug)].
        map(&File.method(:dirname)).
        map(&File.method(:basename))
    end

  end

  before do
    response["Cache-Control"] = "no-cache"
  end

  get "/favicon.ico" do
    404
  end

  get "/robots.txt" do
    404
  end

  get "/" do
    erb :index
  end

  post "/" do
    halt 403 unless settings.allowed.include?(request.env["REMOTE_ADDR"])
    slug = slugify(params[:name])
    save slug, params[:text]
    tags =
      tagify(params[:name]) +
      tagify(params[:text]) +
      tagify(params[:tags])
    tag slug, tags
    redirect "/#{slug}"
  end

  get "/all" do
    @results = Dir[File.join(settings.dir, "*")].
      reject(&File.method(:directory?))
    @results.sort! { |a, b| File.mtime(b) <=> File.mtime(a) }
    @results.map! &File.method(:basename)
    erb :search
  end

  get "/search" do
    @results = (params[:q] || "").split(" or ").map do |tags|
      sets = tags.split(" ").map do |tag|
        Dir[File.join(settings.dir, "search", tag, "*")]
      end.map { |set| Set.new(set) }
      sets.unshift(sets.shift & sets.shift) while 1 < sets.length
      sets.first.to_a
    end.flatten.uniq
    @results.sort! { |a, b| File.mtime(b) <=> File.mtime(a) }
    @results.map! &File.method(:basename)
    erb :search
  end

  get "/:slug/edit" do
    @name = deslugify(params[:slug])
    @text = File.read(File.join(settings.dir, params[:slug]))
    @tags = tags(params[:slug])
    erb :index
  end

  post "/:slug/delete" do
    File.unlink File.join(settings.dir, params[:slug])
    Dir[File.join(settings.dir, "search", "*", params[:slug])].
      map(&File.method(:unlink))
    redirect "/"
  end

  get "/:slug" do
    @name = deslugify(params[:slug])
    text = File.read(File.join(settings.dir, params[:slug]))
    @text = RDiscount.new(text, :smart).to_html.gsub("  ", "&nbsp; ")
    #@tags = tags(params[:slug])
    erb :render
  end

end
