require "sinatra"
require "pstore"
require "pp"

set :bind, '0.0.0.0'

get "/" do
  content_type "text/plain"

  store = PStore.new("stats.store")
  out = ""
 
  store.transaction(:read_only) do
    yesterday = store[Date.today-1] 
    last_week = store[Date.today-8]

    out << "Summary (with change since last week):\n"
    out << "--------------------------\n\n"

    out << "Last 30 day visits: #{yesterday['visits_30_day']} (#{yesterday['visits_30_day'] - last_week['visits_30_day']}, #{'%.1f' % ((1 - last_week['visits_30_day']/yesterday['visits_30_day'].to_f)*100)}% )\n"


    out << "Last 7 day visits: #{yesterday['visits_7_day']} (#{yesterday['visits_7_day'] - last_week['visits_7_day']}, #{'%.1f' % ((1 - last_week['visits_7_day']/yesterday['visits_7_day'].to_f)*100)}% )"

    out << "\n\n"

    store.roots.sort.reverse_each do |date|
      out << "#{date}\n"
      out << "--------------------------\n\n"
      out << store[date].pretty_inspect
      out << "\n\n"
    end
  end

  out
end
