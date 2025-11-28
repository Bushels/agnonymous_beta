# Agnonymous - Product Vision Document

## The Mission

**Agnonymous is the farmer's voice** - a secure, anonymous platform where agricultural professionals can speak truth to power without fear of retaliation. In an industry where reputation is everything and communities are tight-knit, speaking out about harmful practices, unfair pricing, or corporate misconduct can mean social isolation or economic ruin. Agnonymous changes that.

> "Transparency in Agriculture. The farmer takes back control."

---

## The Problem

### The Agricultural Silence

The agriculture industry has a culture of silence:

1. **Small, interconnected communities** - Everyone knows everyone. Speak out against a major feed supplier or neighbor's practices, and word spreads fast.

2. **Economic retaliation** - Farmers who expose bad actors can face:
   - Refused service from suppliers
   - Exclusion from cooperatives
   - Social ostracism in their community
   - Legal threats from corporations

3. **Information asymmetry** - Large agribusiness has pricing power because farmers can't compare what they're paying vs. what others pay.

4. **Misinformation vacuum** - Without trusted channels, rumors spread unchecked. Farmers need a way to validate what they hear.

---

## The Solution

### Core Value Proposition

Agnonymous provides:

1. **Anonymous Whistleblowing** - Share what you know without revealing who you are
2. **Community Truth Validation** - Collective voting separates fact from fiction
3. **Price Transparency** - Crowdsourced input pricing breaks information monopolies
4. **Reputation Without Identity** - Build credibility through consistent accuracy, not personal exposure

---

## Core Features

### 1. Anonymous Posting System

Users can post about:
- Corporate misconduct
- Environmental violations
- Unfair business practices
- Industry rumors (for validation)
- Equipment reviews
- Weather impacts
- Market insights

**Key Innovation: Dual Posting Mode**
- **Anonymous Mode** (default): Complete anonymity, no reputation points earned
- **Username Mode**: Posts with username visible, earns full reputation points

This creates a strategic choice: Do you want to build your reputation, or do you need maximum protection?

### 2. Truth Meter / Credibility System

Every post has a real-time "Truth Meter" powered by community voting:

```
VOTE OPTIONS:
- Two Thumbs Up (++) = Highly credible/verified
- One Thumb Up (+)   = Likely true
- Neutral (0)        = Can't verify either way
- Thumbs Down (-)    = Skeptical/likely false
```

**Visual Truth Meter:**
```
Verified Truth    [====================] 95%
Likely True       [================    ] 80%
Questionable      [========            ] 45%
Likely False      [====                ] 20%
```

### 3. Gamification & Reputation System

**Point Structure:**
| Action | Points | Notes |
|--------|--------|-------|
| Create a post | +5 | Awarded immediately |
| Vote on any post | +1 | Once per post |
| First comment on a post | +2 | Only initial comment, not replies |
| Post receives positive votes | +/- variable | Based on vote ratio |
| Admin verifies post | +10 | Truth confirmed |

**Maximum Loss Per Post: -5 points** (You can lose your posting bonus, but no more)

**Reputation Levels:**
| Level | Points | Title | Vote Weight |
|-------|--------|-------|-------------|
| 0 | 0-49 | Seedling | 1.0x |
| 1 | 50-149 | Sprout | 1.0x |
| 2 | 150-299 | Growing | 1.1x |
| 3 | 300-499 | Established | 1.2x |
| 4 | 500-749 | Reliable Source | 1.3x |
| 5 | 750-999 | Trusted Reporter | 1.5x |
| 6 | 1000-1499 | Expert Whistleblower | 1.7x |
| 7 | 1500-2499 | Truth Guardian | 2.0x |
| 8 | 2500-4999 | Master Investigator | 2.5x |
| 9 | 5000+ | Legend | 3.0x |

**High reputation benefits:**
- Posts appear higher in feeds
- Votes carry more weight
- Eligible for moderator status
- Special badges displayed

### 4. Verification Badge System

**Account Verification:**
- **Verified Badge**: Email confirmed, displays checkmark icon
- **Unverified Badge**: Email not confirmed, displays warning icon
- **Anonymous Badge**: Post made without username, displays mask icon

This builds trust while preserving the option for anonymity.

### 5. Input Pricing Database (NEW FEATURE)

**The Vision:**
Create the first crowdsourced database of agricultural input prices:
- Fertilizers
- Chemicals (herbicides, pesticides, fungicides)
- Seeds (branded, generic, proprietary)

**How It Works:**
1. User selects or creates a retailer location
2. Selects product category and specific product
3. Enters price, unit, and date
4. System handles:
   - CAD vs USD based on location
   - Duplicate retailer detection and merging
   - Price history tracking
   - Regional price comparisons

**Why This Matters:**
Farmers currently have zero price transparency. A co-op in Picture Butte might charge $50/unit more than one in Lethbridge. This feature exposes those disparities.

### 6. Location-Based Features

**Province/State Selection:**
- Required at signup
- Powers location-based feed filtering
- Users can "favorite" their region
- Enables regional price comparisons

**Location Hierarchy:**
```
Canada:
  - Alberta, British Columbia, Manitoba, Saskatchewan...

USA:
  - Texas, California, Iowa, Nebraska...
```

### 7. Smart Categorization (AI-Powered)

**Current Categories:**
- Farming, Livestock, Ranching, Crops
- Markets, Weather, Chemicals, Equipment
- Politics, General, Other

**Future AI Integration (OpenRouter):**
- Auto-suggest categories based on content
- Detect recurring themes (e.g., "Picture Butte Feeder Cooperative" appears often)
- Create dynamic sub-categories
- Tag extraction for search

### 8. Notification System

Users can subscribe to:
- **Location alerts**: Posts from their province/state
- **Keyword alerts**: Specific terms or company names
- **Category alerts**: Posts in topics they follow
- **Price alerts**: Products they're watching in their region
- **Reply alerts**: Responses to their posts/comments

### 9. Post Bumping by Reputation

High-reputation users get priority visibility:
- Posts from Level 5+ users appear higher
- Verified posts get extra visibility
- Community-validated posts (90%+ accuracy) get featured

---

## User Journey

### New User Flow

```
1. LANDING PAGE
   - See featured/trending posts (read-only)
   - Clear CTA: "Join the Conversation"

2. SIGNUP
   - Username (unique, their choice)
   - Email (for verification + recovery)
   - Password (strong requirements)
   - Province/State (required)

3. EMAIL VERIFICATION
   - Link sent to email
   - Can skip, but stays "Unverified"
   - Unverified = limited credibility

4. FIRST EXPERIENCE
   - Tutorial overlay highlighting key features
   - Encouraged to vote on existing posts (+1 point each)
   - "Post Your First Story" CTA
```

### Posting Flow

```
1. TAP "+" BUTTON

2. CHOOSE POSTING MODE
   [Post Anonymously]  [Post as @username]
   "Note: You only earn reputation points when posting with your username"

3. SELECT CATEGORY
   Grid of category icons

4. OPTIONAL: SELECT LOCATION
   Province/State dropdown

5. WRITE POST
   - Title (required, max 100 chars)
   - Content (required, min 10 chars)

6. SUBMIT
   - Success animation
   - +5 points if username mode

7. WATCH YOUR POST
   - See votes roll in
   - Reply to comments
   - Watch Truth Meter move
```

### Input Pricing Flow (NEW)

```
1. NAVIGATE TO "PRICES" TAB (bottom nav)

2. SELECT PRODUCT TYPE
   [Fertilizer] [Chemical] [Seed]

3. SEARCH/SELECT PRODUCT
   - Brand name + formulation
   - Generic name if applicable

4. ENTER OR SELECT RETAILER
   - Search existing retailers
   - Or add new location
   - System detects duplicates

5. ENTER PRICE
   - Price per unit
   - Unit type (lb, gallon, bag, etc.)
   - Date of price
   - Currency auto-detected from location

6. SUBMIT
   - Confirmation
   - "View Price History" option
```

---

## Monetization Strategy

### Phase 1: Beta (Current)
- Free for all users
- Focus on user acquisition and data quality

### Phase 2: Ad-Supported
- **Google AdSense** for web app
- **Google AdMob** for iOS/Android apps
- Non-intrusive placement:
  - Banner between posts (every 5th post)
  - Interstitial after posting (optional reward for skip)
  - No ads for high-reputation users?

### Phase 3: Premium Features (Future)
- Ad-free experience
- Advanced price analytics
- Export data
- API access for agribusiness

---

## Technical Principles

### Security First
- Anonymous user IDs never linked to posts in logs
- End-to-end encryption for sensitive data
- Row-Level Security on all database tables
- Rate limiting to prevent abuse

### Privacy by Design
- Minimal data collection
- No IP address logging on posts
- No tracking across sessions for anonymous users
- GDPR-compliant data handling

### Premium Feel
- Glassmorphism UI (frosted glass aesthetic)
- Smooth animations throughout
- Truth Meter has animated transitions
- Badge reveals with celebratory effects
- Dark theme with agricultural green accents

---

## Success Metrics

### User Engagement
- Daily Active Users (DAU)
- Posts per day
- Votes per post average
- Comment engagement rate
- Return user percentage

### Trust Metrics
- Average Truth Meter score (target: >70%)
- Admin verification rate
- Post accuracy over time
- User trust survey scores

### Growth Metrics
- Weekly new signups
- Organic share rate
- App store ratings
- Word-of-mouth referrals

### Pricing Feature Metrics
- Products catalogued
- Price entries per week
- Retailer coverage map
- Price variance discovered

---

## Competitive Landscape

| Platform | What They Do | What We Do Better |
|----------|--------------|-------------------|
| Facebook Groups | Community discussion | Anonymous posting, truth validation |
| Reddit r/farming | Anonymous discussion | Agricultural focus, reputation system |
| Glassdoor | Anonymous workplace reviews | Agricultural industry specific |
| GasBuddy | Crowdsourced fuel prices | Agricultural inputs (seeds, chemicals, fertilizer) |

---

## Future Roadmap Ideas

### Short-term (Beta)
- Complete authentication system
- Implement full gamification
- Launch input pricing MVP
- Mobile-responsive web app

### Medium-term
- Native iOS/Android apps
- AI-powered categorization
- Advanced notifications
- Retailer partnerships

### Long-term
- API for agribusiness
- Integration with farm management software
- Equipment marketplace
- Legal whistleblower protections advocacy

---

## The Vision Realized

Imagine a farmer in rural Alberta discovers their local co-op is charging 40% more than the next town over. Today, they'd complain to neighbors and shrug it off. With Agnonymous:

1. They anonymously post about the price discrepancy
2. Other farmers validate with their own experiences
3. The Truth Meter climbs to 95%
4. Price data in our database confirms the disparity
5. The co-op faces accountability
6. Prices equalize across the region

**This is transparency in agriculture. This is the farmer taking back control.**

---

*Document Version: 1.0*
*Last Updated: November 24, 2025*
*Author: Claude Code Assistant*
