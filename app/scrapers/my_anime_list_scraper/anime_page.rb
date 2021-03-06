class MyAnimeListScraper
  class AnimePage < MediaPage
    using NodeSetContentMethod
    ANIME_URL = %r{\Ahttps://myanimelist.net/anime/(?<id>\d+)/[^/]+\z}

    def match?
      ANIME_URL =~ @url
    end

    def call
      super
      create_mapping('myanimelist/anime', external_id, media)
      scrape_async "#{@url}/episode" if subtype != :movie
    end

    def import
      super
      media.age_rating ||= age_rating
      media.age_rating_guide ||= age_rating_guide
      media.episode_count ||= episode_count
      media.episode_length ||= episode_length
      media.start_date ||= start_date
      media.end_date ||= end_date
      media.anime_productions += productions
      media.release_schedule ||= release_schedule
      media
    end

    def age_rating
      case rating_info.first
      when /\APG/i then :PG
      when /\AG\z/i then :G
      when /\AR\z/i then :R
      when /\ARx\z/i then :R18
      end
    end

    def age_rating_guide
      rating_info.last
    end

    def productions
      [
        *productions_in(information['Producers'], :producer),
        *productions_in(information['Licensors'], :licensor),
        *productions_in(information['Studios'], :studio)
      ].compact
    end

    def episode_length
      parts = information['Duration']&.content&.split(' ')
      parts.each_cons(2).reduce(0) do |duration, (number, unit)|
        case unit
        when /\Ahr/i then duration + (number.to_i * 60)
        when /\Amin/i then duration + number.to_i
        else duration
        end
      end
    end

    def episode_count
      information['Episodes']&.content&.to_i
    end

    def start_date
      aired[0]
    end

    def end_date
      aired[1]
    end

    def release_schedule
      schedule = information['Broadcast']&.content
      return if schedule.blank? || /Unknown/i =~ schedule
      matches = /(\w+)s at (\d\d:\d\d) \(JST\)/i.match(schedule)
      start_date = media.start_date.in_time_zone('Japan') - 23.hours
      duration = media.episode_length&.minutes

      IceCube::Schedule.new(start_date, duration: duration) do |s|
        time = Time.parse(matches[2])
        s.add_recurrence_rule(
          IceCube::Rule.weekly
            .day(matches[1].downcase.to_sym)
            .hour_of_day(time.hour)
            .minute_of_hour(time.min)
            .count(media.episode_count)
        )
      end
    end

    private

    def rating_info
      information['Rating']&.content&.split(' - ')&.map(&:strip)
    end

    def aired
      @aired ||= parse_date_range(information['Aired']&.content)
    end

    def productions_in(fragment, role)
      return [] if /None found/i =~ fragment.content
      fragment.css('a').map { |link| production_for(link, role) }
    end

    def production_for(link, role)
      id = %r{producer/(\d+)/}.match(link['href'])[1]
      producer = Mapping.lookup('myanimelist/producer', id) do
        Producer.where(name: link.content).first_or_create!
      end
      AnimeProduction.new(role: role, anime: media, producer: producer)
    end

    def external_id
      ANIME_URL.match(@url)['id']
    end

    def media
      @media ||= Mapping.lookup('myanimelist/anime', external_id) || Anime.new
    end
  end
end
