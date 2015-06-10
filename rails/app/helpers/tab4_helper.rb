module Tab4Helper
  def highchart_time(t)
    (t.to_i + t.utc_offset) * 1000
  end

  def highchart_tweets(tweets)
    tweets.sort_by(&:published_at).map do |tweet|
      tweet.attributes.delete('_id')
      tweet.attributes['user'].delete('_id')
      { type: 'tweet', date: highchart_time(tweet.published_at), data: tweet.attributes.merge('i' => tweet.twitter_id.to_s) }
    end
  end

  def recursive_data(data, cols, prefix)
    colz = cols.select{ |col| col.to_s.start_with?(prefix) and col.to_s.length == (prefix.length + 1) }
    colz.map do |cat|
      {
          node: cat,
          cat_id: cat,
          data: data.map do |row|
            [ highchart_time(row[:t]), row[cat].to_i ]
          end,
          subnodes: recursive_data(data, cols, cat)
      }
    end
  end
end