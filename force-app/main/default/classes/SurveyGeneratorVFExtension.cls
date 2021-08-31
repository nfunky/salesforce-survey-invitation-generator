/*          
 * SurveyGeneratorVFExtension
 * VF extension to provide list of selected ids to LWC component
 *
 * @isTestedBy SurveyGeneratorTest
 */
public class SurveyGeneratorVFExtension {
    public String selectedIds{get;set;}

    public SurveyGeneratorVFExtension(ApexPages.StandardSetController cntlr) {        
        List<String> recordIds = new List<String>(); 
        for(SObject rec : cntlr.getSelected()) {
            recordIds.add(rec.Id);                   
        }        
        selectedIds=JSON.serialize(recordIds);
    } 
}