require 'test_helper'

module PublishingApi::ConsultationPresenterTest
  class TestCase < ActiveSupport::TestCase
    attr_accessor :consultation

    setup do
      create(:current_government)
    end

    def presented_content
      PublishingApi::ConsultationPresenter.new(consultation).content
    end

    def assert_attribute(attribute, value)
      assert_equal value, presented_content[attribute]
    end

    def assert_details_attribute(attribute, value)
      assert_equal value, presented_content[:details][attribute]
    end

    def assert_payload(builder, data: -> { presented_content })
      builder_double = builder.demodulize.underscore
      payload_double = { :"#{builder_double}_key" => "#{builder_double}_value" }

      builder
        .constantize
        .expects(:for)
        .at_least_once
        .with(consultation)
        .returns(payload_double)

      actual_data = data.call
      expected_data = actual_data.merge(payload_double)

      assert_equal expected_data, actual_data
    end

    def assert_details_payload(builder)
      assert_payload builder, data: -> { presented_content[:details] }
    end
  end

  class BasicConsultationTest < TestCase
    setup do
      self.consultation = create(:consultation)
    end

    test 'base' do
      attributes_double = {
        base_attribute_one: 'base_attribute_one',
        base_attribute_two: 'base_attribute_two',
        base_attribute_three: 'base_attribute_three',
      }

      PublishingApi::BaseItemPresenter
        .expects(:new)
        .with(consultation)
        .returns(stub(base_attributes: attributes_double))

      actual_content = presented_content
      expected_content = actual_content.merge(attributes_double)

      assert_equal actual_content, expected_content
    end

    test 'body details' do
      body_double = Object.new

      govspeak_renderer = mock('Whitehall::GovspeakRenderer')

      govspeak_renderer
        .expects(:govspeak_edition_to_html)
        .with(consultation)
        .returns(body_double)

      Whitehall::GovspeakRenderer.expects(:new).returns(govspeak_renderer)

      assert_details_attribute :body, body_double
    end

    test 'description' do
      assert_attribute :description, consultation.summary
    end

    test 'document type' do
      assert_attribute :document_type, 'open_consultation'
    end

    test 'first public at details' do
      assert_details_payload 'PublishingApi::PayloadBuilder::FirstPublicAt'
    end

    test 'political details' do
      assert_details_payload 'PublishingApi::PayloadBuilder::PoliticalDetails'
    end

    test 'public document path' do
      assert_payload 'PublishingApi::PayloadBuilder::PublicDocumentPath'
    end

    test 'rendering app' do
      assert_attribute :rendering_app, 'whitehall-frontend'
    end

    test 'schema name' do
      assert_attribute :schema_name, 'consultation'
    end

    test 'validity' do
      assert_valid_against_schema presented_content, 'consultation'
    end
  end

  class UnopenedConsultationTest < TestCase
    setup do
      self.consultation = create(:unopened_consultation)
    end

    test 'document type' do
      assert_attribute :document_type, 'consultation'
    end
  end

  class OpenConsultationTest < TestCase
    setup do
      self.consultation = create(
        :open_consultation,
        closing_at: 1.day.from_now,
        opening_at: 1.day.ago,
      )
    end

    test 'closing date' do
      assert_details_attribute :closing_date, 1.day.from_now
    end

    test 'document type' do
      assert_attribute :document_type, 'open_consultation'
    end

    test 'opening date' do
      assert_details_attribute :opening_date, 1.day.ago
    end

    test 'validity' do
      assert_valid_against_schema presented_content, 'consultation'
    end
  end

  class OpenConsultationWithParticipationTest < TestCase
    setup do
      participation = create(:consultation_participation,
                             link_url: 'http://www.example.com')

      self.consultation = create(:open_consultation,
                                 consultation_participation: participation)
    end

    test 'document type' do
      assert_attribute :document_type, 'open_consultation'
    end

    test 'validity' do
      assert_valid_against_schema presented_content, 'consultation'
    end
  end

  class ClosedConsultationTest < TestCase
    setup do
      self.consultation = create('closed_consultation')
    end

    test 'document type' do
      assert_attribute :document_type, 'closed_consultation'
    end

    test 'validity' do
      assert_valid_against_schema presented_content, 'consultation'
    end
  end

  class ClosedConsultationWithFeedbackTest < TestCase
    setup do
      self.consultation = create(:closed_consultation)

      create(:consultation_public_feedback,
             consultation: consultation,
             summary: 'Public feedback summary')
    end

    test 'document type' do
      assert_attribute :document_type, 'closed_consultation'
    end

    test 'validity' do
      assert_valid_against_schema presented_content, 'consultation'
    end
  end

  class ClosedConsultationWithOutcomeTest < TestCase
    setup do
      self.consultation = create(:consultation_with_outcome)
    end

    test 'document type' do
      assert_attribute :document_type, 'consultation_outcome'
    end

    test 'validity' do
      assert_valid_against_schema presented_content, 'consultation'
    end
  end

  class ConsultationWithPublicTimestamp < TestCase
    setup do
      self.consultation = create(:consultation_with_outcome)

      consultation.stubs(public_timestamp: Date.new(1999),
                         updated_at: Date.new(2012))
    end

    test 'public updated at' do
      assert_attribute :public_updated_at,
                       '1999-01-01T00:00:00+00:00'
    end

    test 'validity' do
      assert_valid_against_schema presented_content, 'consultation'
    end
  end

  class ConsultationWithoutPublicTimestamp < TestCase
    setup do
      self.consultation = create(:consultation_with_outcome)

      consultation.stubs(public_timestamp: nil,
                         updated_at: Date.new(2012))
    end

    test 'public updated at' do
      assert_attribute :public_updated_at,
                       '2012-01-01T00:00:00+00:00'
    end

    test 'validity' do
      assert_valid_against_schema presented_content, 'consultation'
    end
  end

  class ConsultationHeldOnAnotherWebsite < TestCase
    setup do
      self.consultation = create(
        :open_consultation,
        external: true,
        external_url: 'https://example.com/link/to/consultation'
      )
    end

    test 'held on another website URL' do
      assert_details_attribute :held_on_another_website_url,
                               'https://example.com/link/to/consultation'
    end

    test 'validity' do
      assert_valid_against_schema presented_content, 'consultation'
    end
  end
end
