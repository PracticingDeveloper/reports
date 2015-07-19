require "stripe"
require "dotenv"

require "google_drive"
require 'google/api_client'
require 'google/api_client/client_secrets'
require 'google/api_client/auth/installed_app'
require 'google/api_client/auth/storage'
require 'google/api_client/auth/storages/file_store'
require 'fileutils'

Dotenv.load

APPLICATION_NAME = 'Drive API Quickstart'
CLIENT_SECRETS_PATH = 'client_secret.json'
CREDENTIALS_PATH = File.join(Dir.home, '.credentials',
                             "drive-quickstart.json")
SCOPE = 'https://www.googleapis.com/auth/drive.readonly https://www.googleapis.com/auth/analytics.readonly'

##
# Ensure valid credentials, either by restoring from the saved credentials
# files or intitiating an OAuth2 authorization request via InstalledAppFlow.
# If authorization is required, the user's default browser will be launched
# to approve the request.
#
# @return [Signet::OAuth2::Client] OAuth2 credentials
def authorize
  FileUtils.mkdir_p(File.dirname(CREDENTIALS_PATH))

  file_store = Google::APIClient::FileStore.new(CREDENTIALS_PATH)
  storage = Google::APIClient::Storage.new(file_store)
  auth = storage.authorize

  if auth.nil? || (auth.expired? && auth.refresh_token.nil?)
    app_info = Google::APIClient::ClientSecrets.load(CLIENT_SECRETS_PATH)
    flow = Google::APIClient::InstalledAppFlow.new({
      :client_id => app_info.client_id,
      :client_secret => app_info.client_secret,
      :scope => SCOPE})
    auth = flow.authorize(storage)
    puts "Credentials saved to #{CREDENTIALS_PATH}" unless auth.nil?
  end
  auth
end


Stripe.api_key = ENV['STRIPE_API_KEY']

loop do
  puts "------------------------------"
  puts "Retreiving data"

  # Initialize the API
  client = Google::APIClient.new(:application_name => APPLICATION_NAME)
  client.authorization = authorize

  session = GoogleDrive.login_with_oauth(client.authorization.access_token)

  api_method = client.discovered_api('analytics','v3').data.ga.get

  result = client.execute(:api_method => api_method, :parameters => {
    'ids'        => ENV["GA_ID"],
    'start-date' => (Date.today - 30).to_s,
    'end-date'   => (Date.today - 1).to_s,
    'metrics'    => 'ga:users',
  })

  puts "People visiting the site in the last 30 days: #{result.data.rows[0][0]}"

  result = client.execute(:api_method => api_method, :parameters => {
    'ids'        => ENV["GA_ID"],
    'start-date' => (Date.today - 7).to_s,
    'end-date'   => (Date.today - 1).to_s,
    'metrics'    => 'ga:users',
  })

  puts "People visiting the site in the last week: #{result.data.rows[0][0]}"

  result = client.execute(:api_method => api_method, :parameters => {
    'ids'        => ENV["GA_ID"],
    'start-date' => (Date.today).to_s,
    'end-date'   => (Date.today).to_s,
    'metrics'    => 'ga:users',
  })

  puts "People visiting the site today: #{result.data.rows[0][0]}"

  ws = session.spreadsheet_by_key(ENV["TIMESHEET_KEY"]).worksheets[0]

  # Dumps all cells.
  data = (2..ws.num_rows).map { |row|
    [Date.strptime(ws[row,1], "%m/%d/%Y"), ws[row,2][1..-1].to_f]
  }

  gtb_pay = data.select { |a,b| a > Date.today - 31 }.reduce(0) { |s, (a,b)| s + b }
  gtb_days = gtb_pay / ENV["DAY_PAY"].to_i

  puts "GTB Billed in last 30 days: #{gtb_days} days ($#{gtb_pay.round})"

  last = nil
  subscribers = []

  loop do
    results = Stripe::Customer.all(:starting_after => last, :limit => 100)
    subscribers += results["data"].select { |c| c["subscription"] }

    last = results["data"].last

    break unless results["has_more"]
  end

  puts "Subscribers: #{subscribers.count}"


  rev =  Stripe::Transfer.all(:date => { :gt => (Date.today - 31).to_time.to_i }, 
                             :limit => 100).map { |e| e["amount"] }.reduce(:+) / 100.0

  puts "Last 30 days transfers: $#{rev}"

  puts "Twitter followers: #{`t followers | wc -l`}"

  mentioners = `t mentions -n 400 -c | ruby -e "require 'csv'; puts CSV.parse(ARGF.read)[1..-1].select { |e| Date.parse(e[1]) > Date.today - 14 }.map { |e| e[2] }.uniq.count"`

  linkers = `t search all 'practicingruby.com' -c | ruby -e "require 'csv'; puts CSV.parse(ARGF.read)[1..-1].select { |e| Date.parse(e[1]) > Date.today - 14 }.map { |e| e[2] }.uniq.count"`


  puts "People mentioning @practicingruby in past 14 days: #{mentioners}"
  puts "People tweeting links to practicingruby.com recently: #{linkers}"

  puts "Resting for five minutes, see you soon!"
  sleep 300
end