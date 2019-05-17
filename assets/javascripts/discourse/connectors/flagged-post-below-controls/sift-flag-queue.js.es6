import SiftMod from 'discourse/plugins/discourse-sift/admin/models/sift-mod';

function genericError() {
    bootbox.alert(I18n.t('generic_error'));
}

export default {
    actions: {
        confirmFailedPost(flaggedPost) {
            console.log('my action triggered');
            SiftMod.confirmFailed(flaggedPost);
            // SiftMod.confirmFailed(flaggedPost).then(() => {
            //     this.get('model').removeObject(flaggedPost);
            //     this.incrementProperty('stats.confirmed_failed');
            //     this.decrementProperty('stats.requires_moderation');
            // }).catch(genericError).finally(() => {
            //     this.set('performingAction', false);
            // });
        }
    }
}