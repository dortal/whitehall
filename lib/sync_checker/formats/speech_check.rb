module SyncChecker
  module Formats
    class SpeechCheck < EditionBase
      def checks_for_live(_locale)
        super + [
          Checks::LinksCheck.new(
            "speaker",
            [edition_expected_in_live
              .role_appointment
              .person.content_id]
          ),
          Checks::LinksCheck.new(
            "policies",
            (edition_expected_in_live.try(:related_policies) || []).map(&:content_id)
          ),
          Checks::LinksCheck.new(
            "topical_events",
            ::TopicalEvent
              .joins(:classification_memberships)
              .where(classification_memberships: {edition_id: edition_expected_in_live.id})
              .pluck(:content_id)
          )
        ]
      end

      def expected_details_hash(speech, _locale)
        super.tap do |details|
          details.merge!(expected_delivered_on(speech))
          details.merge!(expected_government(speech))
          details.merge!(expected_image(speech))
          details.merge!(expected_political(speech))
          details.reject! { |k, _| k == :emphasised_organisations }
        end
      end

    private

      def expected_political(world_location_news_article)
        { "political" => world_location_news_article.political? }
      end

      def expected_delivered_on(speech)
        { "delivered_on" => speech.delivered_on.iso8601 }
      end

      def expected_government(speech)
        return {} unless speech.government

        {
          "government" => {
            "title" => speech.government.name,
            "slug" => speech.government.slug,
            "current" => speech.government.current?,
          }
        }
      end

      def expected_image(speech)
        speaker = speech.role_appointment.person if speech.role_appointment
        return {} unless speaker && speaker.image && speaker.image.url

        {
          "image" => {
            "alt_text" => speaker.name,
            "url" => speaker.image.url,
          }
        }
      end
    end
  end
end
