import SiftQueue from 'discourse/plugins/discourse-sift/admin/models/sift-queue';

function genericError() {
    bootbox.alert(I18n.t('generic_error'));
}

export default Ember.Controller.extend({
    sortedPosts: Ember.computed.sort('model', 'postSorting'),
    postSorting: ['id:asc'],
    enabled: false,
    performingAction: false,

    actions: {
        refresh() {
            this.set('performingAction', true);
            SiftQueue.findAll().then(result => {
                this.set('stats', result.stats);
                this.set('model', result.posts);
            }).catch(genericError).finally(() => {
                this.set('performingAction', false);
            });
        },

        confirmFailedPost(post) {
            this.set('performingAction', true);
            SiftQueue.confirmFailed(post).then(() => {
                this.get('model').removeObject(post);
                this.incrementProperty('stats.confirmed_failed');
                this.decrementProperty('stats.requires_moderation');
            }).catch(genericError).finally(() => {
                this.set('performingAction', false);
            });
        },

        allowPost(post) {
            this.set('performingAction', true);
            SiftQueue.allow(post).then(() => {
                this.incrementProperty('stats.confirmed_passed');
                this.decrementProperty('stats.requires_moderation');
                this.get('model').removeObject(post);
            }).catch(genericError).finally(() => {
                this.set('performingAction', false);
            });
        },

        dismiss(post) {
            this.set('performingAction', true);
            SiftQueue.dismiss(post).then(() => {
                this.get('model').removeObject(post);
            }).catch(genericError).finally(() => {
                this.set('performingAction', false);
            });
        }

    }
});
