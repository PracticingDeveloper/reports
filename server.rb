require "sinatra"
require "sinatra/reloader"
require "pstore"
require "pp"


def difference(new_value, old_value)
  diff = (new_value - old_value)
  diff_s = diff > 0 ? "+#{'%.2f' % diff}" : '%.2f' % diff

  diff_s.rjust(20) + "#{('%.1f' % ((1 - (old_value.to_f / new_value)) * 100))}%".rjust(20)
end

set :bind, '0.0.0.0'

get "/" do
  content_type "text/plain"

  store = PStore.new("stats.store")
  out = ""
 
  store.transaction(:read_only) do
    yesterday = Hash.new(0).merge(store[Date.today-1]) 
    last_week = Hash.new(0).merge(store[Date.today-8])

    summary = ->(name, key) do 
      "#{name}: ".ljust(25) + "#{'%.2f' % yesterday[key]}".rjust(10) + "#{difference(yesterday[key], last_week[key])}\n\n".rjust(30)
    end

    out << "Summary (with change since last week):\n"
    out << "---------------------------------------------------------------------------\n\n"

    out << summary["30-day visitors", "visits_30_day"]
    out << summary["7-day visitors", "visits_7_day"]
    out << summary["1-day visitors", "visits_yesterday"]

    out << "............................................................................\n\n"
    out << summary["30-day GTB work days", "gtb_work_days"]
    out << summary["30-day GTB pay", "gtb_pay_last_30"]
    out << "............................................................................\n\n"
    out << summary["Subscribers", "subscriber_count"]
    out << summary["30-day Transfers", "transfers_last_30"]
    out << "............................................................................\n\n"
    out << summary["Twitter Followers", "twitter_followers"]
    out << summary["Twitter Mentioners", "twitter_mentioners"]
    out << summary["Twitter Linkers", "twitter_linkers"]
    out << "---------------------------------------------------------------------------\n\n\n"
    out << summary["30-day Slack chatters", "slack_participants_30_day"]
    out << summary["7-day Slack chatters", "slack_participants_7_day"]
    out << summary["1-day Slack chatters", "slack_participants_1_day"]
    out << "---------------------------------------------------------------------------\n\n"
    out << "TODO: Publication schedule stats, discourse, blog, etc.\n\n"
    out << "---------------------------------------------------------------------------\n\n\n"

    store.roots.sort.reverse_each do |date|
      out << "#{date}\n"
      out << "--------------------------\n\n"
      out << store[date].pretty_inspect
      out << "\n\n"
    end
  end

  out
end
