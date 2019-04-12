require 'rails_helper'
require_relative '../shared_examples/notify_user_examples.rb'

RSpec.describe 'ReviewableSiftPost', if: defined?(Reviewable) do
  let(:guardian) { Guardian.new }

  describe '#build_actions' do
    let(:reviewable) { ReviewableSiftPost.new }

    it 'Does not return available actions when the reviewable is no longer pending' do
      available_actions = (Reviewable.statuses.keys - [:pending]).reduce([]) do |actions, status|
        reviewable.status = Reviewable.statuses[status]
        an_action_id = :confirm_failed

        actions.concat reviewable_actions(guardian).to_a
      end

      expect(available_actions).to be_empty
    end

    it 'Adds the confirm failed action' do
      actions = reviewable_actions(guardian)

      expect(actions.has?(:confirm_failed)).to be true
    end

    it 'Adds the allow action' do
      actions = reviewable_actions(guardian)

      expect(actions.has?(:allow)).to be true
    end

    it 'Adds the ignore action' do
      actions = reviewable_actions(guardian)

      expect(actions.has?(:ignore)).to be true
    end

    def reviewable_actions(guardian)
      Reviewable::Actions.new(reviewable, guardian, {}).tap do |actions|
        reviewable.build_actions(actions, guardian, {})
      end
    end
  end

  describe 'Performing actions over reviewables' do
    let(:admin) { Fabricate(:admin) }
    let(:post) { Fabricate(:post) }
    let(:reviewable) { ReviewableSiftPost.needs_review!(target: post, created_by: admin) }

    shared_examples 'It logs actions in the staff actions logger' do
      it 'Creates a UserHistory that reflects the action taken' do
        perform_action

        admin_last_action = UserHistory.find_by(post: post)

        assert_history_reflects_action(admin_last_action, admin, post, action_name)
      end

      def assert_history_reflects_action(action, admin, post, action_name)
        expect(action.custom_type).to eq action_name
        expect(action.post_id).to eq post.id
        expect(action.topic_id).to eq post.topic_id
      end

      it 'Returns necessary information to update reviewable creator user stats' do
        result = perform_action

        update_flag_stats = result.update_flag_stats

        expect(update_flag_stats[:status]).to eq flag_stat_status
        expect(update_flag_stats[:user_ids]).to match_array [reviewable.created_by_id]
      end
    end

    describe '#perform_confirm_failed' do
      let(:action) { :confirm_failed }
      let(:action_name) { 'sift_confirmed_failed' }
      let(:flag_stat_status) { :agreed }

      it_behaves_like 'It logs actions in the staff actions logger'

      let(:sift_reason) { 'sift_has_moderated' }
      it_behaves_like 'It notifies users when the setting is enabled'

      it 'Destroys the post if necessary' do
        result = perform_action

        reviewed_post = post.reload

        expect(post.deleted_at).to be_present
      end

      it 'changes reviewable status to approved' do
        result = perform_action

        expect(result.transition_to).to eq :approved
      end
    end

    describe '#perform_allow' do
      let(:action) { :allow }
      let(:action_name) { 'sift_confirmed_passed' }
      let(:flag_stat_status) { :disagreed }

      it_behaves_like 'It logs actions in the staff actions logger'

      it 'Recovers the post' do
        perform_action

        recovered_post = post.reload

        expect(recovered_post.deleted_at).to be_nil
        expect(recovered_post.deleted_by).to be_nil
      end

      it 'Does not try to recover the post if it was already recovered' do
        post.update(deleted_at: nil)
        event_triggered = false

        DiscourseEvent.on(:post_recovered) { event_triggered = true }
        perform_action

        expect(event_triggered).to eq false
      end

      it 'changes reviewable status to rejected' do
        result = perform_action

        expect(result.transition_to).to eq :rejected
      end
    end

    describe '#perform_dismiss' do
      let(:action) { :ignore }
      let(:action_name) { 'sift_ignored' }
      let(:flag_stat_status) { :ignored }

      it_behaves_like 'It logs actions in the staff actions logger'

      it 'changes reviewable status to ignored' do
        result = perform_action

        expect(result.transition_to).to eq :ignored
      end
    end

    def perform_action
      reviewable.perform admin, action
    end
  end
end
