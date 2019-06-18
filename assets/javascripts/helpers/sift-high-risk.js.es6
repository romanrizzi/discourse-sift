//This helper class is checking if the given risk level should be considered high-risk
// currently this means greater than or equal to a 4
// TODO: Could be extended to allow a threshold to be passed in, or configured somewhere (settings?)
import { registerHelper } from 'discourse-common/lib/helpers';

// Threshold
let boundaryRiskLevel = 4;

registerHelper('sift-high-risk', function(params) {
    let topicValue = parseInt(params[0]);
    return topicValue >= boundaryRiskLevel;
});
