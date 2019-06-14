import SiftMod from 'discourse/plugins/discourse-sift/admin/models/sift-mod';

function genericError() {
    bootbox.alert(I18n.t('generic_error'));
}

export default {

    setupComponent(args, component) {
        component.set('isReportingEnabled', true);
        component.set('reportedReason', "");
    },

    actions: {
        confirmFailedPost(flaggedPost) {
            SiftMod.confirmFailed(flaggedPost);
            this.set("isReportingEnabled", false);
            this.set("reportedReason", I18n.t("sift.actions.agree.title"));
            //internalReportingDone("Agree");
        },

        markReportingDone(reason) {
            this.set("isReportingEnabled", false);
            let reason_key = "sift.actions.disagree_due_to_" + reason + ".title";
            let reason_string = I18n.t(reason_key);
            this.set("reportedReason", reason_string);
            //internalReportingDone(reason)

        }
    },

};
