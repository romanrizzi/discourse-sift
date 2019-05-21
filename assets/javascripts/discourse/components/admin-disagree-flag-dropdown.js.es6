import DropdownSelectBox from "select-kit/components/dropdown-select-box";
import SiftMod from 'discourse/plugins/discourse-sift/admin/models/sift-mod';
const { get } = Ember;

export default DropdownSelectBox.extend({
  classNames: ["disagree-flag", "admin-disagree-flag-dropdown"],
  adminTools: Ember.inject.service(),
  nameProperty: "label",
  headerIcon: "thumbs-o-down",

  computeHeaderContent() {
    let content = this._super(...arguments);
    content.name = `${I18n.t("sift.actions.disagree.title")}...`;
    return content;
  },

  computeContent() {
    const content = [];

    content.push({
      icon: "far-question-circle",
      id: "disagree-false-positive",
      action: () => this.send("disagreeDueToFalsePositive"),
      label: I18n.t("sift.actions.disagree_due_to_false_positive.title"),
      description: I18n.t("sift.actions.disagree_due_to_false_positive.description")
    });

    content.push({
      icon: "fab-steam-square",
      id: "disagree-too-strict",
      action: () => this.send("disagreeDueToTooStrict"),
      label: I18n.t("sift.actions.disagree_due_to_too_strict.title"),
      description: I18n.t("sift.actions.disagree_due_to_too_strict.description")
    });

    content.push({
      icon: "pencil-square-o",
      id: "disagree-user-edited",
      action: () => this.send("disagreeDueToUserEdited"),
      label: I18n.t("sift.actions.disagree_due_to_user_edited.title"),
      description: I18n.t("sift.actions.disagree_due_to_user_edited.description")
    });

    content.push({
      icon: "fab-weixin",
      id: "disagree-other",
      action: () => this.send("disagreeDueToOther"),
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
    disagreeDueToFalsePositive() {
      let flaggedPost = this.get("post");
      SiftMod.disagreeDueToFalsePositive(flaggedPost);
    },

    disagreeDueToTooStrict() {
      let flaggedPost = this.get("post");
      SiftMod.allow(flaggedPost);
    },

    disagreeDueToUserEdited() {
      let flaggedPost = this.get("post");
      SiftMod.allow(flaggedPost);
    },

    disagreeDueToOther() {
      let flaggedPost = this.get("post");
      SiftMod.allow(flaggedPost);
    },


  }
});
