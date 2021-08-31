# salesforce-survey-invitation-generator
Component that generates Survey Invitations on Account, Contact and Leads. 
Useful to generate Survey Invitation URLs and send them to Contacts in the Email body with another tool like Marketing Cloud.
This component creates only guest invitations.

<a href="https://githubsfdeploy.herokuapp.com/app/githubdeploy/nfunky/salesforce-survey-invitation-generator.git">
  <img alt="Deploy to Salesforce"
       src="https://raw.githubusercontent.com/afawcett/githubsfdeploy/master/deploy.png">
</a>

![screenshot](https://github.com/nfunky/salesforce-survey-invitation-generator/blob/master/screenshot.png)

## Features
* Create Survey Invitation records for records selected in a list view.
* Launch a batch job that generates Survey Invitations for a SOQL query entered.
* Filter and select individual records for which Survey Invitations should be generated.

## Prerequisites
1. Enable Person Accounts
2. Set up a Community
3. Enable the Salesforce Survey feature under **Survey Settings**
4. Grant access on Survey objects to the Guest user profile of your community.

## Setup
1. Ensure the prerequisites mentioned above are fulfilled.
2. Deploy the metadata components to your environment. 
3. In Setup navigate to the **Object Manager** and select the Object where you want to generate the Survey Invitation records (Account, Contact or Lead)
4. Click the **Search Layouts for Salesforce Classic** option to add the list view button
5. Click **Edit** next to List View row and add the custom button **Generate Survey Invitations** and click save.
