class HashTweet
  include Mongoid::Document

  field :i, :as => :twitter_id
  field :rc, :as => :retweet_count, type: Integer
  field :rs, :as => :ranking_score
  field :t, :as => :text
  field :tr, :as => :truncated, type: Boolean
  field :ui, :as => :user_id
  field :n, :as => :user_name
  field :sn, :as => :user_screen_name
  field :p, :as => :published_at, type: DateTime
  field :g, :as => :german_time, type: DateTime
  field :x, :as => :scope, type: Integer
  field :h, :as => :hashtags, type: Array
  field :m, :as => :mentions, type: Array
  field :u, :as => :urls, type: Array
  field :l, :as => :links, type: Array
  field :r, :as => :retweet_of
  field :ri, :as => :retweeted_user_id
  field :rn, :as => :retweeted_user_name
  field :rsn, :as => :retweeted_user_screen_name
  field :sns, :as => :retweets # only used as aggregate result shortcut
  field :s, :as => :possibly_sensitive, type: Boolean
  field :y, :as => :user_category # see HashTweep
  field :z, :as => :user_rank # used for sampling tweeps
  field :a, :as => :reach, type: Integer


  # for reference only!
  # indexes are handled through migrations now
  index( x: 1, p: 1 ) # for results retrieval
  index( x: 1, h: 1, p: 1 ) # for tweets retrieval, by hashtag
  index( x: 1, m: 1, p: 1 ) # for tweets retrieval, by mention
  index( x: 1, l: 1, p: 1 ) # for tweets retrieval, by link
  index( x: 1, y: 1, p: 1 ) # for report user listing per user_category
  index( sn: 1 ) # for updating user categories
  index( {ui: 1},{background: true}) # for updating ranking_scores

  API_FIELDS_MAPPING = {
    :i =>    :id,                #twitter_id,    # numeric
    :rc =>   :retweet_count,     #retweet_count, # integer
    :t =>    :text,              #text,
    :p =>    :created_at,        #published_at,  # datetime
    :tr =>   :truncated,         #truncated,     # boolean
    :ui =>   'user.id',          #user_id,       # numeric
    :sn =>   'user.screen_name', #user_screen_name, # string
    :n =>    'user.name',        #user_name,     # string
    :a =>    'user.followers_count', # reach     # numeric
    :r =>   ['retweeted_status.id', :id],  #retweet_of,    # numeric id
    :ri =>  ['retweeted_status.user.id', 'user.id'],  #retweet_of_user_id, # string
    :rn =>  ['retweeted_status.user.name', 'user.name'],  #retweet_of_user_name, # string
    :rsn => ['retweeted_status.user.screen_name', 'user.screen_name'],  #retweet_of_user_screen_name, # string
    :s =>    :possibly_sensitive #possibly_sensitive # bool
  }

  scope :with_any_entity, lambda { |*args|
    h = Hash.new { |h,k| h[k] = [] }
    tokens = args.flatten.map(&:to_s).reject(&:blank?)
    tokens.each do |token|
      case token[0]
        when '#' then h[:hashtags] << token
        when '@' then h[:mentions] << token
        else          h[:links] << token
      end
    end
    cond = {}
    [:hashtags, :mentions, :links].each do |e|
      cond[e] = { '$in' => h[e] } unless h[e].empty?
    end
    self.any_of(cond)
  }

  # Returns the result of the ranking algorithm for the specified scope and parameters
  def self.cached_hashtags(constraints={})
    Rails.logger.info "CACHEZZZ called with #{constraints.inspect}"
    constraints = constraints.dup

    # extract the query parameters
    ranking_weight = constraints.delete(:ranking_weight).to_f
    follower_evaluation = constraints.delete(:follower_evaluation)
    term = constraints.delete(:term)
    scopes = constraints.delete(:scopes)
    scopes = nil if scopes.blank?
    sample = constraints.delete(:sample)
    s_entities = constraints.delete(:entities)
    x_entities = constraints.delete(:exclude) || []
    x_entities = x_entities.to_s.split(',') unless x_entities.is_a? Array
    cats = constraints.delete(:categories) || HashTweep::CATEGORIES.dup
    cats.map! &:to_s
    hashtags = constraints.delete(:hashtags)
    only = constraints.delete(:only)
    limit = constraints.delete(:limit) || constraints.delete(:per_page) || 11
    top_tweets_limit = constraints.delete(:top_tweets_limit) || limit
    skip = constraints.delete(:skip) || constraints.delete(:offset) || 0
    if page = constraints.delete(:page)
      skip = (page.to_i-1) * limit if page.to_i > 0
    end
    t = constraints.delete(:t) || Time.now
    max_age = (ma = constraints.delete(:max_age).to_i) > 0 ? ma : 24.hours
    selection_period = constraints.delete(:selection_period).try(:to_i) || max_age
    joint_time = t - max_age
    # parse entities
    entities = %w[top_tweets_uber_cat hourly_ranked_hashtags daily_ranked_hashtags hourly_uber_cat daily_uber_cat]
    case only
      when String
        entities = only.split(',') & entities
      when Array
        entities = only.map(&:to_s) & entities
      when Symbol
        entities = [ only ] if entities.include?(only.to_s)
    end
    entities.map!(&:to_sym)

    # initializing the result set (again, hashtags is not meaningful here)
    result = OpenStruct.new(
      t: t, max_age: max_age
    )

    # preparing MongoDB scope
    base_scope = self.where(constraints)
    base_scope = base_scope.in(:x => scopes) if scopes
    base_scope = base_scope.exists(:z => true) if sample
    base_scope = base_scope.with_any_entity(s_entities) if s_entities.present?
    scope = base_scope.between( published_at: joint_time..t )
    result.collection_scope = scope

    # Load data from MongoDB and compute new results.

    if :hourly_ranked_hashtags.in? entities
      results = HashTweet.collection.aggregate([
        { "$match" => scope.selector },
        { "$unwind" => "$h" },
        { "$match" => HashTweet.nin(hashtags: x_entities).selector },
        { "$project" => {
          "py" => { "$year" => "$g" },
          "pm" => { "$month" => "$g" },
          "pd" => { "$dayOfMonth" => "$g" },
          "ph" => { "$hour" => "$g" },
          "h"  => 1,
          "sn" => 1
        }},
        { "$group" => { "_id" => {
          "py" => "$py",
          "pm" => "$pm",
          "pd" => "$pd",
          "ph" => "$ph",
          "h" => "$h",
          "sn" => "$sn"
        }}},
        { "$group" => {
          "_id" => {
            "py" => "$_id.py",
            "pm" => "$_id.pm",
            "pd" => "$_id.pd",
            "ph" => "$_id.ph",
            "h" => "$_id.h"
          },
          "c" => { "$sum" => 1 }
        }},
        { "$group" => {
          "_id" => {
            "h" => "$_id.h"
          },
          "m" => { "$max" => "$c" },
          "a" => { "$avg" => "$c" }
        }},
        { "$project" => {
          "h"  => "$_id.h",
          "score" => { "$add" => ["$m", "$a"] }
        }},
        { "$sort" => { "score" => -1, "h" => 1 } },
        { "$skip" => skip },
        { "$limit" => limit }
      ])
      result[:hashtags] = results.map{ |h| [ h["h"], h["score"] ] }
      Rails.logger.debug "REPORTZZZ ranked_hashtags -> #{result[:hashtags].inspect}"
    end

    if :daily_ranked_hashtags.in? entities
      results = HashTweet.collection.aggregate([
        { "$match" => scope.selector },
        { "$unwind" => "$h" },
        { "$match" => HashTweet.nin(hashtags: x_entities).selector },
        { "$project" => {
          "py" => { "$year" => "$g" },
          "pm" => { "$month" => "$g" },
          "pd" => { "$dayOfMonth" => "$g" },
          "h"  => 1,
          "sn" => 1
        }},
        { "$group" => { "_id" => {
          "py" => "$py",
          "pm" => "$pm",
          "pd" => "$pd",
          "h" => "$h",
          "sn" => "$sn"
        }}},
        { "$group" => {
          "_id" => {
            "py" => "$_id.py",
            "pm" => "$_id.pm",
            "pd" => "$_id.pd",
            "h" => "$_id.h"
          },
          "c" => { "$sum" => 1 }
        }},
        { "$group" => {
          "_id" => {
            "h" => "$_id.h"
          },
          "m" => { "$max" => "$c" },
          "a" => { "$avg" => "$c" }
        }},
        { "$project" => {
          "h"  => "$_id.h",
          "score" => { "$add" => ["$m", "$a"] }
        }},
        { "$sort" => { "score" => -1, "h" => 1 } },
        { "$skip" => skip },
        { "$limit" => limit }
      ])
      result[:hashtags] = results.map{ |h| [ h["h"], h["score"] ] }
      Rails.logger.debug "REPORTZZZ ranked_hashtags -> #{result[:hashtags].inspect}"
    end

    # top_tweets_uber_cat, sorted and grouped by retweets
    if :top_tweets_uber_cat.in? entities
      Rails.logger.debug "REPORTZZZ top_tweets_uber_cat..."
      hashtags ||= result.hashtags ? (result.hashtags.map(&:first) - x_entities)[0...limit] : []
      results = {}
      this_scope = scope.nin( user_category: [:y, :z] )
      this_scope = this_scope.remove_scoping( HashTweet.exists(:z => true) ) if sample # don't restrict to sample
      this_scope = this_scope.nin( twitter_id: exclude_tweet_ids ) if exclude_tweet_ids.present?

      hashtags.each do |hashtag|
        results[hashtag] = HashTweet.collection.aggregate([
          { "$match" => this_scope.where(hashtags: hashtag).selector },

          # remove duplicates for multiple scopes
         ({ "$group" => {
            "_id" => "$i",
            "r" => { "$first" => "$r" },
            "i" => { "$first" => "$i" },
            "rc" => { "$first" => "$rc" },
            }} if sample or (scopes and scopes.length > 1)),

          { "$sort" => { "i" => 1 } },
          { "$group" => {
              "_id" => {
                "r" => "$r",
              },
              "i" =>   { "$first" => "$i" }, # twitter_id, min to guarantee original tweet
              "c" =>   { "$sum" => 1 }, # count
              "rc" =>   { "$last" => "$rc" }, # count
            }},
          { "$sort" => { "c" => -1 } },
          { "$limit" => top_tweets_limit },
        ].compact)
      end

      top_tweets_by_id = results.map_values do |hashtag,docs|
        docs.index_by{ |doc| doc['i'] }
      end

      tweet_ids = results.map_array do |hashtag,docs|
        docs.map do |doc|
          doc['i']
        end
      end.flatten.uniq

      tweets_by_id = this_scope.in(twitter_id: tweet_ids).only(:i, :p, :rsn, :sn, :t, :n, :y, :rc).index_by(&:twitter_id)

      results = results.map_values do |hashtag,docs|
        docs.map do |doc|
          tweets_by_id[doc['i']].tap do |t|
            until t.try(:user_category).blank? or t.user_category.in?(cats)
              t.user_category = t.user_category[0..-2]
            end
          end.try(:attributes)
        end
      end

      tweep_screen_names_lower = results.map_array do |hashtag,docs|
        docs.map do |doc|
          doc['rsn'].downcase
        end
      end.flatten.uniq

      tweeps_by_snl = Tame::TwitterUser.get_profiles(tweep_screen_names_lower, fields: [:h, :n, :im])

      result.top_tweets_uber_cat = results.map_values do |hashtag,docs|
        docs.map do |doc|
          HashTweet.new doc.merge(
            "rc"   => top_tweets_by_id[hashtag][doc['i']]['rc'],
            "user" => tweeps_by_snl[doc['rsn'].downcase].try(:attributes) || {}
          )
        end
      end
    end

    if :hourly_uber_cat.in? entities
      Rails.logger.debug "REPORTZZZ hourly uber categorized..."
      hashtags ||= result.hashtags ? (result.hashtags.map(&:first) - x_entities)[0...limit] : []

      results = HashTweet.collection.aggregate([
        { "$match" => scope.selector },
        { "$unwind" => "$h" },
        { "$match" => { "h" => {"$in" => hashtags} } },
        { "$project" => {
          "h"  => 1,
          "py" => { "$year" => "$g" },
          "pm" => { "$month" => "$g" },
          "pd" => { "$dayOfMonth" => "$g" },
          "ph" => { "$hour" => "$g" },
          "y"  => 1,
          "ui" => 1
        }},
        { "$group" => {
          "_id" => {
            "h"  => "$h",
            "py" => "$py",
            "pm" => "$pm",
            "pd" => "$pd",
            "ph" => "$ph",
            "y"  => "$y",
            "ui" => "$ui"
          }
        }},
        { "$group" => {
          "_id" => {
            "h"  => "$_id.h",
            "py" => "$_id.py",
            "pm" => "$_id.pm",
            "pd" => "$_id.pd",
            "ph" => "$_id.ph",
            "y"  => "$_id.y"
          },
          "c" => { "$sum" => 1 }
        }},
        { "$sort" => {
          "_id.py" => 1,
          "_id.pm" => 1,
          "_id.pd" => 1,
          "_id.ph" => 1,
        }}
      ].compact)
      cols = Hash.new{ |h,k| h[k] = Set.new }
      hashtags.each{ |h| cols[h] = Set.new }
      deep_data = Hash.new{ |h,k| h[k] = Hash.new{ |hh,kk| hh[kk] = {} } }
      results.each do |doc|
        id = doc['_id']
        hashtag = id['h']
        cat = id['y']
        next if cat.blank?
        cat = cat[0..-2] until cat.blank? or cat.in?(cats)
        next unless cat.in?(cats)
        t = Time.zone.local(id['py'], id['pm'], id['pd'], id['ph'])

        # handle category
        cols[hashtag].add cat
        deep_data[hashtag][t][cat] ||= 0
        deep_data[hashtag][t][cat] += doc['c']

        # sum up all super-categories
        # e.g. category 'asd' → add value to 'as', 'a', and '' as well
        (0...cat.length).each do |j|
          deep_data[hashtag][t][cat[0...j]] ||= 0
          deep_data[hashtag][t][cat[0...j]] += doc['c']
          cols[hashtag].add cat[0...j]
        end
      end
#        result.hourly_uber_cat = deep_data
      result.hourly_uber_cat = deep_data.map_values do |hashtag,flat_data|
        flat_data.map_array do |t,doc|
          doc.merge(t: t)
        end
      end
      result.hourly_uber_cat_cols = cols.map_values do |hashtag,colz|
        [:t] + (cats & colz.to_a) + [nil]
      end
    end

    if :daily_uber_cat.in? entities
      Rails.logger.debug "REPORTZZZ daily uber categorized..."
      hashtags ||= result.hashtags ? (result.hashtags.map(&:first) - x_entities)[0...limit] : []

      results = HashTweet.collection.aggregate([
        { "$match" => scope.selector },
        { "$unwind" => "$h" },
        { "$match" => { "h" => {"$in" => hashtags} } },
        { "$project" => {
          "h"  => 1,
          "py" => { "$year" => "$g" },
          "pm" => { "$month" => "$g" },
          "pd" => { "$dayOfMonth" => "$g" },
          "y"  => 1,
          "ui" => 1
        }},
        { "$group" => {
          "_id" => {
            "h"  => "$h",
            "py" => "$py",
            "pm" => "$pm",
            "pd" => "$pd",
            "y"  => "$y",
            "ui" => "$ui"
          }
        }},
        { "$group" => {
          "_id" => {
            "h"  => "$_id.h",
            "py" => "$_id.py",
            "pm" => "$_id.pm",
            "pd" => "$_id.pd",
            "y"  => "$_id.y"
          },
          "c" => { "$sum" => 1 }
        }},
        { "$sort" => {
          "_id.py" => 1,
          "_id.pm" => 1,
          "_id.pd" => 1,
        }}
      ].compact)
      cols = Hash.new{ |h,k| h[k] = Set.new }
      hashtags.each{ |h| cols[h] = Set.new }
      deep_data = Hash.new{ |h,k| h[k] = Hash.new{ |hh,kk| hh[kk] = {} } }
      results.each do |doc|
        id = doc['_id']
        hashtag = id['h']
        cat = id['y']
        next if cat.blank?
        cat = cat[0..-2] until cat.blank? or cat.in?(cats)
        next unless cat.in?(cats)
        t = Time.zone.local(id['py'], id['pm'], id['pd'])

        # handle category
        cols[hashtag].add cat
        deep_data[hashtag][t][cat] ||= 0
        deep_data[hashtag][t][cat] += doc['c']

        # sum up all super-categories
        # e.g. category 'asd' → add value to 'as', 'a', and '' as well
        (0...cat.length).each do |j|
          deep_data[hashtag][t][cat[0...j]] ||= 0
          deep_data[hashtag][t][cat[0...j]] += doc['c']
          cols[hashtag].add cat[0...j]
        end
      end
#        result.daily_uber_cat = deep_data
      result.daily_uber_cat = deep_data.map_values do |hashtag,flat_data|
        flat_data.map_array do |t,doc|
          doc.merge(t: t)
        end
      end
      result.daily_uber_cat_cols = cols.map_values do |hashtag,colz|
        [:t] + (cats & colz.to_a) + [nil]
      end
    end

    result
  end
end
