//This helper class is performing a greater than operation on given two values and returning True or False
// based on the evaluation
import { registerHelper } from 'discourse-common/lib/helpers';


registerHelper('ifCond', function(params) {
    let topicValueIsGreaterThanTheBoundaryRiskLevel = false;
    let topicValue = parseInt(params[0]);
    let operator = params[1];
    let boundaryRiskLevel = parseInt(params[2]);
    if (operator === '>='){
        if (topicValue >= boundaryRiskLevel) {
            topicValueIsGreaterThanTheBoundaryRiskLevel =  true;
        }
    }
    return topicValueIsGreaterThanTheBoundaryRiskLevel;
});