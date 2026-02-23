### Features

#### HubSpot Integration (existing)

- In settings, connect HubSpot using OAuth
- After recording a new meeting:
    - Open a modal to review AI-suggested updates to a HubSpot contact
    - Search/select a HubSpot contact
    - Use the HubSpot API to pull the contact record
    - AI generates suggested updates based on the meeting transcript
    - Shows existing value vs. AI-suggested update for each field
    - Click "Update HubSpot" to sync updates to the selected contact

#### Salesforce Integration (new)

- In settings, connect Salesforce using OAuth (Connected App)
- After recording a new meeting:
    - Open a modal to review AI-suggested updates to a Salesforce contact
    - Search/select a Salesforce contact via SOSL search
    - Use the Salesforce REST API to pull the contact record
    - AI generates suggested updates to Salesforce fields based on the meeting transcript
    - Shows existing value in Salesforce and the AI-suggested update for each field
    - Click "Update Salesforce" to sync selected updates to the Salesforce contact
    - Token refresh via Oban cron worker (proactive refresh before expiry)
    - Architecture designed for easy addition of more CRMs in the future
