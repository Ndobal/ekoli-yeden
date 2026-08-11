MODULE 1 — EKOLI YEDEN DIGITAL HOME
Foundation & Cloudflare Architecture
Project Identity

Project Name:

EKOLI YEDEN DIGITAL HOME

Tagline:

Preserving Our Past. Celebrating Our Present. Building Our Future.

Community: Ekori

Festival: Leboku

1. TECHNOLOGY STACK

We will use:

Component	Technology
Frontend	Flutter Web
Frontend Hosting	Cloudflare Pages
Backend/API	Cloudflare Workers
Database	Cloudflare D1
File Storage	Cloudflare R2
Video Hosting	YouTube
DNS/SSL/Security	Cloudflare
Architecture
                 EKOLI YEDEN DIGITAL HOME
                           │
                           ▼
                    CLOUDFLARE PAGES
                     Flutter Web App
                           │
                           ▼
                   CLOUDFLARE WORKERS
                       API Layer
                           │
              ┌────────────┼────────────┐
              ▼            ▼            ▼
             D1           R2         YouTube
          Database      Files        Videos
              │
              ▼
          Admin / CMS
2. MODULE 1 OBJECTIVE

The purpose of Module 1 is to establish the complete technical foundation before we begin building individual website sections.

We are not waiting for community materials.

The system must be designed so that when materials begin arriving, administrators can simply add them through the platform.

3. FLUTTER PROJECT ARCHITECTURE

Create a clean, scalable Flutter Web structure:

lib/
│
├── core/
│   ├── config/
│   ├── constants/
│   ├── errors/
│   ├── routing/
│   ├── theme/
│   ├── utils/
│   └── widgets/
│
├── models/
│
├── services/
│   ├── api/
│   ├── auth/
│   └── storage/
│
├── repositories/
│
├── features/
│   ├── home/
│   ├── about/
│   ├── history/
│   ├── leadership/
│   ├── people/
│   ├── language/
│   ├── leboku/
│   ├── news/
│   ├── events/
│   ├── gallery/
│   ├── videos/
│   ├── businesses/
│   ├── organizations/
│   ├── community/
│   └── contributions/
│
├── admin/
│   ├── dashboard/
│   ├── content/
│   ├── media/
│   ├── moderation/
│   ├── users/
│   └── settings/
│
└── main.dart

Do not create a monolithic Flutter application.

Everything should be modular and reusable.

4. CLOUDFLARE WORKERS

Create a TypeScript Cloudflare Worker as the backend/API layer.

Structure:

worker/
├── src/
│   ├── index.ts
│   ├── routes/
│   ├── controllers/
│   ├── services/
│   ├── repositories/
│   ├── middleware/
│   ├── types/
│   └── utils/
│
├── migrations/
└── wrangler.toml

Initial API architecture:

GET /api/health
GET /api/settings
GET /api/pages
GET /api/history
GET /api/leaders
GET /api/people
GET /api/news
GET /api/events
GET /api/festivals
GET /api/language
GET /api/gallery
GET /api/videos

For Module 1, the most important requirement is a working:

GET /api/health

endpoint that confirms the Worker is functioning.

5. CLOUDFLARE D1 DATABASE

Create the D1 database and migration system.

Initial tables:

users
roles
user_roles

site_settings
pages

history_entries
leaders
people

news
events
festivals

language_categories
language_words
language_audio

galleries
gallery_items
videos

businesses
organizations
community_projects

submissions
media_assets

audit_logs

Every appropriate table should have:

id
created_at
updated_at
status

Use a consistent unique-ID strategy.

6. CONTENT WORKFLOW

Every major content type should support:

draft
pending_review
approved
published
archived
rejected

For example:

Community member submits old photograph
              ↓
       pending_review
              ↓
       Administrator checks
              ↓
           approved
              ↓
          published

Public users must never directly publish official content.

7. CLOUDFLARE R2

R2 will store the actual files.

Use it for:

Historical photographs
Gallery images
Audio recordings
Language recordings
PDFs
Historical documents
Profile images
Other approved community materials

Suggested storage structure:

images/
audio/
documents/
avatars/
heritage/
language/
leboku/

D1 should store the metadata, while R2 stores the actual files.

8. YOUTUBE VIDEO SYSTEM

Videos will not be stored in R2.

YouTube will host:

Leboku videos
Documentaries
Interviews
Cultural performances
Community events
Historical recordings
Ekori music
Oral-history videos

D1 should store:

id
title
description
youtube_video_id
thumbnail_url
category
published_date
related_event_id
status
created_at
updated_at

The website will use the YouTube video ID to display the video.

9. AUTHENTICATION & ROLES

Establish the architecture for:

Super Admin

Full system access.

Content Administrator

Creates and manages content.

Media Manager

Manages photographs, audio and media.

Heritage Editor

Manages history and cultural materials.

Language Editor

Manages language resources.

Moderator

Reviews community submissions.

Contributor

Submits materials but cannot publish directly.

Public Visitor

Views publicly available information.

Authorization must be checked server-side through Workers, not merely hidden in Flutter.

10. PUBLIC & ADMIN ROUTES
Public
/
/about
/history
/leaders
/people
/language
/leboku
/news
/events
/gallery
/videos
/businesses
/community
/contribute
Administration
/admin
/admin/content
/admin/history
/admin/leaders
/admin/people
/admin/language
/admin/leboku
/admin/news
/admin/events
/admin/gallery
/admin/videos
/admin/submissions
/admin/users
/admin/settings

Module 1 only needs to establish the route structure and access-control foundation.

11. COMMUNITY CONTRIBUTION SYSTEM

Create the foundation for:

CONTRIBUTE TO EKOLI YEDEN

People should eventually be able to submit:

Old photographs
Historical documents
Stories
Videos
Language recordings
Information about important people
Cultural materials
Historical accounts

Submission fields can include:

Name
Email / Phone
Material Type
Title
Description
Date
Location
People in Material
File Upload
Source / Story
Permission / Consent

All submissions enter:

Pending Review

before publication.

12. LEBOKU ARCHITECTURE

Don't create Leboku as a single static page.

Build a reusable Festival System.

Festival
│
├── Name
├── Year
├── Theme
├── Description
├── Start Date
├── End Date
├── Programme
├── Events
├── Announcements
├── Sponsors
├── Photos
├── Videos
└── Archive

This allows:

Leboku 2026
Leboku 2027
Leboku 2028
Leboku 2029
...

Every festival becomes part of Ekoli Yeden's permanent digital archive.

13. EKORI LANGUAGE ARCHITECTURE

The system must be prepared for the language preservation project.

Each word can eventually contain:

Word
English Meaning
Category
Definition
Example Sentence
Audio Pronunciation
Speaker
Dialect / Variation
Notes
Verification Status

Example:

YEJO

Meaning:
[Awaiting verified material]

Pronunciation:
🔊 Audio

Example:
[Awaiting verified material]

Verified By:
[Scholar/Elder]

Do not invent meanings or pronunciations.

The community's recognized speakers and scholars will provide and verify the language materials.

14. SEARCH FOUNDATION

The future search system should be able to search across:

History
People
Leaders
News
Events
Language
Proverbs
Photos
Videos
Businesses
Organizations

Build the database and API so that this can be implemented later without restructuring everything.

15. DESIGN SYSTEM

The platform should feel:

Premium + African + Cultural + Modern + Warm + Professional

Create centralized design tokens:

AppColors
AppTypography
AppSpacing
AppRadius
AppShadows
AppTheme

The visual identity must be centralized so we can change branding later without rebuilding every page.

Do not invent cultural symbols and claim they are authentic Ekori cultural symbols.

16. RESPONSIVE DESIGN

Build mobile-first.

Support:

Mobile
Tablet
Laptop
Desktop
Large screens

The website should be particularly strong on mobile because visitors will likely arrive through WhatsApp, Facebook, QR codes and other mobile channels.

17. SEO FOUNDATION

Prepare the website for search engines.

Use clean routes such as:

/history
/leaders
/people
/language
/leboku
/leboku/2026
/news
/gallery
/videos

Prepare metadata support for:

Page title
Description
Social image
Open Graph
Canonical URL
18. SECURITY FOUNDATION

Implement:

Secure authentication
Role-based authorization
Worker-side permission checks
Input validation
File type validation
File size limits
Protected admin routes
Audit logging architecture
CORS configuration
Safe error responses
Secure Cloudflare secrets/environment variables

Never expose Cloudflare secrets in Flutter.

19. ERROR & STATE MANAGEMENT

Create reusable states for:

Loading
Success
Empty
Error
Unauthorized
Forbidden
Not Found

A failed API request should never crash the application.

20. ENVIRONMENT CONFIGURATION

Prepare:

Development
Staging
Production

Never hard-code:

API URLs
API keys
Cloudflare credentials
Secrets
R2 credentials

Use the appropriate Cloudflare configuration/secrets system.

21. README

Create a proper:

README.md

Document:

Project purpose
Technology stack
Flutter setup
Cloudflare Pages setup
Workers setup
D1 setup
R2 setup
YouTube integration
Local development
Environment variables
Database migrations
Deployment
Project structure
22. MODULE 1 COMPLETION CHECKLIST

Module 1 is NOT complete until:

 Flutter Web runs
 Cloudflare Pages configuration exists
 Cloudflare Worker runs
 /api/health works
 D1 database created
 D1 migrations execute
 R2 configuration established
 YouTube architecture established
 Public routes created
 Admin route foundation created
 Authentication architecture established
 Roles established
 Responsive foundation works
 Design system established
 API service layer established
 Repository layer established
 Error handling established
 Contribution architecture established
 Leboku architecture established
 Language architecture established
 README created
 Project compiles without errors
 No Ekori information has been invented
🚀 COPILOT PROMPT — MODULE 1

Copy everything below into GitHub Copilot:

Build MODULE 1 of the project:

EKOLI YEDEN DIGITAL HOME

Tagline:
"Preserving Our Past. Celebrating Our Present. Building Our Future."

Community:
Ekori

Festival:
Leboku

MODULE 1:
FOUNDATION & CLOUDFLARE ARCHITECTURE

The goal is to establish a production-ready, scalable technical foundation for a digital heritage and community platform for Ekori.

TECHNOLOGY STACK — STRICT REQUIREMENT:

Frontend:
Flutter Web

Frontend hosting:
Cloudflare Pages

Backend/API:
Cloudflare Workers using TypeScript

Database:
Cloudflare D1

File storage:
Cloudflare R2

Video hosting:
YouTube

Do NOT use Supabase, Firebase, PostgreSQL, MySQL, AWS S3 or another backend/database/storage service.

ARCHITECTURE:

Flutter Web
    ↓
Cloudflare Pages
    ↓
Cloudflare Workers API
    ↓
D1 + R2 + YouTube

The Workers API must act as the secure backend layer between Flutter and Cloudflare services.

PROJECT PURPOSE:

EKOLI YEDEN DIGITAL HOME will eventually contain:

- Ekori history and heritage
- Traditional leadership
- People of Ekori
- Ekori language preservation
- Digital dictionary
- Proverbs
- Folklore
- Oral history
- News
- Events
- Leboku
- Photo gallery
- YouTube video archive
- Businesses
- Organizations
- Community development projects
- Community submissions
- Educational resources
- Ekori people around the world

IMPORTANT:

We are starting development before all community materials are available.

The application must therefore use a database-driven CMS architecture so that materials can be added later without changing source code.

DO NOT INVENT:

- Ekori history
- Chiefs
- Leaders
- Language meanings
- Cultural facts
- Historical dates
- Leboku information
- Community statistics

Use placeholders where verified information is not yet available.

==================================================
1. FLUTTER ARCHITECTURE
==================================================

Create a clean modular Flutter Web architecture:

lib/
  core/
    config/
    constants/
    errors/
    routing/
    theme/
    utils/
    widgets/

  models/

  services/
    api/
    auth/
    storage/

  repositories/

  features/
    home/
    about/
    history/
    leadership/
    people/
    language/
    leboku/
    news/
    events/
    gallery/
    videos/
    businesses/
    organizations/
    community/
    contributions/

  admin/
    dashboard/
    content/
    media/
    moderation/
    users/
    settings/

  main.dart

Do not create a monolithic application.

Use reusable widgets and clean separation of concerns.

==================================================
2. CLOUDFLARE WORKERS
==================================================

Create a TypeScript Cloudflare Worker.

Structure:

worker/
  src/
    index.ts
    routes/
    controllers/
    services/
    repositories/
    middleware/
    types/
    utils/

  migrations/

  wrangler.toml

Establish API architecture:

GET /api/health
GET /api/settings
GET /api/pages
GET /api/history
GET /api/leaders
GET /api/people
GET /api/news
GET /api/events
GET /api/festivals
GET /api/language
GET /api/gallery
GET /api/videos

For Module 1, implement a working /api/health endpoint.

==================================================
3. CLOUDFLARE D1
==================================================

Create the D1 database configuration and migration system.

Initial tables:

users
roles
user_roles

site_settings
pages

history_entries
leaders
people

news
events
festivals

language_categories
language_words
language_audio

galleries
gallery_items
videos

businesses
organizations
community_projects

submissions
media_assets

audit_logs

Use consistent unique identifiers.

Appropriate tables should contain:

id
created_at
updated_at
status

==================================================
4. CONTENT WORKFLOW
==================================================

Implement the architecture for:

draft
pending_review
approved
published
archived
rejected

Only published content may be returned to public users.

==================================================
5. CLOUDFLARE R2
==================================================

Prepare R2 storage architecture.

R2 stores:

- Images
- Historical photographs
- Audio
- Language recordings
- PDFs
- Historical documents
- Profile images
- Other approved community files

Use prefixes:

images/
audio/
documents/
avatars/
heritage/
language/
leboku/

Store metadata in D1 and actual files in R2.

==================================================
6. YOUTUBE
==================================================

Videos MUST be hosted on YouTube.

Do not store videos in R2.

Create the videos model with:

id
title
description
youtube_video_id
thumbnail_url
category
published_date
related_event_id
status
created_at
updated_at

The website will display YouTube videos using their IDs.

==================================================
7. AUTHENTICATION & ROLES
==================================================

Establish architecture for:

Super Admin
Content Administrator
Media Manager
Heritage Editor
Language Editor
Moderator
Contributor
Public Visitor

Admin operations must be protected.

Role authorization must be enforced server-side through Workers.

==================================================
8. PUBLIC ROUTES
==================================================

Create route foundation for:

/
/about
/history
/leaders
/people
/language
/leboku
/news
/events
/gallery
/videos
/businesses
/community
/contribute

==================================================
9. ADMIN ROUTES
==================================================

Create route foundation for:

/admin
/admin/content
/admin/history
/admin/leaders
/admin/people
/admin/language
/admin/leboku
/admin/news
/admin/events
/admin/gallery
/admin/videos
/admin/submissions
/admin/users
/admin/settings

Only authorized users may access admin routes.

==================================================
10. CONTRIBUTION SYSTEM
==================================================

Create the architecture for:

CONTRIBUTE TO EKOLI YEDEN

Possible submission types:

- Historical photographs
- Documents
- Stories
- Videos
- Language recordings
- Information about important people
- Cultural materials
- Historical accounts

Submissions must enter pending_review.

Never automatically publish user submissions.

==================================================
11. LEBOKU SYSTEM
==================================================

Create a reusable festival architecture.

Festival fields:

name
year
theme
description
start_date
end_date
programme
events
announcements
sponsors
photos
videos
archive
status

It must support:

Leboku 2026
Leboku 2027
Leboku 2028
and future years.

==================================================
12. EKORI LANGUAGE SYSTEM
==================================================

Create database/API/model architecture for:

word
english_meaning
category
definition
example_sentence
audio
speaker
dialect_or_variation
notes
verification_status

Do not invent language information.

Use placeholders until verified community materials are supplied.

==================================================
13. DESIGN SYSTEM
==================================================

Create a premium cultural design system.

The visual identity should feel:

Modern
Elegant
African
Cultural
Professional
Warm
Trustworthy

Create centralized:

AppColors
AppTypography
AppSpacing
AppRadius
AppShadows
AppTheme

Do not invent cultural symbols and present them as authentic Ekori symbols.

==================================================
14. RESPONSIVE DESIGN
==================================================

Support:

Mobile
Tablet
Laptop
Desktop
Large screens

Use mobile-first responsive principles.

==================================================
15. SEO FOUNDATION
==================================================

Prepare SEO architecture for:

/history
/leaders
/people
/language
/leboku
/leboku/2026
/news
/gallery
/videos

Prepare support for:

Page title
Description
Social preview image
Open Graph
Canonical URL

==================================================
16. SECURITY
==================================================

Implement:

- Secure authentication
- Server-side authorization
- Input validation
- File type validation
- File size limits
- Protected admin routes
- Audit log architecture
- CORS
- Safe error handling
- Cloudflare secrets/environment variables

Never expose secrets in Flutter.

==================================================
17. ERROR STATES
==================================================

Create reusable states:

Loading
Success
Empty
Error
Unauthorized
Forbidden
Not Found

The UI must not crash when an API fails.

==================================================
18. ENVIRONMENTS
==================================================

Prepare:

Development
Staging
Production

Do not hard-code secrets or environment-specific configuration.

==================================================
19. DOCUMENTATION
==================================================

Create README.md documenting:

- Project purpose
- Technology stack
- Flutter setup
- Cloudflare Pages
- Cloudflare Workers
- D1
- R2
- YouTube
- Local development
- Environment variables
- Database migrations
- Deployment
- Project structure

==================================================
20. MODULE 1 COMPLETION
==================================================

Do NOT proceed to Module 2.

Module 1 is complete only when:

- Flutter Web runs successfully
- Cloudflare Pages configuration exists
- Worker runs
- /api/health works
- D1 is connected
- Migrations work
- R2 architecture exists
- YouTube architecture exists
- Public routes exist
- Admin routes exist
- Authentication foundation exists
- Role architecture exists
- Responsive foundation works
- Design system exists
- API service layer exists
- Repository layer exists
- Error handling exists
- Contribution architecture exists
- Leboku architecture exists
- Language architecture exists
- README exists
- Flutter analyzer has no errors
- Build succeeds
- No community information has been invented

After implementation, report:

1. Files created
2. Files modified
3. D1 tables
4. Migrations
5. Worker endpoints
6. R2 configuration
7. YouTube architecture
8. Authentication architecture
9. Roles
10. Public routes
11. Admin routes
12. Environment variables
13. Commands used
14. Tests performed
15. Errors fixed
16. Remaining issues

STOP after Module 1.

This is now our official Module 1 specification for Ekoli Yeden Digital Home.