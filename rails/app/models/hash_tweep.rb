class HashTweep
  include Mongoid::Document

  field :i, :as => :twitter_id, type: Integer
  field :t, :as => :timestamp
  field :n, :as => :name
  field :h, :as => :screen_name # h for handle
  field :j, :as => :screen_name_lower # next free letter after h
  field :l, :as => :location
  field :d, :as => :description
  field :u, :as => :url
  field :p, :as => :protected, type: Boolean
  field :e, :as => :follower_ids, type: Array
  field :k, :as => :friend_ids, type: Array
  field :f, :as => :follower_count, type: Integer
  field :o, :as => :friend_count, type: Integer # o for outgoing connections
  field :ll, :as => :listed_count, type: Integer
  field :r, :as => :registered_at, type: DateTime
  field :ff, :as => :favorite_count, type: Integer
  field :to, :as => :utc_offset, type: Integer
  field :tz, :as => :time_zone
  field :g, :as => :geo_enabled, type: Boolean
  field :v, :as => :verified, type: Boolean
  field :c, :as => :tweet_count, type: Integer
  field :ln, :as => :lang
  field :im, :as => :profile_image_url
  field :b, :as => :profile_use_background_image
  field :dp, :as => :default_profile, type: Boolean
  field :di, :as => :default_profile_image, type: Boolean

  # non-persistent fields for easier access
  field :y,  :as => :category
  field :cc,  :as => :count

  API_FIELDS_MAPPING = {
    :i  =>   :id,          # twitter_id
    :n  =>   :name,
    :h  =>   :screen_name,
    :l  =>   :location,
    :d  =>   :description,
    :u  =>   :url,
    :p  =>   :protected,
    :f  =>   :followers_count,
    :o  =>   :friends_count,
    :ll =>   :listed_count,
    :r  =>   :created_at,
    :ff =>   :favourites_count,
    :to =>   :utc_offset,
    :tz =>   :time_zone,
    :g  =>   :geo_enabled,
    :v  =>   :verified,
    :c  =>   :statuses_count,
    :ln =>   :lang,
    :im =>   :profile_image_url,
    :b  =>   :profile_use_background_image,
    :dp =>   :default_profile,
    :di =>   :default_profile_image
  }

  CATEGORIES = [
    # Politician
    :pud, # Union → CDU
    :pus, # Union → CSU
    :ps,  # SPD
    :pg,  # Grüne
    :pf,  # FDP
    :pl,  # Linke
    :pp,  # Piraten
    :px,  # Other

    # Interest group (Interessensvertreter)
    :ic,  # corporate (Unternehmen/Verbände)
    :in,  # NGOs, civil

    # Journalist
    :jm,  # media
    :ji,  # non-media (Blogger/independent)

    # User
    :u,

    # Marked for review
    :y,

    # Irrelevant
    :z
  ]
end
