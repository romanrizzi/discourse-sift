require 'rails_helper'
require_relative '../shared_examples/notify_user_examples.rb'

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

        perform_action
      end
    end

    shared_examples 'It hides flagged posts' do
      it 'Soft deletes the post' do
        perform_action

        deleted_post = post.reload

        expect(post.deleted_at).to be_present
        expect(post.deleted_by).to eq Discourse.system_user
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

        perform_action
      end

      let(:sift_reason) { 'sift_auto_filtered' }
      it_behaves_like 'It notifies users when the setting is enabled'
      it_behaves_like 'It hides flagged posts'

      it 'Triggers a sift_auto_moderated event' do
        event_triggered = false

        DiscourseEvent.on(:sift_auto_moderated) { event_triggered = true }
        perform_action

        expect(event_triggered).to eq true
      end
    end

    describe 'When the post is classified as low risk' do
      before do
        SiteSetting.sift_hate_deny_level = 100000
        hate_topic_id = 10
        stub_response_with response: false, topics: { "#{hate_topic_id}" => 3 }
      end

      context 'Queued pending reviews as flagged posts' do
        before { SiteSetting.sift_use_standard_queue = true }

        it 'Creates a flag as a system user' do
          perform_action

          assert_post_action_was_created_by Discourse.system_user
        end

        it 'Creates another flag as a different user' do
          additional_flagger = Fabricate(:user)
          SiteSetting.sift_extra_flag_users = additional_flagger.username
          
          perform_action

          assert_post_action_was_created_by additional_flagger
        end

        it 'Creates a ReviewableFladdedPost', if: defined?(Reviewable) do
          perform_action

          expect(ReviewableFlaggedPost.exists?).to eq true
        end

        def assert_post_action_was_created_by user
          action = PostAction.find_by(user: user)

          expect(action.post).to eq post
          expect(action.post_action_type_id).to eq PostActionType.types[:inappropriate]
        end
      end

      context 'Do not queue pending reviews as flagged posts' do
        before { SiteSetting.sift_use_standard_queue = false }

        it 'Changes state to requires_moderation' do
          described_class.expects(:move_to_state).with(post, 'requires_moderation')
  
          perform_action
        end
  
        it 'Triggers a sift_post_failed_policy_guide event' do
          event_triggered = false
  
          DiscourseEvent.on(:sift_post_failed_policy_guide) { event_triggered = true }
          perform_action
  
          expect(event_triggered).to eq true
        end

        describe 'Queued pending reviews as ReviewableSiftPosts', if: defined?(Reviewable) do
          it 'Creates a new pending reviewable' do
            perform_action

            sift_reviewable = ReviewableSiftPost.last

            expect(sift_reviewable.status).to eq Reviewable.statuses[:pending]
            expect(sift_reviewable.post).to eq post
            expect(sift_reviewable.reviewable_by_moderator).to eq true
            expect(sift_reviewable.payload['post_cooked']).to eq post.cooked
          end

          it 'Creates a new score for the new reviewable' do
            perform_action
      
            reviewable_akismet_score = ReviewableScore.last
      
            expect(reviewable_akismet_score.user).to eq Discourse.system_user
            expect(reviewable_akismet_score.reviewable_score_type).to eq PostActionType.types[:inappropriate]
            expect(reviewable_akismet_score.take_action_bonus).to be_zero
          end
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

    def perform_action
      described_class.classify_post post
    end
  end
end