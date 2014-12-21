require "eaal"

GOOGLE_CLIENT_ID = "357234107497-redpuvjaq8glmiponrcd1786jfrgpdo9.apps.googleusercontent.com"
GOOGLE_CLIENT_SECRET = "bLhe-QIvLKIWjaLcigxlEkcP"
SPREADSHEET_ID = ''

# Monkey patch
ENV.instance_eval do
  def source(filename)
    return {} unless File.exists?(filename)

    env = File.read(filename).split("\n").inject({}) do |hash, line|
      if line =~ /\A([A-Za-z_0-9]+)=(.*)\z/
        key, val = [$1, $2]
        case val
          when /\A'(.*)'\z/ then hash[key] = $1
          when /\A"(.*)"\z/ then hash[key] = $1.gsub(/\\(.)/, '\1')
          else hash[key] = val
        end
      end
      hash
    end

    env.each { |k,v| ENV[k] = v unless ENV[k] }
  end
end

def save_env!
  File.open(".env", "w") do |f|
    f.puts "EVE_KEY_ID=#{ENV['EVE_KEY_ID']}"
    f.puts "EVE_TOKEN=#{ENV['EVE_TOKEN']}"
    f.puts "DRIVE_REFRESH_TOKEN=#{ENV['DRIVE_REFRESH_TOKEN']}"
    f.close
  end
end

def oauth2_client
  OAuth2::Client.new(
      GOOGLE_CLIENT_ID, GOOGLE_CLIENT_SECRET,
      :site => "https://accounts.google.com",
      :token_url => "/o/oauth2/token",
      :authorize_url => "/o/oauth2/auth")
end

def setup_tokens
  ENV.source(".env")

  if (ENV["EVE_TOKEN"].nil? or ENV["EVE_TOKEN"].empty?) or (ENV["EVE_KEY_ID"].nil? or ENV["EVE_KEY_ID"].empty?)
    puts "No Eve Token available."
    puts "Please visit the following URL to get a token:"
    puts "https://community.eveonline.com/support/api-key/update/"
    puts ""
    STDOUT.write "Enter the key id here: "
    STDOUT.flush
    key = gets
    if key.empty?
      puts "No key... exiting."
      exit
    end

    STDOUT.write "Enter the token here: "
    STDOUT.flush
    token = gets
    if token.empty?
      puts "No token... exiting."
      exit
    end

    key.chomp!
    token.chomp!
    ENV["EVE_KEY_ID"] = key
    ENV["EVE_TOKEN"] = token
    save_env!
  end

  if ENV["DRIVE_REFRESH_TOKEN"].nil? or ENV["DRIVE_REFRESH_TOKEN"].empty?
    client = oauth2_client
    auth_url = client.auth_code.authorize_url(
        :redirect_uri => "urn:ietf:wg:oauth:2.0:oob",
        :scope => "https://spreadsheets.google.com/feeds/")

    puts "No Google Drive token available."
    puts "Please visit the following URL to get a token:"
    puts auth_url
    puts ""
    STDOUT.write "Enter the displayed authorization code here: "
    STDOUT.flush
    authorization_code = gets
    if authorization_code.empty?
      puts "No authorization code... exiting."
      exit
    end

    authorization_code.chomp!
    auth_token = client.auth_code.get_token(
        authorization_code, :redirect_uri => "urn:ietf:wg:oauth:2.0:oob")
    ENV['DRIVE_REFRESH_TOKEN'] = auth_token.refresh_token

    save_env!
  end

  $eve = EAAL::API.new(ENV["EVE_KEY_ID"], ENV["EVE_TOKEN"])
  puts "Character Name => Character ID"
  $eve.Characters.characters.each { |c| puts "#{c.name} => #{c.characterID}" }
  puts "Welcome to EveBox!"
  puts "API references is at:"
  puts "http://wiki.eve-id.net/APIv2_Page_Index"
end

def get_spreadsheet(spreadsheet_id)
  auth_token = OAuth2::AccessToken.from_hash(oauth2_client, {:refresh_token => ENV['DRIVE_REFRESH_TOKEN']})
  auth_token = auth_token.refresh!
  session = GoogleDrive.login_with_oauth(auth_token.token)
  session.spreadsheet_by_key(spreadsheet_id)
end

