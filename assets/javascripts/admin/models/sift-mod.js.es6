import { ajax } from 'discourse/lib/ajax';

export default {
    confirmFailed(post) {
        return ajax("/admin/plugins/sift/mod/confirm_failed", {
            type: "POST",
            data: {
                post_id: post.get("id")
            }
        });
    },

    allow(post) {
        return ajax("/admin/plugins/mod/sift/allow", {
            type: "POST",
            data: {
                post_id: post.get("id")
            }
        });
    },
};
