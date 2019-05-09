require 'rails_helper'

describe 'Reviewables rake tasks', if: defined?(Reviewable) do
  before do
    Rake::Task.clear
    Discourse::Application.load_tasks
  end

  describe '#migrate_sift_reviews' do
    let(:post) { Fabricate(:post) }

    before do
      @sift_response = { response: false, topics: { "10" => 3 } }
      post.custom_fields[DiscourseSift::RESPONSE_CUSTOM_FIELD] = @sift_response
      post.save_custom_fields(true)
    end

    %w[pass_policy_guide auto_moderated].each do |state|
      it "Does not migrate post that were tagged as #{state}" do
        DiscourseSift.move_to_state(post, state)

        run_migration
        created_reviewables = ReviewableSiftPost.count

        expect(created_reviewables).to be_zero
      end
    end

    let(:admin) { Fabricate(:admin) }
    let(:system_user) { Discourse.system_user }

    %w[confirmed_failed confirmed_passed dismissed].each do |state|
      it "Migrates posts that were tagged as #{state}" do
        DiscourseSift.move_to_state(post, state)
        log_action(admin, post, state)
        actions_to_perform = 2

        run_migration
        reviewable = ReviewableSiftPost.includes(:reviewable_histories).last
        reviewable_participants = reviewable.reviewable_histories.pluck(:created_by_id)

        assert_review_was_created_correctly(reviewable, state)
        expect(reviewable_participants).to eq [system_user.id, admin.id]
      end
    end

    it 'Migrates posts needing review and leaves them ready to be reviewed with the new API' do
      state = 'requires_moderation'
      DiscourseSift.move_to_state(post, state)
      actions_to_perform = 1

      run_migration
      reviewable = ReviewableSiftPost.includes(:reviewable_histories).last
      reviewable_participants = reviewable.reviewable_histories.pluck(:created_by_id)

      assert_review_was_created_correctly(reviewable, state)
      expect(reviewable_participants).to eq [system_user.id]
    end

    def assert_review_was_created_correctly(reviewable, state)
      expect(reviewable.status).to eq reviewable_status_for(state)
      expect(reviewable.target_id).to eq post.id
      expect(reviewable.topic_id).to eq post.topic_id
      expect(reviewable.reviewable_by_moderator).to eq true
      expect(reviewable.payload['post_cooked']).to eq post.cooked
      expect(reviewable.payload['sift']).to eq @sift_response.to_json
    end

    describe 'Migrating scores' do
      let(:innapropiate_type) { PostActionType.types[:inappropriate] }
      let(:type_bonus) { PostActionType.where(id: innapropiate_type).pluck(:score_bonus)[0] }

      it 'Creates a pending score for pending reviews' do
        state = 'requires_moderation'
        DiscourseSift.move_to_state(post, state)

        run_migration
        reviewable = ReviewableSiftPost.includes(:reviewable_scores).last
        score = reviewable.reviewable_scores.last

        assert_score_was_create_correctly(score, reviewable, state)
        expect(score.reviewed_by).to be_nil
        expect(score.take_action_bonus).to be_zero
        expect(score.score).to eq ReviewableScore.user_flag_score(reviewable.created_by) + type_bonus
      end

      %w[dismissed confirmed_failed confirmed_passed].each do |state|
        it "Creates an score with take action bonus when migrating a review with state: #{state} " do
          expected_bonus = 5.0
          DiscourseSift.move_to_state(post, state)
          log_action(admin, post, state)

          run_migration
          reviewable = ReviewableSiftPost.includes(:reviewable_scores).last
          score = reviewable.reviewable_scores.last

          assert_score_was_create_correctly(score, reviewable, state)
          expect(score.reviewed_by).to eq admin
          expect(score.take_action_bonus).to eq expected_bonus
          expect(score.score).to eq ReviewableScore.user_flag_score(reviewable.created_by) + type_bonus + expected_bonus
        end
      end

      def assert_score_was_create_correctly(score, reviewable, action)
        expect(score.user).to eq reviewable.created_by
        expect(score.status).to eq score_status_for(action)
        expect(score.reviewable_score_type).to eq innapropiate_type
        expect(score.created_at).to eq reviewable.created_at
      end

      def score_status_for(action)
        case action
        when 'requires_moderation'
          ReviewableScore.statuses[:pending]
        when 'dismissed'
          ReviewableScore.statuses[:ignored]
        when 'confirmed_failed'
          ReviewableScore.statuses[:agreed]
        else
          ReviewableScore.statuses[:disagreed]
        end
      end
    end

    def reviewable_status_for(state)
      reviewable_states = Reviewable.statuses
      case state
      when 'confirmed_failed'
        reviewable_states[:approved]
      when 'confirmed_passed'
        reviewable_states[:rejected]
      when 'dismissed'
        reviewable_states[:ignored]
      else
        reviewable_states[:pending]
      end
    end

    def log_action(admin, post, state)
      StaffActionLogger.new(admin).log_custom(state,
        post_id: post.id, topic_id: post.topic_id
      )
    end

    def run_migration
      Rake::Task['reviewables:migrate_sift_reviews'].invoke
    end
  end
end
