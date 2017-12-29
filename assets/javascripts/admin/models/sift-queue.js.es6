import { ajax } from 'discourse/lib/ajax';

export default {
    confirmFailed(post) {
        return ajax("/admin/plugins/sift/confirm_failed", {
            type: "POST",
            data: {
                post_id: post.get("id")
            }
        });
    },

    allow(post) {
        return ajax("/admin/plugins/sift/allow", {
            type: "POST",
            data: {
                post_id: post.get("id")
            }
        });
    },

    dismiss(post) {
        return ajax("/admin/plugins/sift/dismiss", {
            type: "POST",
            data: {
                post_id: post.get("id")
            }
        });
    },

    findAll() {
        return ajax("/admin/plugins/sift/index.json").then(result => {
            result.posts = result.posts.map(p => Discourse.Post.create(p));
        return result;
    });
    }
};
