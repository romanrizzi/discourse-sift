import DropdownSelectBox from "select-kit/components/dropdown-select-box";
import SiftMod from 'discourse/plugins/discourse-sift/admin/models/sift-mod';
const { get } = Ember;

export default DropdownSelectBox.extend({
  classNames: ["disagree-flag", "admin-disagree-flag-dropdown"],
  adminTools: Ember.inject.service(),
  nameProperty: "label",
  isDisabled: false,
  headerIcon: "thumbs-o-down",

  computeHeaderContent() {
    let content = this._super(...arguments);
    content.name = `${I18n.t("sift.actions.disagree.title")}...`;
    return content;
  },

  sendAndDisable(reason){
    if (reason === 'other'){
      this.send("disagree_other", reason);
    }
    else{
      this.send("disagree", reason);
    }
    this.set("isDisabled", true);
  },

  computeContent() {
    const content = [];
    content.push({
      icon: "far-question-circle",
      id: "disagree-false-positive",
      action: () => this.sendAndDisable('false_positive'),
      label: I18n.t("sift.actions.disagree_due_to_false_positive.title"),
      description: I18n.t("sift.actions.disagree_due_to_false_positive.description")
    });

    content.push({
      icon: "fab-steam-square",
      id: "disagree-too-strict",
      action: () => this.sendAndDisable('too_strict'),
      label: I18n.t("sift.actions.disagree_due_to_too_strict.title"),
      description: I18n.t("sift.actions.disagree_due_to_too_strict.description")
    });

    content.push({
      icon: "far-edit",
      id: "disagree-user-edited",
      action: () => this.sendAndDisable('user_edited'),
      label: I18n.t("sift.actions.disagree_due_to_user_edited.title"),
      description: I18n.t("sift.actions.disagree_due_to_user_edited.description")
    });

    content.push({
      icon: "fab-weixin",
      id: "disagree-other",
      action: () => this.sendAndDisable('other'),
      label: I18n.t("sift.actions.disagree_due_to_other_reasons.title"),
      description: I18n.t("sift.actions.disagree_due_to_other_reasons.description")
    });

    return content;
  },

  mutateValue(value) {
    const computedContentItem = this.get("computedContent").findBy(
      "value",
      value
    );
    get(computedContentItem, "originalContent.action")();
  },

  actions: {
    disagree(reason){
      let flaggedPost = this.get("post");
      SiftMod.disagree(flaggedPost, reason);
    },

    disagree_other(reason) {
      let flaggedPost = this.get("post");
      let otherReason = promptForExtraReason();
      SiftMod.disagreeOther(flaggedPost, reason, otherReason);

      function promptForExtraReason() {
        let extraReason = prompt("Please enter the reason:", "correct based on the context");
        if (extraReason == null || extraReason === "") {
          promptForExtraReason();
        }
        return extraReason;
      }
    },




  }
});
