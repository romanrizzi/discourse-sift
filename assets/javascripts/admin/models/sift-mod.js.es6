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

    disagreeDueToFalsePositive(post) {
        return ajax("/admin/plugins/sift/mod/disagree_due_to_false_positive", {
            type: "POST",
            data: {
                post_id: post.get("id")
            }
        });
    },
    disagreeDueToTooStrict(post) {
        return ajax("/admin/plugins/sift/mod/disagree_due_to_too_strict", {
            type: "POST",
            data: {
                post_id: post.get("id")
            }
        });
    },
    disagreeDueToUserEdited(post) {
        return ajax("/admin/plugins/sift/mod/disagree_due_to_user_edited", {
            type: "POST",
            data: {
                post_id: post.get("id")
            }
        });
    },
    disagreeDueToOther(post) {
        return ajax("/admin/plugins/sift/mod/disagree_due_to_other", {
            type: "POST",
            data: {
                post_id: post.get("id")
            }
        });
    },
};
