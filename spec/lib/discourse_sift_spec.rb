require 'rails_helper'

RSpec.describe DiscourseSift do
  before do
    SiteSetting.sift_enabled = true
    SiteSetting.sift_api_key = 'fake_key',
    SiteSetting.sift_api_url = 'https://test.siftapi.com'
  end

  describe 'Classifying a post' do
    let(:post) { Fabricate(:post) }

    describe 'When the post is not classified as a risk' do
      it 'Changes state to pass_policy_guide' do
        stub_response_with response: true

        described_class.expects(:move_to_state).with(post, 'pass_policy_guide')

        described_class.classify_post post
      end
    end

    shared_examples 'It hides flagged posts' do
      it 'Soft deletes the post' do
        described_class.classify_post post

        deleted_post = post.reload

        expect(post.deleted_at).to be_present
        expect(post.deleted_by).to eq Discourse.system_user
      end
    end

    shared_examples 'It notifies users when the setting is enabled' do
      it 'Notifies user if the setting is enabled' do
        SiteSetting.sift_notify_user = true

        SystemMessage.expects(:create).with(post.user, sift_reason, topic_title: post.topic.title).once

        described_class.classify_post post
      end

      it 'Does nothing when the setting is disabled' do
        SiteSetting.sift_notify_user = false

        SystemMessage.expects(:create).never

        described_class.classify_post post
      end
    end

    describe 'When the post is classified as high risk' do
      before do
        SiteSetting.sift_hate_deny_level = 2
        hate_topic_id = 10
        stub_response_with response: false, topics: { "#{hate_topic_id}" => 3 }
      end

      it 'Changes state to auto_moderated' do
        described_class.expects(:move_to_state).with(post, 'auto_moderated')

        described_class.classify_post post
      end

      let(:sift_reason) { 'sift_auto_filtered' }
      it_behaves_like 'It notifies users when the setting is enabled'
      it_behaves_like 'It hides flagged posts'

      it 'Triggers a sift_auto_moderated event' do
        event_triggered = false

        DiscourseEvent.on(:sift_auto_moderated) { event_triggered = true }
        described_class.classify_post post

        expect(event_triggered).to eq true
      end
    end

    describe 'When the post is classified as low risk' do
      before do
        SiteSetting.sift_hate_deny_level = 100000
        hate_topic_id = 10
        stub_response_with response: false, topics: { "#{hate_topic_id}" => 3 }
      end

      context 'Using the standard queue mode' do
        before { SiteSetting.sift_use_standard_queue = true }

        it 'Creates a flag as a system user' do
          described_class.classify_post post

          assert_post_action_was_created_by Discourse.system_user
        end

        it 'Creates another flag as a different user' do
          additional_flagger = Fabricate(:user)
          SiteSetting.sift_extra_flag_users = additional_flagger.username
          
          described_class.classify_post post

          assert_post_action_was_created_by additional_flagger
        end

        def assert_post_action_was_created_by user
          action = PostAction.find_by(user: user)

          expect(action.post).to eq post
          expect(action.post_action_type_id).to eq PostActionType.types[:inappropriate]
        end
      end

      context 'Using the custom sift queue' do
        before { SiteSetting.sift_use_standard_queue = false }

        it 'Changes state to requires_moderation' do
          described_class.expects(:move_to_state).with(post, 'requires_moderation')
  
          described_class.classify_post post
        end
  
        it 'Triggers a sift_post_failed_policy_guide event' do
          event_triggered = false
  
          DiscourseEvent.on(:sift_post_failed_policy_guide) { event_triggered = true }
          described_class.classify_post post
  
          expect(event_triggered).to eq true
        end

        context 'Hide posts while waiting for moderation' do
          before { SiteSetting.sift_post_stay_visible = false }
          it_behaves_like 'It hides flagged posts'

          let(:sift_reason) { 'sift_human_moderation' }
          it_behaves_like 'It notifies users when the setting is enabled'
        end
      end
    end

    def stub_response_with(risk_response)
      stub_request(:post, /test.siftapi.com/).to_return(status: 200, body: risk_response.to_json)
    end
  end
end