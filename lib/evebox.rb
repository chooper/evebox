require "eaal"

GOOGLE_CLIENT_ID = "357234107497-redpuvjaq8glmiponrcd1786jfrgpdo9.apps.googleusercontent.com"
GOOGLE_CLIENT_SECRET = "bLhe-QIvLKIWjaLcigxlEkcP"
SPREADSHEET_ID = ENV["SPREADSHEET_ID"] # FIXME

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

def character_balances
  chars = $eve.Characters.characters

  $eve.scope = "char"
  balances = {}
  chars.each do |c|
      balances[c.name] = $eve.AccountBalance("characterID" => c.characterID).accounts.select { |a| a.accountKey == "1000" }.first.balance
  end
  balances
end

def get_spreadsheet(spreadsheet_id)
  auth_token = OAuth2::AccessToken.from_hash(oauth2_client, {:refresh_token => ENV['DRIVE_REFRESH_TOKEN']})
  auth_token = auth_token.refresh!
  session = GoogleDrive.login_with_oauth(auth_token.token)
  session.spreadsheet_by_key(spreadsheet_id)
end

def update_balance_sheet()
  raise "No spreadsheet configured" if ENV["SPREADSHEET_ID"].nil?
  sheet_id = ENV["SPREADSHEET_ID"]

  spreadsheet = get_spreadsheet(sheet_id)
  w = spreadsheet.worksheets.first  # FIXME

  # fetch the balances from Eve
  balances = character_balances

  # initialize the header if it hasn't been set before
  headers = ["Date"] + balances.keys
  w.list.keys = headers if w.list.keys == []

  # check that headers match
  # if they change, it's probably because a list was renamed, added, moved, or removed
  unless w.list.keys == headers
    puts "#{board_name}: WARNING WARNING WARNING"
    puts "#{board_name}: Headers do not match; it's likely the board layout changed"
    puts "#{board_name}: Please fix the spreadsheet before continuing; skipping!"
    exit
  end

  # check for and handle date collisions (last write wins)
  today = Time.now.strftime("%-m/%-d/%Y")
  row_idx = w.num_rows - 2        # 1 for header, 1 for zero index

  unless w.list[row_idx]['Date'].to_s == today
    # add a new row if it's a new day
    w.max_rows = w.num_rows + 1
    row_idx += 1
  end

  # update the row
  w.list[row_idx]["Date"] = today
  balances.each { |k,v| w.list[row_idx][k] = v }

  # save the spreadsheet
  w.max_cols = w.num_cols
  w.save
  nil
end

