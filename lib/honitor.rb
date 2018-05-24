# frozen_string_literal: true

require 'dotenv/load'
require 'colorize'
require 'yaml'

Dir[File.dirname(__FILE__) + '/**/*.rb'].each { |file| require file }

class Honitor
  def initialize(instance:)
    @instance = instance

    start
  end

  def start
    read_config
    switch_log(@user_config.log)
    mkdir 'logs'
    check_changes
  end

  def check_changes
    loop do
      page = MechanizeBot.new(link: @user_config.link, dom_class: @user_config.dom_class)
      @current_dom_objects = HonitorHelpers::Mechanize.beautify(xml_list: page.fetch_dom_objects)

      prepare_message

      @old_dom_objects = @current_dom_objects

      sleep @user_config.interval unless @user_config.random
      sleep(rand(1..@user_config.interval))
    end
  end

  def prepare_message
    if no_changes?
      message = " Found #{@current_dom_objects.count} items || " + 'No changes'.yellow
    else
      new_changes = @current_dom_objects - @old_dom_objects
      message = " Found new #{new_changes.count} items || " + 'Sent message!'.blue
      PushoverApi.send_push_notification(
        message: "On #{@user_config.name} there are #{new_changes.count} updated items."
      )
    end

    puts HonitorHelpers::Log.show_time.to_s.green + message
    puts @current_dom_objects
    puts
  end

  def no_changes?
    @old_dom_objects.nil? || @old_dom_objects == @current_dom_objects
  end

  def read_config
    config = YAML.load_file("configs/#{@instance}.yml")

    @user_config = UserConfig.new(config['config'])
  end

  def switch_log(log)
    if log
      puts "Log will be saved in logs/#{@instance}.log"
      $stdout.reopen("logs/#{@instance}.log", 'a')
      $stdout.sync = true
    end

    puts 'Log is turned off'
  end

  def mkdir(name)
    FileUtils.mkdir_p(name) unless File.directory?(name)
  end
end
