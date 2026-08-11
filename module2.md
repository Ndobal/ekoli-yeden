MODULE 2 — REBUILT
EKOLI YEDEN DIGITAL HOME
Brand Identity • CMS • Editorial System • Public Website
1. OFFICIAL BRAND IDENTITY

Use the uploaded logo as the primary brand asset.

Brand

EKOLI YEDEN DIGITAL HOME

Tagline

Preserving Our Past. Celebrating Our Present. Building Our Future.

Logo colour direction

From the supplied logo, build the design system around approximately:

Colour	Use
Deep Navy #0A345C	Primary brand, headings, navigation
Heritage Green #2D6A1D	Culture, community, growth
Gold #B8912D	Highlights, important actions
Light Blue #A9D2F3	Secondary accents
White #FFFFFF	Main surfaces
Soft Background	Very light neutral/blue-white

The colours should be centralized in the Flutter theme so they can be changed later without touching individual screens.

Do not invent additional cultural colours and call them official Ekoli colours.

2. THE BIG CHANGE — EDITORIAL CMS

This is very important.

The Editorial Team must NOT need to touch code to edit website content.

They should be able to log into:

Editorial Dashboard

and edit virtually all public-facing text.

For example:

Homepage

They can edit:

Hero heading
Hero description
Hero button labels
Welcome heading
Welcome text
Section headings
Section descriptions
Card titles
Card descriptions
CTA text
Footer text
Navigation

They can edit:

Home
About
History
Culture
Language
Leboku
People
Gallery
Videos
News
Community
Contribute
Every page

They can edit:

Page title
Introduction
Body content
Headings
Captions
Buttons
SEO title
SEO description
Social sharing description
Image captions
Notices
System text

We should even make these editable through the CMS:

"No news available"
"Coming soon"
"Search"
"Read more"
"Submit"
"Loading..."
Error messages
Contribution instructions
Footer copyright text

That means the website becomes content-driven rather than code-driven.

3. EDITORIAL TEAM ≠ SUPER ADMIN

This distinction must be enforced at the database and API level.

Super Admin

Can:

Manage users
Create/remove roles
Manage permissions
Manage Editorial Team
Manage system settings
Manage infrastructure settings
Manage content
Approve/reject content
Manage security
View audit logs
Configure integrations
Editorial Team

Can:

Create content
Edit content
Edit website text
Edit pages
Edit articles
Edit captions
Edit navigation labels
Edit homepage sections
Prepare content for publication
Submit content for approval
Manage approved editorial material according to permission

But cannot:

Create Super Admins
Change security settings
Change roles/permissions
Access Cloudflare credentials
Access secrets
Modify infrastructure
Delete the entire database
Change zero-trust policies
Bypass approval workflows
4. CONTENT WORKFLOW

This should be built into everything.

Editorial Team
      ↓
Create/Edit
      ↓
DRAFT
      ↓
Submit for Review
      ↓
PENDING REVIEW
      ↓
Authorized Reviewer
      ↓
APPROVED
      ↓
PUBLISHED

For rejected content:

PENDING REVIEW
      ↓
REJECTED
      ↓
Editorial Team revises
      ↓
PENDING REVIEW

No editorial user should be able to bypass this simply by manipulating the frontend.

The Worker must enforce it server-side.

5. CONTRIBUTOR ACKNOWLEDGEMENT

This should be part of the system from Module 2.

Every submitted material should have:

Contributor
Contributor Type
Submission Date
Approval Date
Approved By
Source
Attribution
Copyright/Usage Permission

When published, the website can show:

Contributed by: [Name]

or:

Photo contributed by: [Name]

or:

Historical material supplied by: [Name/Organization]

The contributor acknowledgement should not disappear when an editor edits the article.

The audit trail should preserve who supplied the material and who approved it.

6. SOURCE & REFERENCE SYSTEM

This is particularly important for the history section.

Each historical article should be capable of having:

Sources
References
Author
Contributor
Reviewer
Date verified
Verification status

For example:

Sources & References

Yakurrwatchblog — The History of Yakurr Kingdom
Wikipedia — Ekori
Other historical books/documents supplied by the Preservation Team
Oral interview with an elder
Archival photograph supplied by contributor

The editorial system should allow the team to add references without touching code.

The current source material indicates that the historical naming of the five major Yakurr settlements is discussed as involving earlier names including Ekoli, with later forms such as Ekori appearing in outside usage; however, this is exactly the sort of historical/language claim that should be presented with source attribution and reviewed by the Preservation Team rather than treated as settled fact merely because one online source says so.

7. INITIAL WEBSITE CONTENT

We can now put some source-based initial content into the website while leaving room for the Preservation Team to expand and verify it.

Homepage introduction
Welcome to Ekoli-Yeden

EKOLI YEDEN DIGITAL HOME is a digital heritage and community platform dedicated to preserving, documenting and celebrating the history, culture, language, people and development of Ekoli-Yeden.

This platform is being developed as a living digital archive, bringing together historical materials, community stories, photographs, videos, language resources, festivals, people and contributions from Ekoli-Yeden and its people around the world.

This is platform/project content rather than a historical claim.

8. HISTORY PAGE — INITIAL CONTENT

Create:

History of Ekoli-Yeden

Start with a clearly marked:

Historical Archive — Initial Research Edition

The supplied sources discuss Ekoli as one of the communities/settlements associated with Yakurr and identify Lokaa/Lokạạ as the language associated with Yakurr communities. The sources also contain accounts of migration, ancestral origins and the historical development of present settlements.

The Yakurrwatchblog history article presents an account in which migration occurred in phases and places the establishment of Ekori and Nko in the period 1677–1707, while other online sources repeat related chronology. Because these accounts are secondary web sources, the Digital Home should initially present them as sourced historical accounts, not as unquestionable final history.

Then display:

References

The History of Yakurr Kingdom — Yakurrwatchblog

Ekori — Wikipedia

And provide a button:

Suggest a Correction / Add Historical Evidence

That will allow elders, researchers and contributors to help improve the archive.

9. CULTURE PAGE

Create:

Culture & Heritage

Initial categories:

Language
Leboku
Traditional practices
Wrestling / KEPU
Dances
Food
Clothing
Agriculture
Proverbs
Folklore
Oral history
Traditional institutions
Community life

The available source material describes Leboku as the New Yam festival associated with Yakurr communities and identifies Ekori among the communities associated with the festival.

But the CMS should allow the Preservation Team to build a much richer, properly sourced cultural archive.

10. LEBOKU PAGE

Create a dedicated:

LEBOKU

The system should support:

Leboku
 ├── History
 ├── Meaning
 ├── Ekoli Celebration
 ├── Programme
 ├── Events
 ├── Photos
 ├── Videos
 ├── Participants
 ├── Traditional Activities
 ├── Announcements
 └── Archive

The existing sources describe Leboku as a New Yam festival of the Yakurr people and identify Ekori as one of the communities associated with the festival.

We should not automatically copy every claim from those sources. The Editorial Team and Preservation Team should verify culturally sensitive material before publication.

11. LANGUAGE PAGE

Create:

LEARN EKOLI

The language section should ultimately become one of the most valuable parts of the platform.

Example:

EKOLI LANGUAGE

Search a word...

Word:
YEJO

Meaning:
[Editable by Editorial Team]

Pronunciation:
[Audio]

Example:
[Editable]

Speaker:
[Contributor]

Verified by:
[Reviewer]

The system must support:

Text → Meaning → Audio pronunciation → Example → Contributor → Verification

And later:

🔊 Listen

A contributor or recognized language scholar can upload the authentic pronunciation.

12. HOME PAGE — MAXIMUM FIVE SECTIONS

I agree with your instruction.

The homepage should not become excessively long.

After the hero, use five professionally designed sections.

SECTION 1 — DISCOVER EKOLI-YEDEN

Three or four large cards:

Our History

Our Culture

Our People

Our Language

SECTION 2 — LEBOKU & HERITAGE

Large visual feature.

Image on one side.

Content on the other:

Leboku

Discover the traditions, stories, celebrations and memories surrounding one of the most important cultural festivals associated with Yakurr communities.

Explore Leboku

SECTION 3 — EKOLI-YEDEN TODAY

Modern community section:

Community news
Projects
Businesses
Organizations
Achievements
SECTION 4 — FROM OUR ARCHIVE

A beautiful media strip:

Photos | Videos | Historical Documents

This will eventually become the gateway into the full archive.

SECTION 5 — PRESERVE OUR HERITAGE

Strong closing CTA:

Your photograph could be history tomorrow.

Help preserve the stories, images, language and memories of Ekoli-Yeden for generations to come.

Buttons:

Contribute Materials

Join the Preservation Team

13. HERO — FIVE IMAGE CAROUSEL

This is now the homepage's primary visual feature.

Exactly 5 slides.

Each slide contains an image and text overlay.

Slide 1

WELCOME TO
EKOLI YEDEN DIGITAL HOME

Preserving Our Past. Celebrating Our Present. Building Our Future.

Buttons:

Explore Our Heritage

Contribute to Ekoli-Yeden

The other four images can initially have configurable text from the CMS.

For example:

Slide 2

Our History

Slide 3

Our Culture

Slide 4

Our People

Slide 5

Our Future

But all of these texts must be editable by the Editorial Team.

14. DISTINCT PAGES

The navbar should lead to proper pages rather than merely scrolling around the homepage.

/
 /about
 /history
 /culture
 /language
 /leboku
 /people
 /news
 /events
 /gallery
 /videos
 /community
 /businesses
 /organizations
 /contribute
 /preservation-team
 /contact

Each page should have:

Hero/banner
Page title
Introductory text
Content
Images where appropriate
Sources/references where applicable
Contributor acknowledgement
Related content
CTA
Footer
15. MEDIA CONTRIBUTION SYSTEM

This needs to be very strong.

Someone can submit:

📷 Photograph
🎥 Video
📄 Historical document
🎙️ Audio
📖 Story
🗣️ Language recording

Workflow:

Contributor
      ↓
Upload
      ↓
Metadata
      ↓
Usage permission
      ↓
Pending
      ↓
Editorial Review
      ↓
Verification
      ↓
Approval
      ↓
Published

Approved material gets:

Contributed by [Contributor]

and appropriate source/credit information.

16. ZERO-TRUST ARCHITECTURE

We should make this a hard requirement.

The principle is:

Never trust. Always verify.

Every protected request
Flutter
   ↓
Worker
   ↓
Authenticate
   ↓
Identify user
   ↓
Check role
   ↓
Check permission
   ↓
Check resource
   ↓
Check action
   ↓
Allow / Deny

Do not rely on:

if (user.role == "editor")

in Flutter.

That is only UI.

The Worker must independently enforce authorization.

17. ROLE/PERMISSION MATRIX

Create granular permissions.

SUPER ADMIN
system.manage
users.manage
roles.manage
permissions.manage
security.manage
settings.manage
content.manage
content.publish
content.delete
media.manage
submissions.manage
audit.view
EDITORIAL TEAM
content.create
content.edit
content.review
content.submit
pages.edit
navigation.edit
homepage.edit
seo.edit
media.metadata.edit
sources.manage

Potentially:

content.publish

should be separately permissioned, rather than automatically granted to every Editorial Team member.

That gives the Super Admin the ability to have:

Writer → Editor → Reviewer → Publisher

inside the Editorial Team.

18. AUDIT LOG

Every important action should be recorded.

Example:

WHO:
Editorial User

ACTION:
Edited History Page

WHAT:
Changed paragraph 3

WHEN:
11 August 2026, 16:30

IP / Request metadata:
Logged securely

RESULT:
Pending Review

For administrators:

Who changed the role?
Who approved the photograph?
Who published the article?
Who deleted the submission?
Who changed the homepage?

Everything important should be traceable.

19. CONTENT VERSIONING

This is essential for history.

Suppose an editor changes:

"Ekoli was founded..."

The previous version must remain available internally.

Create:

Version 1
Version 2
Version 3
Version 4

Allow authorized users to:

View Version

Compare Changes

Restore Version

This protects the archive from accidental or inappropriate edits.

20. EDITORIAL DASHBOARD

The Editorial Team should see:

EDITORIAL DASHBOARD

Welcome, [Name]

Drafts             12
Pending Review      5
Published          48
Needs Revision      3

--------------------------------

Homepage
Pages
History
Culture
Language
Leboku
People
News
Events
Gallery
Videos
Community
Sources
Contributors
Submissions

No Cloudflare dashboard.

No database console.

No code.

No secrets.

21. SUPER ADMIN DASHBOARD

Different interface.

SUPER ADMIN

System Overview

Users
Roles
Permissions
Editorial Team
Content
Submissions
Media
Sources
Audit Logs
Security
Site Settings
Integrations

The Editorial Team should not see this interface.

22. CONTENT TABLE DESIGN

Add something like:

content_items

with:

id
content_type
slug
title
subtitle
excerpt
body
status
author_id
editor_id
reviewer_id
published_by
published_at
created_at
updated_at

Then:

content_versions
content_sources
content_contributors

This makes the CMS scalable.

23. IMPORTANT: ALL PUBLIC TEXT MUST BE CMS-DRIVEN

This is the rule I want Copilot to follow:

If a visitor can read it, the Editorial Team should be able to manage it without changing source code, unless it is a security/system-generated message.

That includes:

Navigation
Hero
Headings
Paragraphs
Buttons
Cards
Footer
Page titles
Descriptions
CTAs
SEO
Captions
Labels
Empty states
Announcements
Festival descriptions
Contribution instructions