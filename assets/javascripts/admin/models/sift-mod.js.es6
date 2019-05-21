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

    disagree(post, reason){
        return ajax("/admin/plugins/sift/mod/disagree", {
            type: "POST",
            data: {
                post_id: post.get("id"),
                reason: reason
            }
        });
    },

    disagreeOther(post, reason, otherReason){
        return ajax("/admin/plugins/sift/mod/disagree_other", {
            type: "POST",
            data: {
                post_id: post.get("id"),
                reason: reason,
                other_reason: otherReason
            }
        });
    },
};
