import { withPluginApi } from 'discourse/lib/plugin-api';

export default {
    name: 'add-sift-count',
    before: 'register-discourse-location',
    after: 'inject-objects',

    initialize(container) {
        const user = container.lookup('current-user:main');

        if (user && user.get('staff')) {

            withPluginApi('0.4', api => {
                api.addFlagProperty('currentUser.sift_review_count');
                api.decorateWidget('hamburger-menu:admin-links', dec => {
                    return dec.attach('link', {
                        route: 'adminPlugins.sift',
                        label: 'sift.title',
                        badgeCount: 'sift_review_count',
                        badgeClass: 'flagged-posts'
                    });
                });

            });

            const messageBus = container.lookup('message-bus:main');
            messageBus.subscribe("/sift_counts", function (result) {
                if (result) {
                    user.set('sift_review_count', result.sift_review_count || 0);
                }
            });
        }
    }
};
