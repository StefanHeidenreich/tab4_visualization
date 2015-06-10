class Tab4Controller < ApplicationController


  def report
    opts = { }
    opts[:entities] = params[:hashtag] if params[:hashtag].present?
    opts[:exclude] = params[:exclude] if params[:exclude].present?
    opts[:categories] = ["", :p, :pu, :ps, :pg, :pf, :pl, :pp, :px, :j, :i, :u]
    opts[:no_stats] = true
    if @scopes = params[:scopes]
      @scopes = @scopes.to_s.split(',') unless @scopes.is_a?(Array)
      opts[:scopes] = @scopes
    end
    if @sample = params[:sample].present?
      opts[:sample] = true
    end

    @days = (params[:days] || 1).to_i
    @max_age = @days * 24.hours
    resolution = (@days == 1 or params[:resolution] == 'hourly') ? :hourly : :daily
    d = @end_date = Date.today
    if date = params[:date] || params[:end_date]
      d = @end_date = Time.zone.parse(date).to_date
      if date =~ /^\d+\-\d+\-\d+\s+\d+:\d+$/  # includes time
        @t = Time.zone.parse(date).end_of_minute.utc
      else
        @t = d.end_of_day.utc
      end
    elsif resolution == :hourly
      # beginning of hour
      t = Time.zone.now
      @t = Time.zone.local(t.year, t.month, t.day, t.hour).utc - 1
    else
      @t = Time.zone.now.beginning_of_day.utc - 1
    end
    if d0 = params[:start_date]
      @start_date = Time.zone.parse(d0).to_date
      @days = (@end_date - @start_date + 1).to_i
      params[:days] = @days.to_s
      if d0 =~ /^\d+\-\d+\-\d+\s+\d+:\d+$/  # includes time
        @max_age = (@t.to_i - Time.zone.parse(d0).to_i)
      else
        @max_age = (@t - (d - @days + 1).beginning_of_day.utc).round
      end
    end

    # determine resolution (minutely, hourly, daily)
    resolution = begin
      params[:resolution].presence.try(:to_sym) ||
          case @max_age
            when 0...3.hours
              :minutely
            when 3.hours...3.days
              :hourly
            else
              :daily
          end
    end

    opts[:only] = [] # [:user_cats]
    if resolution == :hourly
      opts[:only] << :hourly_ranked_hashtags
      opts[:only] += [:hourly_uber_cat, :top_tweets_uber_cat]
    else
      opts[:only] << :daily_ranked_hashtags
      opts[:only] += [:daily_uber_cat, :top_tweets_uber_cat]
    end
    opts[:t] = @t
    opts[:max_age] = @max_age
    opts[:limit] = 10
    opts[:top_tweets_limit] = 10

    if cat = params[:user_category]
      cat = nil if cat == 'none'
      opts[:user_category] = cat
    end

    respond_to do |format|
      @cached = HashTweet.cached_hashtags(opts.dup)

      # fill up tweets
      min_recent_tweet_count = { 7.days => 10, 24.hours => 1 }

      Rails.logger.debug "REPORTZZZ Time.now.to_i -> #{Time.now.to_i}"
      (@cached.top_tweets_uber_cat || {}).each_pair do |hashtag,tweets|
        Rails.logger.debug "REPORTZZZ #{hashtag} : tweets from #{tweets.map{ |t| t['p'].to_i }.sort.reverse.join(', ')}"
        min_recent_tweet_count.each_pair do |period,min_count|
          next if @max_age <= period
          limit = min_count - tweets.count{ |t| t['p'] >= (@t - period) }
          Rails.logger.debug "REPORTZZZ #{hashtag} : loading #{limit} more tweets for last #{period}..."
          if limit > 0
            cached2 = HashTweet.cached_hashtags(opts.merge(
                                                    max_age: period,
                                                    only: :top_tweets_uber_cat,
                                                    hashtags: [hashtag],
                                                    top_tweets_limit: limit,
                                                    exclude_tweet_ids: @cached.top_tweets_uber_cat[hashtag].map{ |t| t['i'] }
                                                ))
            @cached.top_tweets_uber_cat[hashtag] += cached2.top_tweets_uber_cat[hashtag]
          end
        end
      end

      format.json { render :partial => 'report_data.json', :layout => false }
    end
  end
end
