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
    let(:policy_failed_response) do
      {
        tokenized_solution: {
          text: "What's up losers???? This is stupid :wink:",
          slots: [
            { text: "what's", join_right: true, solution: "what's up", risk: 1, position: 6 },
            { text: 'up', join_left: true, solution: "what's up", risk: 1, position: 7 },
            { text: 'losers', solution: 'losers', risk: 3, position: 8 },
            { text: 'this', solution: 'this', risk: 1, position: 9 },
            { text: 'is', solution: 'is', risk: 2, position: 10 },
            { text: 'stupid', solution: 'stupid', risk: 3, position: 11 },
            { text: 'wink', solution: 'wink', risk: 1, position: 12 }
          ]
        },
        risk: 3,
        topics: { '0' => 3, '1' => 3 },
        hashed: "What's up losers???? This is stupid :wink:",
        response: false,
        escalations: [],
        trust: 4,
        events: nil
      }
    end

    describe 'When the post is not classified as a risk' do
      it 'Changes state to pass_policy_guide' do
        policy_passed_response = policy_failed_response.merge(response: true)
        stub_response_with(policy_passed_response)

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
        SiteSetting.sift_bullying_deny_level = 2
        bullying_id = '1'
        @risk_response = policy_failed_response.merge(topics: { bullying_id => 100 })
        stub_response_with(@risk_response)
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

      it 'Creates a new pending reviewable', if: defined?(Reviewable) do
        expected_transitions = 2

        perform_action

        assert_reviewable_was_created(:approved, expected_transitions)
      end
    end

    describe 'When the post is classified as low risk' do
      before do
        SiteSetting.sift_bullying_deny_level = 1000
        bullying_id = '1'
        @risk_response = policy_failed_response.merge(topics: { bullying_id => 2 })
        stub_response_with(@risk_response)
      end

      context 'Queued pending reviews as flagged posts' do
        before { SiteSetting.sift_use_standard_queue = true }

        it 'Creates a flag as a system user' do
          perform_action

          assert_post_action_was_created_by Discourse.system_user
        end

        it 'Creates a ReviewableFlaggedPost', if: defined?(Reviewable) do
          perform_action

          expect(ReviewableFlaggedPost.exists?).to eq true
        end

        def assert_post_action_was_created_by(user)
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
            expected_transitions = 1

            perform_action

            assert_reviewable_was_created(:pending, expected_transitions)
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

    def assert_reviewable_was_created(status, actions_count)
      sift_reviewable = ReviewableSiftPost.includes(:reviewable_histories).last

      expect(sift_reviewable.status).to eq Reviewable.statuses[status]
      expect(sift_reviewable.post).to eq post
      expect(sift_reviewable.reviewable_by_moderator).to eq true
      expect(sift_reviewable.payload['post_cooked']).to eq post.cooked
      expect(sift_reviewable.payload['sift']).to eq @risk_response.as_json
      expect(sift_reviewable.reviewable_histories.size).to eq actions_count
    end

    def stub_response_with(risk_response)
      stub_request(:post, /test.siftapi.com/).to_return(status: 200, body: risk_response.to_json)
    end

    def perform_action
      described_class.classify_post post
    end
  end
end
