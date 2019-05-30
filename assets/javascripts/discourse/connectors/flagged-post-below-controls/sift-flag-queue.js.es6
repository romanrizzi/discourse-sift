import SiftMod from 'discourse/plugins/discourse-sift/admin/models/sift-mod';

function genericError() {
    bootbox.alert(I18n.t('generic_error'));
}

export default {

    internalReportingDone: (reason) => {
        console.log("internalReportingDone: enter");
        console.log("internalReportingDone: reason = " + reason);
        this.set("isReportingEnabled", false);
    },

    setupComponent(args, component) {
        component.set('isReportingEnabled', true);
        component.set('reportedReason', "");
    },

    actions: {
        confirmFailedPost(flaggedPost) {
            SiftMod.confirmFailed(flaggedPost);
            this.set("isReportingEnabled", false);
            this.set("reportedReason", "Agree");
            //internalReportingDone("Agree");
        },

        markReportingDone(reason) {
            this.set("isReportingEnabled", false);
            this.set("reportedReason", reason);
            //internalReportingDone(reason)

        }
    },

};
